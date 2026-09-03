import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teiker_app/backend/notification_service.dart';
import 'package:teiker_app/work_sessions/domain/fixed_holiday_hours_policy.dart';
import 'package:teiker_app/work_sessions/domain/work_session.dart';

/// Guarda localmente as marcações feitas pelas teikers e replica-as para o
/// Firestore assim que for possível. O Firestore também mantém a sua própria
/// fila offline; esta cópia protege a marcação antes de qualquer chamada à rede.
class OfflineWorkSessionService with WidgetsBindingObserver {
  OfflineWorkSessionService._();

  static final OfflineWorkSessionService instance =
      OfflineWorkSessionService._();

  static const _storageKeyPrefix = 'pending_work_sessions_';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final Random _random = Random();
  bool _started = false;
  bool _syncing = false;
  Future<void> _storageLock = Future.value();

  /// Serializa alterações à fila local. Sem isto, uma sincronização antiga
  /// podia voltar a guardar uma sessão como aberta depois de ela ter sido
  /// terminada no telemóvel.
  Future<T> _withStorageLock<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _storageLock = _storageLock.catchError((_) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _auth.authStateChanges().listen((_) {
      unawaited(syncPendingSessions());
    });
    unawaited(syncPendingSessions());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncPendingSessions());
    }
  }

  String _keyFor(String teikerId) => '$_storageKeyPrefix$teikerId';

  String _newId() =>
      'offline_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';

  Future<List<_PendingWorkSession>> _read(String teikerId) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_keyFor(teikerId));
    if (value == null || value.isEmpty) return [];

    try {
      final decoded = jsonDecode(value) as List<dynamic>;
      final sessions = <_PendingWorkSession>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          final session = _PendingWorkSession.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (session.teikerId == teikerId) sessions.add(session);
        } catch (_) {
          // Um registo antigo/corrompido não pode impedir a recuperação dos
          // restantes registos guardados no telemóvel.
        }
      }
      return sessions;
    } catch (_) {
      // Não bloquear uma marcação nova caso uma instalação antiga tenha dados
      // locais inválidos.
      return [];
    }
  }

  Future<void> _write(
    String teikerId,
    List<_PendingWorkSession> sessions,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _keyFor(teikerId),
      jsonEncode(sessions.map((session) => session.toJson()).toList()),
    );
  }

  Future<WorkSession?> findOpenSession(String clienteId) async {
    final teikerId = _auth.currentUser?.uid;
    if (teikerId == null) return null;
    return _withStorageLock(() async {
      final sessions = await _read(teikerId);
      final session = sessions.cast<_PendingWorkSession?>().firstWhere(
        (item) => item?.clienteId == clienteId && item?.endTime == null,
        orElse: () => null,
      );
      return session?.toWorkSession();
    });
  }

  Future<WorkSession?> findAnyOpenSession() async {
    final teikerId = _auth.currentUser?.uid;
    if (teikerId == null) return null;
    return _withStorageLock(() async {
      final sessions = await _read(teikerId);
      final session = sessions.cast<_PendingWorkSession?>().firstWhere(
        (item) => item?.endTime == null,
        orElse: () => null,
      );
      return session?.toWorkSession();
    });
  }

  Future<WorkSession> startSession({
    required String clienteId,
    required String teikerId,
    required String clienteName,
  }) async {
    if (clienteId.trim().isEmpty || teikerId.trim().isEmpty) {
      throw Exception('Não foi possível iniciar a sessão: dados incompletos.');
    }
    if (_auth.currentUser?.uid != teikerId) {
      throw Exception('Utilizador não autenticado.');
    }
    final session = await _withStorageLock(() async {
      final sessions = await _read(teikerId);
      if (sessions.any((item) => item.endTime == null)) {
        throw Exception('Já tens uma sessão ativa noutro cliente.');
      }
      final newSession = _PendingWorkSession(
        id: _newId(),
        clienteId: clienteId,
        teikerId: teikerId,
        startTime: DateTime.now(),
      );
      sessions.add(newSession);
      await _write(teikerId, sessions);
      return newSession;
    });
    try {
      await _notificationService.schedulePendingSessionReminder(
        sessionId: session.id,
        clienteId: clienteId,
        clienteName: clienteName,
        startTime: session.startTime,
      );
    } catch (error) {
      // Uma falha ao agendar um lembrete não pode anular uma sessão já
      // guardada de forma segura na fila offline.
      debugPrint('Erro ao agendar lembrete de sessão: $error');
    }
    unawaited(syncPendingSessions());
    return session.toWorkSession();
  }

  /// Guarda uma deslocação já terminada. Por não ser uma sessão aberta, nunca
  /// bloqueia o início da próxima casa, mesmo que ainda não exista internet.
  Future<void> saveTransitSession({
    required String teikerId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (teikerId.trim().isEmpty || _auth.currentUser?.uid != teikerId) {
      throw Exception('Utilizador não autenticado.');
    }
    if (!endTime.isAfter(startTime)) {
      throw Exception('A hora de fim deve ser posterior ao início.');
    }

    await _withStorageLock(() async {
      final sessions = await _read(teikerId);
      sessions.add(
        _PendingWorkSession(
          id: _newId(),
          clienteId: 'DESLOCACAO',
          teikerId: teikerId,
          startTime: startTime,
          endTime: endTime,
          isTransit: true,
        ),
      );
      await _write(teikerId, sessions);
    });
    unawaited(syncPendingSessions());
  }

  Future<WorkSession> finishSession(WorkSession session) async {
    final teikerId = _auth.currentUser?.uid;
    if (teikerId == null || teikerId != session.teikerId) {
      throw Exception('Utilizador não autenticado');
    }
    if (session.id.trim().isEmpty || session.clienteId.trim().isEmpty) {
      throw Exception('Não foi possível terminar a sessão: dados incompletos.');
    }
    if (!session.isOpen) {
      throw Exception('Esta sessão já foi terminada.');
    }

    final end = DateTime.now();
    if (!end.isAfter(session.startTime)) {
      throw Exception('A hora de fim deve ser posterior ao início.');
    }

    final completed = await _withStorageLock(() async {
      final sessions = await _read(teikerId);
      var index = sessions.indexWhere((item) => item.id == session.id);

      // Se a UI recebeu a cópia já sincronizada do Firestore, termina a
      // cópia local correspondente em vez de deixar uma segunda sessão aberta
      // na fila para ser enviada mais tarde.
      if (index == -1) {
        index = sessions.indexWhere(
          (item) => item.clienteId == session.clienteId && item.endTime == null,
        );
      }

      final localSession = index == -1 ? null : sessions[index];
      final finished = _PendingWorkSession(
        id: localSession?.id ?? session.id,
        clienteId: session.clienteId,
        teikerId: session.teikerId,
        startTime: localSession?.startTime ?? session.startTime,
        endTime: end,
        startSynced: localSession?.startSynced ?? false,
      );
      if (index == -1) {
        sessions.add(finished);
      } else {
        sessions[index] = finished;
      }
      await _write(teikerId, sessions);
      return finished;
    });
    try {
      await _notificationService.cancelPendingSessionReminder(session.id);
      if (completed.id != session.id) {
        await _notificationService.cancelPendingSessionReminder(completed.id);
      }
    } catch (error) {
      // A sessão continua terminada mesmo que o sistema operativo não aceite
      // o cancelamento do lembrete neste instante.
      debugPrint('Erro ao cancelar lembrete de sessão: $error');
    }
    unawaited(syncPendingSessions());
    return completed.toWorkSession();
  }

  /// Envia todas as marcações que ainda estão no telemóvel. Só as remove da
  /// fila depois da confirmação do servidor; sem rede ficam guardadas.
  Future<void> syncPendingSessions() async {
    if (_syncing) return;
    final teikerId = _auth.currentUser?.uid;
    if (teikerId == null) return;

    var retryForNewerData = false;
    _syncing = true;
    try {
      final sessions = await _withStorageLock(() => _read(teikerId));
      if (sessions.isEmpty) return;

      final sentSessions = sessions
          .where((session) => session.endTime != null || !session.startSynced)
          .toList();
      if (sentSessions.isEmpty) return;

      for (final session in sentSessions) {
        await _firestore
            .collection('workSessions')
            .doc(session.id)
            .set(session.toFirestore());
      }

      // Quando não existe internet este Future não conclui. O timeout mantém
      // a cópia local para uma nova tentativa ao retomar/abrir a aplicação.
      await _firestore.waitForPendingWrites().timeout(
        const Duration(seconds: 5),
      );

      retryForNewerData = await _withStorageLock(() async {
        final latest = await _read(teikerId);
        final sentById = {
          for (final session in sentSessions) session.id: session,
        };
        final remaining = <_PendingWorkSession>[];

        for (final session in latest) {
          final sent = sentById[session.id];
          if (sent == null || !session.hasSameSyncState(sent)) {
            remaining.add(session);
          } else if (session.endTime == null) {
            // O início já chegou ao servidor. Mantemos só uma referência local
            // para permitir terminar sem rede, mas nunca o reenviamos aberto.
            remaining.add(session.copyWith(startSynced: true));
          }
          // Uma sessão terminada, sem alterações após o envio, sai da fila.
        }
        await _write(teikerId, remaining);
        return remaining.any(
          (session) => session.endTime != null || !session.startSynced,
        );
      });
    } catch (_) {
      // A fila local é intencionalmente preservada para a próxima tentativa.
    } finally {
      _syncing = false;
      if (retryForNewerData) {
        unawaited(syncPendingSessions());
      }
    }
  }
}

class _PendingWorkSession {
  const _PendingWorkSession({
    required this.id,
    required this.clienteId,
    required this.teikerId,
    required this.startTime,
    this.endTime,
    this.isTransit = false,
    this.startSynced = false,
  });

  factory _PendingWorkSession.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String? ?? '').trim();
    final clienteId = (json['clienteId'] as String? ?? '').trim();
    final teikerId = (json['teikerId'] as String? ?? '').trim();
    final startTime = json['startTime'] as String?;
    if (id.isEmpty ||
        clienteId.isEmpty ||
        teikerId.isEmpty ||
        startTime == null) {
      throw const FormatException('Sessão local incompleta.');
    }
    return _PendingWorkSession(
      id: id,
      clienteId: clienteId,
      teikerId: teikerId,
      startTime: DateTime.parse(startTime),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      isTransit: json['isTransit'] == true,
      // Filas gravadas pelas versões anteriores não tinham este campo. São
      // tratadas como inícios já confirmados para não ressuscitar uma sessão
      // antiga e aberta quando a app voltar a ter internet. Ao terminar, a
      // sessão completa continua a ser sincronizada normalmente.
      startSynced: json.containsKey('startSynced')
          ? json['startSynced'] == true
          : true,
    );
  }

  final String id;
  final String clienteId;
  final String teikerId;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isTransit;
  final bool startSynced;

  _PendingWorkSession copyWith({bool? startSynced}) => _PendingWorkSession(
    id: id,
    clienteId: clienteId,
    teikerId: teikerId,
    startTime: startTime,
    endTime: endTime,
    isTransit: isTransit,
    startSynced: startSynced ?? this.startSynced,
  );

  bool hasSameSyncState(_PendingWorkSession other) =>
      id == other.id &&
      startTime == other.startTime &&
      endTime == other.endTime &&
      isTransit == other.isTransit;

  WorkSession toWorkSession() => WorkSession(
    id: id,
    clienteId: clienteId,
    teikerId: teikerId,
    startTime: startTime,
    endTime: endTime,
    durationHours: _durationHours,
  );

  double? get _durationHours {
    final end = endTime;
    if (end == null) return null;
    final rawHours = end.difference(startTime).inMinutes / 60.0;
    if (isTransit) return rawHours;
    return FixedHolidayHoursPolicy.applyToHours(
      workDate: startTime,
      rawHours: rawHours,
    );
  }

  Map<String, dynamic> toFirestore() {
    final end = endTime;
    if (end == null) {
      return {
        'clienteId': clienteId,
        'teikerId': teikerId,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': null,
        'durationHours': null,
      };
    }
    final rawHours = end.difference(startTime).inMinutes / 60.0;
    final durationHours = _durationHours!;
    final multiplier = rawHours > 0 ? durationHours / rawHours : 1.0;
    return {
      'clienteId': clienteId,
      'teikerId': teikerId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(end),
      'durationHours': durationHours,
      'rawDurationHours': rawHours,
      'durationMultiplier': multiplier,
      'isFixedHolidayRateApplied': !isTransit && multiplier > 1,
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clienteId': clienteId,
    'teikerId': teikerId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'isTransit': isTransit,
    'startSynced': startSynced,
  };
}

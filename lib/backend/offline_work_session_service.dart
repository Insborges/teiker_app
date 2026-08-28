import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final Random _random = Random();
  bool _started = false;
  bool _syncing = false;

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
    final sessions = await _read(teikerId);
    final session = sessions.cast<_PendingWorkSession?>().firstWhere(
      (item) => item?.clienteId == clienteId && item?.endTime == null,
      orElse: () => null,
    );
    return session?.toWorkSession();
  }

  Future<WorkSession?> findAnyOpenSession() async {
    final teikerId = _auth.currentUser?.uid;
    if (teikerId == null) return null;
    final sessions = await _read(teikerId);
    final session = sessions.cast<_PendingWorkSession?>().firstWhere(
      (item) => item?.endTime == null,
      orElse: () => null,
    );
    return session?.toWorkSession();
  }

  Future<WorkSession> startSession({
    required String clienteId,
    required String teikerId,
  }) async {
    if (clienteId.trim().isEmpty || teikerId.trim().isEmpty) {
      throw Exception('Não foi possível iniciar a sessão: dados incompletos.');
    }
    if (_auth.currentUser?.uid != teikerId) {
      throw Exception('Utilizador não autenticado.');
    }
    final existing = await findAnyOpenSession();
    if (existing != null) {
      throw Exception('Já tens uma sessão ativa noutro cliente.');
    }

    final session = _PendingWorkSession(
      id: _newId(),
      clienteId: clienteId,
      teikerId: teikerId,
      startTime: DateTime.now(),
    );
    final sessions = await _read(teikerId);
    sessions.add(session);
    await _write(teikerId, sessions);
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

    final sessions = await _read(teikerId);
    final index = sessions.indexWhere((item) => item.id == session.id);
    final completed = _PendingWorkSession(
      id: session.id,
      clienteId: session.clienteId,
      teikerId: session.teikerId,
      startTime: session.startTime,
      endTime: end,
    );
    if (index == -1) {
      sessions.add(completed);
    } else {
      sessions[index] = completed;
    }
    await _write(teikerId, sessions);
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
      final sessions = await _read(teikerId);
      if (sessions.isEmpty) return;

      for (final session in sessions) {
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

      final latest = await _read(teikerId);
      final sentEndTimes = {
        for (final session in sessions) session.id: session.endTime,
      };
      await _write(
        teikerId,
        // Uma sessão iniciada mantém-se no telemóvel até ser terminada,
        // mesmo que o respetivo início já tenha chegado ao Firebase.
        latest
            .where(
              (session) =>
                  session.endTime == null ||
                  sentEndTimes[session.id] != session.endTime,
            )
            .toList(),
      );
      // Se a teiker terminou a sessão enquanto uma sincronização do início
      // estava em curso, o fim continua guardado e é enviado logo a seguir.
      retryForNewerData = latest.any(
        (session) =>
            !sentEndTimes.containsKey(session.id) ||
            sentEndTimes[session.id] != session.endTime,
      );
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
    );
  }

  final String id;
  final String clienteId;
  final String teikerId;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isTransit;

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
  };
}

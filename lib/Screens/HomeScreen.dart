import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/EventAddSheet.dart';
import 'package:teiker_app/Widgets/EventItem.dart';
import 'package:teiker_app/Widgets/CurveAppBarClipper.dart';
import 'package:teiker_app/Widgets/modern_calendar.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/AppBottomNavBar.dart';
import 'package:teiker_app/Widgets/app_confirm_dialog.dart';
import 'package:teiker_app/auth/auth_notifier.dart';
import 'package:teiker_app/auth/app_user_role.dart';
import 'package:teiker_app/backend/notification_service.dart';
import 'package:teiker_app/models/Clientes.dart';
import 'package:teiker_app/theme/app_colors.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends ConsumerState<HomeScreen> {
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};
  final Map<DateTime, List<Map<String, dynamic>>> _consultas = {};
  List<Map<String, dynamic>> teikersFerias = [];
  List<Map<String, dynamic>> teikersBaixas = [];
  List<Map<String, dynamic>> _teikerBirthdays = [];
  List<Map<String, String>> _teikers = [];
  Map<String, String> _teikerNamesById = {};
  List<Clientes> _clientes = [];
  final PageController _adminEventsPageController = PageController();
  final PageController _teikerEventsPageController = PageController();
  int _adminEventsPage = 0;
  int _teikerEventsPage = 0;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final Color selectedColor = AppColors.primaryGreen;
  String? _loadedUserId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _teikerSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _adminRemindersSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _userRemindersSubscription;
  StreamSubscription<String>? _managerEventOpenSubscription;
  bool _adminRemindersListening = false;
  String? _userRemindersListeningFor;
  String? _pendingManagerEventDialogReminderId;
  bool _pendingManagerEventRefreshAttempted = false;
  bool _openingManagerEventDialog = false;

  DateTime _dayKey(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  DateTime _birthdayDateInYear(DateTime birthDate, int year) {
    final maxDay = DateTime(year, birthDate.month + 1, 0).day;
    final safeDay = birthDate.day.clamp(1, maxDay).toInt();
    return DateTime(year, birthDate.month, safeDay);
  }

  bool _isAcontecimento(Map<String, dynamic> event) {
    return event['isAcontecimento'] == true || event['tag'] == 'Acontecimento';
  }

  bool _isReminder(Map<String, dynamic> event) {
    if (_isAcontecimento(event)) return false;
    if (event['isFerias'] == true) return false;
    if (event['isConsulta'] == true) return false;
    if (event['isBirthday'] == true) return false;
    return true;
  }

  bool _isTeikerMarcacaoTag(String? rawTag) {
    final normalized = (rawTag ?? '').trim().toLowerCase();
    return normalized == 'reunião de trabalho' ||
        normalized == 'reuniao de trabalho' ||
        normalized == 'acompanhamento';
  }

  bool _isHrVisibleAgendaTag(String? rawTag) {
    final normalized = (rawTag ?? '').trim();
    if (normalized == 'Acontecimento') return true;
    return _isTeikerMarcacaoTag(normalized);
  }

  bool _isTeikerMarcacaoAgendaEvent(Map<String, dynamic> event) {
    return _isTeikerMarcacaoTag(event['tag'] as String?);
  }

  List<String> _parseStringList(dynamic raw) {
    if (raw is! Iterable) return const <String>[];
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _parseAcontecimentoResponses(dynamic raw) {
    if (raw is! Iterable) return const <Map<String, dynamic>>[];
    final items = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final createdAt = map['createdAt'];
      if (createdAt is Timestamp) {
        map['createdAt'] = createdAt.toDate();
      }
      items.add(map);
    }
    items.sort((a, b) {
      final aDate = a['createdAt'] as DateTime?;
      final bDate = b['createdAt'] as DateTime?;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return -1;
      if (bDate == null) return 1;
      return aDate.compareTo(bDate);
    });
    return items;
  }

  bool _isAcontecimentoResolved(Map<String, dynamic> event) {
    final resolved = event['resolved'];
    if (resolved is bool) return resolved;
    final done = event['done'];
    return done is bool ? done : false;
  }

  bool _isAcontecimentoSeenByCounterpart(Map<String, dynamic> event) {
    final creatorId = (event['createdById'] as String?)?.trim() ?? '';
    final seenBy = _parseStringList(event['seenByUserIds']);
    if (seenBy.isEmpty) return false;
    if (creatorId.isEmpty) return true;
    return seenBy.any((uid) => uid != creatorId);
  }

  String _formatAcontecimentoDate(DateTime date) {
    return DateFormat('EEEE, dd MMMM yyyy', 'pt_PT').format(date);
  }

  void _queueOpenAcontecimentoFromNotification(String reminderId) {
    final normalized = reminderId.trim();
    if (normalized.isEmpty) return;
    _pendingManagerEventDialogReminderId = normalized;
    _pendingManagerEventRefreshAttempted = false;
    _tryOpenPendingAcontecimentoFromNotification();
  }

  MapEntry<DateTime, Map<String, dynamic>>? _findAcontecimentoByReminderId(
    String reminderId,
  ) {
    for (final entry in _events.entries) {
      for (final event in entry.value) {
        final id = (event['id'] as String?)?.trim();
        if (id == reminderId && _isAcontecimento(event)) {
          return MapEntry(entry.key, event);
        }
      }
    }
    return null;
  }

  void _tryOpenPendingAcontecimentoFromNotification() {
    if (!mounted || _openingManagerEventDialog) return;
    final reminderId = _pendingManagerEventDialogReminderId;
    if (reminderId == null || reminderId.isEmpty) return;

    final found = _findAcontecimentoByReminderId(reminderId);
    if (found == null) {
      final userId = _loadedUserId;
      if (!_pendingManagerEventRefreshAttempted &&
          userId != null &&
          userId.trim().isNotEmpty) {
        _pendingManagerEventRefreshAttempted = true;
        unawaited(_loadReminders(userId));
      }
      return;
    }

    _pendingManagerEventDialogReminderId = null;
    _openingManagerEventDialog = true;

    final event = found.value;
    final eventDate = event['date'] as DateTime? ?? _selectedDay;
    setState(() {
      _selectedDay = eventDate;
      _focusedDay = DateTime(eventDate.year, eventDate.month, 1);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _openingManagerEventDialog = false;
        return;
      }
      await _showAcontecimentoDetailsDialog(event);
      _openingManagerEventDialog = false;
      if (_pendingManagerEventDialogReminderId != null) {
        _tryOpenPendingAcontecimentoFromNotification();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadFerias();
    _loadBaixas();
    _loadConsultas();
    _loadClientes();
    _loadTeikers();
    _startTeikerListener();
    _managerEventOpenSubscription = NotificationService()
        .managerEventOpenRequests
        .listen(_queueOpenAcontecimentoFromNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final initialUser = ref.read(authStateProvider).asData?.value;
      _handleAuthenticatedUserChange(initialUser?.uid);
      final pendingManagerEvent = NotificationService()
          .consumePendingManagerEventReminderId();
      if (pendingManagerEvent != null && pendingManagerEvent.isNotEmpty) {
        _queueOpenAcontecimentoFromNotification(pendingManagerEvent);
      }
    });
  }

  void _handleAuthenticatedUserChange(String? userId) {
    final normalizedUserId = userId?.trim();
    if (normalizedUserId == null || normalizedUserId.isEmpty) {
      _loadedUserId = null;
      _userRemindersListeningFor = null;
      _userRemindersSubscription?.cancel();
      _userRemindersSubscription = null;
      return;
    }
    if (_loadedUserId == normalizedUserId) return;

    _loadedUserId = normalizedUserId;
    _startUserRemindersListener(normalizedUserId);
    unawaited(_loadReminders(normalizedUserId));
    unawaited(_loadFerias());
    unawaited(_loadBaixas());
    unawaited(_loadConsultas());
    unawaited(_loadTeikers());
  }

  String _creatorNameForCurrentUser(AppUserRole role, String? userId) {
    if (role.isAdmin) return 'Admin';
    if (role.isHr) return 'Recursos Humanos';
    if (userId == null || userId.trim().isEmpty) return 'Utilizador';
    return _teikerNamesById[userId] ?? 'Utilizador';
  }

  String _resolveCreatorNameFromData(Map<String, dynamic> data) {
    final fromData = (data['createdByName'] as String?)?.trim();
    if (fromData != null && fromData.isNotEmpty) return fromData;
    final fromId = (data['createdById'] as String?)?.trim();
    if (fromId == null || fromId.isEmpty) return 'Admin';
    return _teikerNamesById[fromId] ?? 'Utilizador';
  }

  String? _buildAdminSubtitle({
    required bool isPrivileged,
    String? clienteName,
    String? creatorName,
    DateTime? createdAt,
    String? teikerName,
  }) {
    if (!isPrivileged) return null;
    final parts = <String>[];
    final client = clienteName?.trim();
    final by = creatorName?.trim();
    final teiker = teikerName?.trim();
    if (client != null && client.isNotEmpty) {
      parts.add('Cliente: $client');
    }
    if (teiker != null && teiker.isNotEmpty) {
      parts.add('Teiker: $teiker');
    }
    if (by != null && by.isNotEmpty) {
      parts.add('Por: $by');
    }
    if (createdAt != null) {
      parts.add('Às ${DateFormat('HH:mm', 'pt_PT').format(createdAt)}');
    }
    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  Future<void> _loadReminders(String userId) async {
    if (!mounted) return;
    final isPrivileged = ref.read(isPrivilegedProvider);
    final role = ref.read(userRoleProvider);

    final snapshot = await FirebaseFirestore.instance
        .collection('reminders')
        .doc(userId)
        .collection('items')
        .get();

    final Map<DateTime, List<Map<String, dynamic>>> loaded = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final date = (data['date'] as Timestamp?)?.toDate();
      if (date == null) continue;
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final clienteName = data['clienteName'] as String?;
      final creatorName = _resolveCreatorNameFromData(data);
      final teikerName = data['teikerName'] as String?;
      final tag = (data['tag'] as String?)?.trim() ?? 'Lembrete';
      final isAcontecimento = tag == 'Acontecimento';
      if (role.isHr && !_isHrVisibleAgendaTag(tag)) continue;
      final resolved = (data['resolved'] as bool?) ?? (data['done'] as bool?);

      final key = _dayKey(date);
      loaded.putIfAbsent(key, () => []);
      loaded[key]!.add({
        'id': doc.id,
        'title': data['title'],
        'done': resolved ?? (data['done'] ?? false),
        'resolved': resolved ?? false,
        'start': data['start'],
        'end': data['end'],
        'tag': tag,
        'isFerias': false,
        'isAcontecimento': isAcontecimento,
        'date': date,
        'clienteId': data['clienteId'],
        'clienteName': clienteName,
        'teikerId': data['teikerId'],
        'teikerName': teikerName,
        'createdById': data['createdById'],
        'createdByName': data['createdByName'],
        'createdByRole': data['createdByRole'],
        'createdAt': createdAt,
        'description': (data['description'] as String?) ?? '',
        'seenByUserIds': _parseStringList(data['seenByUserIds']),
        'responses': _parseAcontecimentoResponses(data['responses']),
        'resolvedById': data['resolvedById'],
        'resolvedByName': data['resolvedByName'],
        'resolvedAt': (data['resolvedAt'] as Timestamp?)?.toDate(),
        'subtitle': _buildAdminSubtitle(
          isPrivileged: isPrivileged,
          clienteName: clienteName,
          creatorName: creatorName,
          createdAt: createdAt,
          teikerName: teikerName,
        ),
        'adminReminderId': data['adminReminderId'],
        'adminSource': false,
        if (isAcontecimento) 'cor': selectedColor,
      });
    }

    if (isPrivileged) {
      final adminSnapshot = await FirebaseFirestore.instance
          .collection('admin_reminders')
          .get();

      for (final doc in adminSnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate();
        if (date == null) continue;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final clienteName = data['clienteName'] as String?;
        final creatorName = _resolveCreatorNameFromData(data);
        final teikerName = data['teikerName'] as String?;
        final tag = (data['tag'] as String?)?.trim();
        final isAcontecimento = tag == 'Acontecimento';
        if (role.isHr && !_isHrVisibleAgendaTag(tag)) continue;
        final sourceUserId = (data['sourceUserId'] as String?)?.trim();
        if (sourceUserId != null &&
            sourceUserId.isNotEmpty &&
            sourceUserId == userId) {
          // Evita duplicar acontecimentos/lembretes que a própria gestora já tem
          // no seu espaço pessoal.
          continue;
        }
        final resolved = (data['resolved'] as bool?) ?? (data['done'] as bool?);
        final key = _dayKey(date);
        loaded.putIfAbsent(key, () => []);
        loaded[key]!.add({
          'id': doc.id,
          'title': data['title'],
          'done': resolved ?? (data['done'] ?? false),
          'resolved': resolved ?? false,
          'start': data['start'],
          'end': data['end'],
          'tag': tag ?? 'Lembrete',
          'isFerias': false,
          'isAcontecimento': isAcontecimento,
          'date': date,
          'clienteId': data['clienteId'],
          'clienteName': clienteName,
          'teikerId': data['teikerId'],
          'teikerName': teikerName,
          'createdById': data['createdById'],
          'createdByName': data['createdByName'],
          'createdByRole': data['createdByRole'],
          'createdAt': createdAt,
          'description': (data['description'] as String?) ?? '',
          'seenByUserIds': _parseStringList(data['seenByUserIds']),
          'responses': _parseAcontecimentoResponses(data['responses']),
          'resolvedById': data['resolvedById'],
          'resolvedByName': data['resolvedByName'],
          'resolvedAt': (data['resolvedAt'] as Timestamp?)?.toDate(),
          'subtitle': _buildAdminSubtitle(
            isPrivileged: true,
            clienteName: clienteName,
            creatorName: creatorName,
            createdAt: createdAt,
            teikerName: teikerName,
          ),
          'sourceUserId': data['sourceUserId'],
          'sourceReminderId': data['sourceReminderId'],
          'adminSource': true,
          if (isAcontecimento) 'cor': selectedColor,
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _events
        ..clear()
        ..addAll(loaded);
      _loadedUserId = userId;
    });
    _tryOpenPendingAcontecimentoFromNotification();

    if (isPrivileged && !_adminRemindersListening) {
      _startAdminRemindersListener(userId);
    }
  }

  Future<void> _loadFerias() async {
    if (!mounted) return;
    final authService = ref.read(authServiceProvider);
    final feriasRaw = await authService.getFeriasTeikers();

    final List<Map<String, dynamic>> feriasProcessed = [];

    for (final f in feriasRaw) {
      final dias = (f['dias'] as List).map((d) {
        if (d is DateTime) return d;
        if (d is String) return DateTime.parse(d);
        return DateTime.now();
      }).toList();

      final corTeiker = f['cor'] is int
          ? Color(f['cor'])
          : (f['cor'] is Color ? f['cor'] : Colors.green);

      feriasProcessed.add({
        'uid': f['uid'],
        'nome': f['nome'],
        'dias': dias,
        'cor': corTeiker,
      });
    }

    if (!mounted) return;

    setState(() => teikersFerias = feriasProcessed);
  }

  Future<void> _loadBaixas() async {
    if (!mounted) return;
    final authService = ref.read(authServiceProvider);
    final baixasRaw = await authService.getBaixasTeikers();

    final List<Map<String, dynamic>> baixasProcessed = [];
    for (final b in baixasRaw) {
      final dias = (b['dias'] as List).map((d) {
        if (d is DateTime) return d;
        if (d is String) return DateTime.parse(d);
        return DateTime.now();
      }).toList();

      final cor = b['cor'] is int
          ? Color(b['cor'])
          : (b['cor'] is Color ? b['cor'] : Colors.red.shade700);

      baixasProcessed.add({
        'uid': b['uid'],
        'nome': b['nome'],
        'dias': dias,
        'cor': cor,
      });
    }

    if (!mounted) return;
    setState(() => teikersBaixas = baixasProcessed);
  }

  Future<void> _loadClientes() async {
    if (!mounted) return;
    final authService = ref.read(authServiceProvider);
    final clientes = await authService.getClientes();
    if (!mounted) return;
    setState(() => _clientes = clientes);
  }

  Future<void> _loadTeikers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('teikers')
          .get();

      final pickerList = <Map<String, String>>[];
      final birthdays = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = (data['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;

        pickerList.add({'uid': doc.id, 'name': name});

        final birthDate =
            _parseDate(data['birthDate']) ?? _parseDate(data['dataNascimento']);
        if (birthDate != null) {
          birthdays.add({
            'uid': doc.id,
            'name': name,
            'birthDate': DateTime(
              birthDate.year,
              birthDate.month,
              birthDate.day,
            ),
          });
        }
      }

      pickerList.sort(
        (a, b) => a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
      );
      birthdays.sort(
        (a, b) => (a['name'] as String).toLowerCase().compareTo(
          (b['name'] as String).toLowerCase(),
        ),
      );

      final map = <String, String>{
        for (final item in pickerList) item['uid']!: item['name']!,
      };

      if (!mounted) return;
      setState(() {
        _teikers = pickerList;
        _teikerBirthdays = birthdays;
        _teikerNamesById = map;
      });
      final currentUserId = _loadedUserId;
      if (currentUserId != null) {
        _loadReminders(currentUserId);
      }
    } catch (_) {}
  }

  void _startTeikerListener() {
    _teikerSubscription?.cancel();
    _teikerSubscription = FirebaseFirestore.instance
        .collection('teikers')
        .snapshots()
        .listen((_) {
          _loadFerias();
          _loadBaixas();
          _loadConsultas();
          _loadClientes();
          _loadTeikers();
        });
  }

  void _startAdminRemindersListener(String userId) {
    _adminRemindersSubscription?.cancel();
    _adminRemindersListening = true;
    _adminRemindersSubscription = FirebaseFirestore.instance
        .collection('admin_reminders')
        .snapshots()
        .listen((_) {
          _loadReminders(userId);
        });
  }

  void _startUserRemindersListener(String userId) {
    if (_userRemindersListeningFor == userId &&
        _userRemindersSubscription != null) {
      return;
    }
    _userRemindersSubscription?.cancel();
    _userRemindersListeningFor = userId;
    _userRemindersSubscription = FirebaseFirestore.instance
        .collection('reminders')
        .doc(userId)
        .collection('items')
        .snapshots()
        .listen((_) {
          _loadReminders(userId);
        });
  }

  Future<void> _loadConsultas() async {
    if (!mounted) return;
    final authService = ref.read(authServiceProvider);
    final userId = ref.read(authStateProvider).asData?.value?.uid;
    final isPrivileged = ref.read(isPrivilegedProvider);
    final consultasRaw = await authService.getConsultasTeikers();

    final Map<DateTime, List<Map<String, dynamic>>> grouped = {};

    for (final c in consultasRaw) {
      final date = c['data'] as DateTime?;
      if (date == null) continue;

      final isOwn = userId != null && c['uid'] == userId;
      final title = (!isPrivileged && isOwn)
          ? "Tenho consulta!"
          : (isOwn ? "Tenho consulta!" : "${c['nome']} tem consulta");

      final key = _dayKey(date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add({
        'title': title,
        'descricao': c['descricao'],
        'uid': c['uid'],
        'date': date,
        'start': DateFormat('HH:mm', 'pt_PT').format(date),
        'isConsulta': true,
        'cor': c['cor'],
        'tag': 'Consulta',
      });
    }

    if (!mounted) return;
    setState(() {
      _consultas
        ..clear()
        ..addAll(grouped);
    });
  }

  Future<void> _addEvent(Map<String, dynamic> event) async {
    final key = _dayKey(event['date']);
    final role = ref.read(userRoleProvider);
    final createdAt = event['createdAt'] as DateTime?;
    final clienteName = event['clienteName'] as String?;
    final teikerName = event['teikerName'] as String?;
    final userId = _loadedUserId;
    final creatorName = _creatorNameForCurrentUser(role, userId);
    final tag = (event['tag'] as String?)?.trim();
    final isAcontecimento = tag == 'Acontecimento';

    final newEvent = {
      'title': event['title'],
      'description': (event['description'] as String?)?.trim() ?? '',
      'done': false,
      'resolved': false,
      'start': event['start'],
      'end': event['end'],
      'tag': tag,
      'isFerias': false,
      'isAcontecimento': isAcontecimento,
      'date': event['date'],
      'clienteId': event['clienteId'],
      'clienteName': event['clienteName'],
      'teikerId': event['teikerId'],
      'teikerName': teikerName,
      'createdById': userId,
      'createdByName': creatorName,
      'createdByRole': role.name,
      'createdAt': event['createdAt'],
      'seenByUserIds': const <String>[],
      'responses': const <Map<String, dynamic>>[],
      'subtitle': _buildAdminSubtitle(
        isPrivileged: role.isPrivileged,
        clienteName: clienteName,
        creatorName: creatorName,
        createdAt: createdAt,
        teikerName: teikerName,
      ),
      'adminReminderId': null,
      if (isAcontecimento) 'cor': selectedColor,
    };

    Future<String?> saveToDb() async {
      if (userId == null) return null;
      final doc = await FirebaseFirestore.instance
          .collection('reminders')
          .doc(userId)
          .collection('items')
          .add({
            'title': newEvent['title'],
            'description': newEvent['description'],
            'date': Timestamp.fromDate(newEvent['date']),
            'start': newEvent['start'],
            'end': newEvent['end'],
            'done': newEvent['done'],
            'resolved': newEvent['resolved'],
            'tag': newEvent['tag'],
            'clienteId': newEvent['clienteId'],
            'clienteName': newEvent['clienteName'],
            'teikerId': newEvent['teikerId'],
            'teikerName': newEvent['teikerName'],
            'createdById': newEvent['createdById'],
            'createdByName': newEvent['createdByName'],
            'createdByRole': newEvent['createdByRole'],
            'seenByUserIds': newEvent['seenByUserIds'],
            'responses': newEvent['responses'],
            'createdAt': newEvent['createdAt'] != null
                ? Timestamp.fromDate(newEvent['createdAt'])
                : Timestamp.now(),
            'adminReminderId': null,
          });
      return doc.id;
    }

    final id = await saveToDb();
    if (id != null) newEvent['id'] = id;

    final adminId = await _notifyAdminsIfNeeded(
      newEvent,
      sourceUserId: userId,
      sourceReminderId: id,
    );
    if (adminId != null && userId != null && id != null) {
      newEvent['adminReminderId'] = adminId;
      await FirebaseFirestore.instance
          .collection('reminders')
          .doc(userId)
          .collection('items')
          .doc(id)
          .update({'adminReminderId': adminId});
    }

    if (!mounted) return;
    setState(() {
      _selectedDay = event['date'];
      _focusedDay = event['date'];

      // Evita duplicados quando o listener do Firestore já carregou este item.
      _events.putIfAbsent(key, () => []);
      final alreadyExists = id != null
          ? _events[key]!.any((e) => e['id'] == id)
          : false;
      if (!alreadyExists) {
        _events[key]!.add(newEvent);
      }
    });
  }

  Future<String?> _notifyAdminsIfNeeded(
    Map<String, dynamic> event, {
    required String? sourceUserId,
    required String? sourceReminderId,
  }) async {
    final role = ref.read(userRoleProvider);
    final tag = (event['tag'] as String?)?.trim() ?? '';
    final isAcontecimento = tag == 'Acontecimento';
    final shouldMirrorToManagers =
        role.isTeiker || (role.isPrivileged && isAcontecimento);
    if (!shouldMirrorToManagers) return null;
    final createdAt = event['createdAt'] as DateTime? ?? DateTime.now();
    final payload = {
      'title': event['title'],
      'description': event['description'],
      'date': Timestamp.fromDate(event['date'] as DateTime),
      'start': event['start'],
      'end': event['end'],
      'tag': event['tag'],
      'done': false,
      'resolved': false,
      'clienteId': event['clienteId'],
      'clienteName': event['clienteName'],
      'teikerId': event['teikerId'],
      'teikerName': event['teikerName'],
      'seenByUserIds': event['seenByUserIds'] ?? const <String>[],
      'responses': event['responses'] ?? const <Map<String, dynamic>>[],
      'createdAt': Timestamp.fromDate(createdAt),
      'createdById': _loadedUserId,
      'createdByName': event['createdByName'],
      'createdByRole': role.name,
      'sourceUserId': sourceUserId,
      'sourceReminderId': sourceReminderId,
    };

    final doc = await FirebaseFirestore.instance
        .collection('admin_reminders')
        .add(payload);
    return doc.id;
  }

  Future<DocumentReference<Map<String, dynamic>>?> _findAdminMirrorDoc({
    required String sourceReminderId,
    String? sourceUserId,
    String? knownAdminReminderId,
  }) async {
    final adminCollection = FirebaseFirestore.instance.collection(
      'admin_reminders',
    );

    final normalizedKnownId = (knownAdminReminderId ?? '').trim();
    if (normalizedKnownId.isNotEmpty) {
      final byIdRef = adminCollection.doc(normalizedKnownId);
      final byIdSnap = await byIdRef.get();
      if (byIdSnap.exists) return byIdRef;
    }

    final query = await adminCollection
        .where('sourceReminderId', isEqualTo: sourceReminderId)
        .limit(8)
        .get();
    if (query.docs.isEmpty) return null;

    final normalizedUserId = (sourceUserId ?? '').trim();
    if (normalizedUserId.isEmpty) return query.docs.first.reference;

    for (final doc in query.docs) {
      final data = doc.data();
      final mirrorSourceUserId =
          (data['sourceUserId'] as String?)?.trim() ?? '';
      final createdById = (data['createdById'] as String?)?.trim() ?? '';
      if (mirrorSourceUserId == normalizedUserId ||
          createdById == normalizedUserId) {
        return doc.reference;
      }
    }

    return query.docs.first.reference;
  }

  Future<DocumentReference<Map<String, dynamic>>?> _findUserReminderDoc({
    required String adminReminderId,
    String? sourceUserId,
    String? sourceReminderId,
  }) async {
    final normalizedSourceUserId = (sourceUserId ?? '').trim();
    final normalizedSourceReminderId = (sourceReminderId ?? '').trim();
    if (normalizedSourceUserId.isNotEmpty &&
        normalizedSourceReminderId.isNotEmpty) {
      final directRef = FirebaseFirestore.instance
          .collection('reminders')
          .doc(normalizedSourceUserId)
          .collection('items')
          .doc(normalizedSourceReminderId);
      final directSnap = await directRef.get();
      if (directSnap.exists) return directRef;
    }

    if (normalizedSourceUserId.isNotEmpty) {
      final scoped = await FirebaseFirestore.instance
          .collection('reminders')
          .doc(normalizedSourceUserId)
          .collection('items')
          .where('adminReminderId', isEqualTo: adminReminderId)
          .limit(1)
          .get();
      if (scoped.docs.isNotEmpty) return scoped.docs.first.reference;
    }

    final anyUser = await FirebaseFirestore.instance
        .collectionGroup('items')
        .where('adminReminderId', isEqualTo: adminReminderId)
        .limit(1)
        .get();
    if (anyUser.docs.isEmpty) return null;
    return anyUser.docs.first.reference;
  }

  Future<List<DocumentReference<Map<String, dynamic>>>> _resolveEventDocRefs(
    Map<String, dynamic> event,
  ) async {
    final refs = <DocumentReference<Map<String, dynamic>>>[];
    final eventId = (event['id'] as String?)?.trim() ?? '';
    if (eventId.isEmpty) return refs;

    if (event['adminSource'] == true) {
      refs.add(
        FirebaseFirestore.instance.collection('admin_reminders').doc(eventId),
      );
      final sourceUserId = (event['sourceUserId'] as String?)?.trim();
      final sourceReminderId = (event['sourceReminderId'] as String?)?.trim();
      final sourceRef = await _findUserReminderDoc(
        adminReminderId: eventId,
        sourceUserId: sourceUserId,
        sourceReminderId: sourceReminderId,
      );
      if (sourceRef != null) refs.add(sourceRef);
    } else {
      final userId = (_loadedUserId ?? '').trim();
      if (userId.isNotEmpty) {
        refs.add(
          FirebaseFirestore.instance
              .collection('reminders')
              .doc(userId)
              .collection('items')
              .doc(eventId),
        );
      }
      final adminReminderId = (event['adminReminderId'] as String?)?.trim();
      final adminMirror = await _findAdminMirrorDoc(
        sourceReminderId: eventId,
        sourceUserId: _loadedUserId,
        knownAdminReminderId: adminReminderId,
      );
      if (adminMirror != null) refs.add(adminMirror);
    }

    final uniqueByPath = <String, DocumentReference<Map<String, dynamic>>>{};
    for (final ref in refs) {
      uniqueByPath[ref.path] = ref;
    }
    return uniqueByPath.values.toList();
  }

  Future<void> _updateEventAcrossRefs(
    Map<String, dynamic> event,
    Map<String, dynamic> payload,
  ) async {
    final refs = await _resolveEventDocRefs(event);
    if (refs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final ref in refs) {
      batch.update(ref, payload);
    }
    await batch.commit();
  }

  Future<void> _markAcontecimentoSeen(Map<String, dynamic> event) async {
    if (!_isAcontecimento(event)) return;
    final userId = (_loadedUserId ?? '').trim();
    if (userId.isEmpty) return;

    final seenBy = _parseStringList(event['seenByUserIds']);
    if (seenBy.contains(userId)) return;

    await _updateEventAcrossRefs(event, {
      'seenByUserIds': FieldValue.arrayUnion([userId]),
    });

    if (!mounted) return;
    setState(() {
      event['seenByUserIds'] = [...seenBy, userId];
    });
  }

  Future<void> _toggleAcontecimentoResolved(
    Map<String, dynamic> event, {
    required bool resolved,
  }) async {
    final role = ref.read(userRoleProvider);
    final userId = (_loadedUserId ?? '').trim();
    final userName = _creatorNameForCurrentUser(
      role,
      userId.isEmpty ? null : userId,
    );
    final now = Timestamp.now();

    final payload = <String, dynamic>{
      'resolved': resolved,
      'done': resolved,
      'resolvedAt': resolved ? now : null,
      'resolvedById': resolved ? (userId.isEmpty ? null : userId) : null,
      'resolvedByName': resolved ? userName : null,
    };

    await _updateEventAcrossRefs(event, payload);

    if (!mounted) return;
    setState(() {
      event['resolved'] = resolved;
      event['done'] = resolved;
      event['resolvedById'] = resolved
          ? (userId.isEmpty ? null : userId)
          : null;
      event['resolvedByName'] = resolved ? userName : null;
      event['resolvedAt'] = resolved ? DateTime.now() : null;
    });
  }

  Future<void> _addAcontecimentoResponse(
    Map<String, dynamic> event,
    String message,
  ) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final role = ref.read(userRoleProvider);
    final userId = (_loadedUserId ?? '').trim();
    final createdAt = DateTime.now();
    final replyForDb = <String, dynamic>{
      'id': createdAt.microsecondsSinceEpoch.toString(),
      'message': trimmed,
      'authorId': userId,
      'authorName': _creatorNameForCurrentUser(
        role,
        userId.isEmpty ? null : userId,
      ),
      'authorRole': role.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };

    await _updateEventAcrossRefs(event, {
      'responses': FieldValue.arrayUnion([replyForDb]),
    });

    final localReplies = List<Map<String, dynamic>>.from(
      (event['responses'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ??
          const <Map<String, dynamic>>[],
    );
    localReplies.add({...replyForDb, 'createdAt': createdAt});
    localReplies.sort((a, b) {
      final aDate = a['createdAt'] as DateTime?;
      final bDate = b['createdAt'] as DateTime?;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return -1;
      if (bDate == null) return 1;
      return aDate.compareTo(bDate);
    });

    if (!mounted) return;
    setState(() => event['responses'] = localReplies);
  }

  Future<void> _updateAcontecimentoDetails({
    required Map<String, dynamic> event,
    required String title,
    required String description,
    required DateTime date,
    required String teikerId,
    required String teikerName,
  }) async {
    final role = ref.read(userRoleProvider);
    final creatorName =
        (event['createdByName'] as String?)?.trim().isNotEmpty == true
        ? (event['createdByName'] as String).trim()
        : _creatorNameForCurrentUser(role, _loadedUserId);
    final createdAt = event['createdAt'] as DateTime?;
    final payload = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'teikerId': teikerId,
      'teikerName': teikerName,
    };

    await _updateEventAcrossRefs(event, payload);

    final previousDayKey = _dayKey(event['date'] as DateTime);
    final nextDate = DateTime(date.year, date.month, date.day);
    final nextDayKey = _dayKey(nextDate);

    if (!mounted) return;
    setState(() {
      event['title'] = title.trim();
      event['description'] = description.trim();
      event['date'] = nextDate;
      event['teikerId'] = teikerId;
      event['teikerName'] = teikerName;
      event['subtitle'] = _buildAdminSubtitle(
        isPrivileged: role.isPrivileged,
        clienteName: event['clienteName'] as String?,
        creatorName: creatorName,
        createdAt: createdAt,
        teikerName: teikerName,
      );

      if (previousDayKey != nextDayKey) {
        _events[previousDayKey]?.remove(event);
        if ((_events[previousDayKey]?.isEmpty ?? false)) {
          _events.remove(previousDayKey);
        }
        _events.putIfAbsent(nextDayKey, () => []);
        _events[nextDayKey]!.add(event);
        _selectedDay = nextDate;
        _focusedDay = DateTime(nextDate.year, nextDate.month, 1);
      }
    });
  }

  Future<bool> _showEditAcontecimentoSheet(Map<String, dynamic> event) async {
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => EventAddSheet(
        initialDate: event['date'] as DateTime? ?? _selectedDay,
        primaryColor: selectedColor,
        onAddEvent: (data) => Navigator.pop(context, data),
        clientes: _clientes,
        teikers: _teikers,
        sheetTitle: 'Editar Acontecimento',
        titleLabel: 'Título',
        submitLabel: 'Guardar alterações',
        showClienteSelector: false,
        showTeikerSelector: true,
        showDescriptionField: true,
        descriptionLabel: 'Descrição',
        eventTag: 'Acontecimento',
        initialTitle: (event['title'] as String?) ?? '',
        initialDescription: (event['description'] as String?) ?? '',
        initialTeikerId: (event['teikerId'] as String?)?.trim(),
      ),
    );
    if (updated == null) return false;

    final teikerId = (updated['teikerId'] as String?)?.trim() ?? '';
    final teikerName = (updated['teikerName'] as String?)?.trim() ?? '';
    final date = updated['date'] as DateTime?;
    final title = (updated['title'] as String?)?.trim() ?? '';
    final description = (updated['description'] as String?)?.trim() ?? '';
    if (teikerId.isEmpty ||
        teikerName.isEmpty ||
        date == null ||
        title.isEmpty) {
      return false;
    }

    await _updateAcontecimentoDetails(
      event: event,
      title: title,
      description: description,
      date: date,
      teikerId: teikerId,
      teikerName: teikerName,
    );
    return true;
  }

  Future<void> _showAcontecimentoDetailsDialog(
    Map<String, dynamic> event,
  ) async {
    await _markAcontecimentoSeen(event);
    if (!mounted) return;

    final replyController = TextEditingController();
    bool sendingReply = false;
    bool savingState = false;
    bool deleting = false;

    Future<void> handleDelete(
      BuildContext dialogContext,
      StateSetter setDialogState,
    ) async {
      final confirmed = await AppConfirmDialog.show(
        context: context,
        title: 'Eliminar acontecimento',
        message: 'Tens a certeza que queres eliminar este acontecimento?',
        confirmLabel: 'Eliminar',
        confirmColor: Colors.red.shade700,
      );
      if (confirmed != true) return;
      if (!dialogContext.mounted) return;
      setDialogState(() => deleting = true);
      try {
        final dayKey = _dayKey(event['date'] as DateTime);
        await _deleteEvent(dayKey, event);
        if (dialogContext.mounted) {
          Navigator.pop(dialogContext);
        }
      } finally {
        if (dialogContext.mounted) {
          setDialogState(() => deleting = false);
        }
      }
    }

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final currentUserId = (_loadedUserId ?? '').trim();
              final creatorId = (event['createdById'] as String?)?.trim() ?? '';
              final canManage =
                  currentUserId.isNotEmpty && creatorId == currentUserId;
              final responses = List<Map<String, dynamic>>.from(
                (event['responses'] as List?)?.map(
                      (e) => Map<String, dynamic>.from(e),
                    ) ??
                    const <Map<String, dynamic>>[],
              );
              final resolved = _isAcontecimentoResolved(event);
              final eventDate = event['date'] as DateTime?;
              final createdAt = event['createdAt'] as DateTime?;
              final resolvedAt = event['resolvedAt'] is Timestamp
                  ? (event['resolvedAt'] as Timestamp).toDate()
                  : event['resolvedAt'] as DateTime?;
              final title = (event['title'] as String?)?.trim() ?? '';
              final description =
                  (event['description'] as String?)?.trim() ?? '';
              final teikerName =
                  (event['teikerName'] as String?)?.trim() ?? 'Sem teiker';
              final createdBy =
                  (event['createdByName'] as String?)?.trim() ?? 'Utilizador';

              Widget sectionCard({
                required IconData icon,
                required String title,
                required Widget child,
              }) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selectedColor.withValues(alpha: .14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: selectedColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: TextStyle(
                              color: selectedColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      child,
                    ],
                  ),
                );
              }

              Widget infoPill({
                required IconData icon,
                required String label,
                required Color color,
                Color? bgColor,
              }) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (bgColor ?? color).withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: .2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: color),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(
                      MediaQuery.of(dialogContext).size.width - 28,
                      620,
                    ),
                    maxHeight: MediaQuery.of(dialogContext).size.height * .86,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7F3),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .12),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                          decoration: BoxDecoration(
                            color: selectedColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Acontecimento',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        infoPill(
                                          icon: resolved
                                              ? Icons.check_circle_rounded
                                              : Icons.pending_actions_rounded,
                                          label: resolved
                                              ? 'Resolvido'
                                              : 'Por resolver',
                                          color: selectedColor,
                                          bgColor: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (canManage) ...[
                                IconButton(
                                  tooltip: 'Editar',
                                  onPressed:
                                      deleting || savingState || sendingReply
                                      ? null
                                      : () async {
                                          Navigator.pop(dialogContext);
                                          final changed =
                                              await _showEditAcontecimentoSheet(
                                                event,
                                              );
                                          if (!mounted) return;
                                          if (changed) {
                                            unawaited(
                                              _showAcontecimentoDetailsDialog(
                                                event,
                                              ),
                                            );
                                          }
                                        },
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  onPressed:
                                      deleting || savingState || sendingReply
                                      ? null
                                      : () => handleDelete(
                                          dialogContext,
                                          setDialogState,
                                        ),
                                  icon: deleting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.white,
                                        ),
                                ),
                              ],
                              IconButton(
                                tooltip: 'Fechar',
                                onPressed:
                                    sendingReply || savingState || deleting
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                sectionCard(
                                  icon: Icons.event_note_rounded,
                                  title: 'Detalhes',
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          description.isEmpty
                                              ? 'Sem descrição'
                                              : description,
                                          style: TextStyle(
                                            color: description.isEmpty
                                                ? Colors.black54
                                                : Colors.black87,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _detailRow('Teiker', teikerName),
                                      if (eventDate != null) ...[
                                        const SizedBox(height: 8),
                                        _detailRow(
                                          'Dia',
                                          _formatAcontecimentoDate(eventDate),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                sectionCard(
                                  icon: Icons.info_outline_rounded,
                                  title: 'Estado',
                                  child: Column(
                                    children: [
                                      _detailRow('Criado por', createdBy),
                                      if (createdAt != null) ...[
                                        const SizedBox(height: 8),
                                        _detailRow(
                                          'Criado às',
                                          DateFormat(
                                            'dd/MM/yyyy HH:mm',
                                            'pt_PT',
                                          ).format(createdAt),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      _detailRow(
                                        'Estado',
                                        resolved ? 'Resolvido' : 'Por resolver',
                                      ),
                                      if (resolved &&
                                          (event['resolvedByName'] as String?)
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true) ...[
                                        const SizedBox(height: 8),
                                        _detailRow(
                                          'Resolvido por',
                                          (event['resolvedByName'] as String)
                                              .trim(),
                                        ),
                                      ],
                                      if (resolved && resolvedAt != null) ...[
                                        const SizedBox(height: 8),
                                        _detailRow(
                                          'Resolvido às',
                                          DateFormat(
                                            'dd/MM/yyyy HH:mm',
                                            'pt_PT',
                                          ).format(resolvedAt),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: savingState || deleting
                                              ? null
                                              : () async {
                                                  if (!dialogContext.mounted) {
                                                    return;
                                                  }
                                                  setDialogState(
                                                    () => savingState = true,
                                                  );
                                                  try {
                                                    await _toggleAcontecimentoResolved(
                                                      event,
                                                      resolved: !resolved,
                                                    );
                                                  } finally {
                                                    if (dialogContext.mounted) {
                                                      setDialogState(
                                                        () =>
                                                            savingState = false,
                                                      );
                                                    }
                                                  }
                                                },
                                          icon: Icon(
                                            resolved
                                                ? Icons
                                                      .radio_button_unchecked_rounded
                                                : Icons
                                                      .check_circle_outline_rounded,
                                            size: 18,
                                          ),
                                          label: Text(
                                            resolved
                                                ? 'Marcar por resolver'
                                                : 'Marcar resolvido',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: selectedColor,
                                            side: BorderSide(
                                              color: selectedColor.withValues(
                                                alpha: .35,
                                              ),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                sectionCard(
                                  icon: Icons.forum_outlined,
                                  title: 'Respostas',
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (responses.isEmpty)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                          child: const Text(
                                            'Sem respostas ainda.',
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      else
                                        Column(
                                          children: responses.map((reply) {
                                            final msg =
                                                (reply['message'] as String?)
                                                    ?.trim() ??
                                                '';
                                            final author =
                                                (reply['authorName'] as String?)
                                                    ?.trim() ??
                                                'Utilizador';
                                            final date =
                                                reply['createdAt'] as DateTime?;
                                            return Container(
                                              width: double.infinity,
                                              margin: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: Colors.grey.shade200,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          author,
                                                          style: TextStyle(
                                                            color:
                                                                selectedColor,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                      if (date != null)
                                                        Text(
                                                          DateFormat(
                                                            'dd/MM HH:mm',
                                                            'pt_PT',
                                                          ).format(date),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black54,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(msg),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: replyController,
                                        minLines: 2,
                                        maxLines: 4,
                                        decoration: InputDecoration(
                                          labelText: 'Responder',
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: selectedColor.withValues(
                                                alpha: .18,
                                              ),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: selectedColor,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(20),
                            ),
                            border: Border(
                              top: BorderSide(
                                color: selectedColor.withValues(alpha: .12),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      sendingReply || savingState || deleting
                                      ? null
                                      : () => Navigator.pop(dialogContext),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: selectedColor,
                                    side: BorderSide(
                                      color: selectedColor.withValues(
                                        alpha: .35,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Fechar'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      sendingReply || savingState || deleting
                                      ? null
                                      : () async {
                                          final message = replyController.text
                                              .trim();
                                          if (message.isEmpty) return;
                                          if (!dialogContext.mounted) return;
                                          setDialogState(
                                            () => sendingReply = true,
                                          );
                                          try {
                                            await _addAcontecimentoResponse(
                                              event,
                                              message,
                                            );
                                            if (!dialogContext.mounted) return;
                                            replyController.clear();
                                          } finally {
                                            if (dialogContext.mounted) {
                                              setDialogState(
                                                () => sendingReply = false,
                                              );
                                            }
                                          }
                                        },
                                  icon: sendingReply
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send_rounded,
                                          size: 16,
                                        ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  label: const Text('Responder'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      // showDialog() resolves on pop before the reverse animation fully ends;
      // disposing immediately can crash the TextField during the last frames.
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        try {
          replyController.dispose();
        } catch (_) {}
      });
    }
  }

  Widget _detailRow(String label, String value, {bool multiline = false}) {
    return Row(
      crossAxisAlignment: multiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteEvent(DateTime dayKey, Map<String, dynamic> event) async {
    final userId = _loadedUserId;
    final eventId = event['id'] as String?;
    if (eventId != null) {
      final batch = FirebaseFirestore.instance.batch();
      if (event['adminSource'] == true) {
        final adminRef = FirebaseFirestore.instance
            .collection('admin_reminders')
            .doc(eventId);
        batch.delete(adminRef);

        final sourceUserId = (event['sourceUserId'] as String?)?.trim();
        final sourceReminderId = (event['sourceReminderId'] as String?)?.trim();
        final sourceRef = await _findUserReminderDoc(
          adminReminderId: eventId,
          sourceUserId: sourceUserId,
          sourceReminderId: sourceReminderId,
        );
        if (sourceRef != null) {
          batch.delete(sourceRef);
        }
      } else if (userId != null) {
        final userRef = FirebaseFirestore.instance
            .collection('reminders')
            .doc(userId)
            .collection('items')
            .doc(eventId);
        batch.delete(userRef);

        final adminReminderId = (event['adminReminderId'] as String?)?.trim();
        final adminMirror = await _findAdminMirrorDoc(
          sourceReminderId: eventId,
          sourceUserId: userId,
          knownAdminReminderId: adminReminderId,
        );
        if (adminMirror != null) {
          batch.delete(adminMirror);
        }
      }
      await batch.commit();
    }

    if (!mounted) return;
    setState(() {
      _events[dayKey]?.remove(event);
      if ((_events[dayKey]?.isEmpty ?? true)) _events.remove(dayKey);
    });

    HapticFeedback.lightImpact();
  }

  Future<void> _toggleDone(Map<String, dynamic> event) async {
    final previousDone = event['done'] ?? false;
    final nextDone = !previousDone;
    setState(() => event['done'] = nextDone);
    HapticFeedback.mediumImpact();

    final userId = _loadedUserId;
    final eventId = event['id'] as String?;
    if (eventId != null) {
      try {
        if (event['adminSource'] == true) {
          final adminRef = FirebaseFirestore.instance
              .collection('admin_reminders')
              .doc(eventId);
          await adminRef.update({'done': nextDone});

          final sourceUserId = (event['sourceUserId'] as String?)?.trim();
          final sourceReminderId = (event['sourceReminderId'] as String?)
              ?.trim();
          final sourceRef = await _findUserReminderDoc(
            adminReminderId: eventId,
            sourceUserId: sourceUserId,
            sourceReminderId: sourceReminderId,
          );
          if (sourceRef != null) {
            await sourceRef.update({'done': nextDone}).catchError((_) {});
          }
        } else if (userId != null) {
          final userRef = FirebaseFirestore.instance
              .collection('reminders')
              .doc(userId)
              .collection('items')
              .doc(eventId);
          await userRef.update({'done': nextDone});

          final adminReminderId = (event['adminReminderId'] as String?)?.trim();
          final adminMirror = await _findAdminMirrorDoc(
            sourceReminderId: eventId,
            sourceUserId: userId,
            knownAdminReminderId: adminReminderId,
          );
          if (adminMirror != null) {
            await adminMirror.update({'done': nextDone}).catchError((_) {});
            if (adminReminderId == null || adminReminderId.isEmpty) {
              event['adminReminderId'] = adminMirror.id;
              await userRef
                  .update({'adminReminderId': adminMirror.id})
                  .catchError((_) {});
            }
          }
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => event['done'] = previousDone);
      }
    }
  }

  String _appBarTitle() {
    final now = DateTime.now();
    return 'Hoje é ${DateFormat('EEEE, dd MMMM', 'pt_PT').format(now)}';
  }

  String _getEmptyMessage(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(day.year, day.month, day.day);
    if (selected == today) return 'Sem eventos para hoje.';
    if (selected == today.subtract(const Duration(days: 1))) {
      return 'Sem eventos ontem.';
    }
    if (selected == today.add(const Duration(days: 1))) {
      return 'Sem eventos amanhã.';
    }
    return 'Sem eventos neste dia.';
  }

  void _showAddEventSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => EventAddSheet(
        initialDate: _selectedDay,
        primaryColor: selectedColor,
        onAddEvent: _addEvent,
        clientes: _clientes,
        eventTag: 'Lembrete',
      ),
    );
  }

  void _showAddAcontecimentoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => EventAddSheet(
        initialDate: _selectedDay,
        primaryColor: selectedColor,
        onAddEvent: _addEvent,
        clientes: _clientes,
        teikers: _teikers,
        sheetTitle: 'Acontecimento',
        titleLabel: 'Título',
        submitLabel: 'Guardar',
        showClienteSelector: false,
        showTeikerSelector: true,
        showDescriptionField: true,
        descriptionLabel: 'Descrição',
        eventTag: 'Acontecimento',
      ),
    );
  }

  List<Map<String, dynamic>> _birthdayEventsForDay({
    required DateTime dayKey,
    required bool isAdmin,
    required String? userId,
  }) {
    final events = <Map<String, dynamic>>[];
    for (final birthday in _teikerBirthdays) {
      final uid = birthday['uid'] as String? ?? '';
      final birthDate = birthday['birthDate'] as DateTime?;
      if (uid.isEmpty || birthDate == null) continue;
      if (!isAdmin && uid != userId) continue;

      final occurrence = _birthdayDateInYear(birthDate, dayKey.year);
      if (_dayKey(occurrence) != dayKey) continue;

      final name = birthday['name'] as String? ?? 'Teiker';
      events.add({
        'title': isAdmin
            ? 'Aniversário de $name'
            : 'A Teiker deseja-te um Feliz Aniversário',
        'done': false,
        'start': '',
        'end': '',
        'isFerias': true,
        'isBirthday': true,
        'cor': Colors.orange.shade700,
        'tag': 'Aniversário',
      });
    }
    return events;
  }

  Map<DateTime, List<Map<String, dynamic>>> _birthdayCalendarEvents({
    required int year,
    required bool isAdmin,
    required String? userId,
  }) {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final birthday in _teikerBirthdays) {
      final uid = birthday['uid'] as String? ?? '';
      final birthDate = birthday['birthDate'] as DateTime?;
      if (uid.isEmpty || birthDate == null) continue;
      if (!isAdmin && uid != userId) continue;
      final occurrence = _birthdayDateInYear(birthDate, year);
      final key = _dayKey(occurrence);
      map.putIfAbsent(key, () => []);
      map[key]!.add({
        'title': 'Aniversário',
        'isBirthday': true,
        'cor': Colors.orange.shade700,
        'tag': 'Aniversário',
      });
    }
    return map;
  }

  Widget _buildEventListBody({
    required List<Map<String, dynamic>> events,
    required DateTime dayKey,
    required Color color,
    String? emptyMessage,
    bool hideReminderTag = false,
  }) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final listBottomPadding = bottomSafeArea + AppBottomNavBar.barHeight + 12;

    if (events.isEmpty) {
      return Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
        child: Center(
          child: Text(
            emptyMessage ?? _getEmptyMessage(_selectedDay),
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Scrollbar(
      child: ListView.builder(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.only(bottom: listBottomPadding),
        itemCount: events.length,
        itemBuilder: (context, i) {
          final event = events[i];
          final bool isFerias = event['isFerias'] == true;
          final bool isConsulta = event['isConsulta'] == true;
          final bool isAcontecimento = _isAcontecimento(event);
          final bool isTeikerMarcacao = _isTeikerMarcacaoAgendaEvent(event);
          final start = (event['start'] ?? '').toString();
          final end = (event['end'] ?? '').toString();
          final hasHourRange = start.isNotEmpty || end.isNotEmpty;
          final bool readOnly =
              isFerias || isConsulta || isAcontecimento || isTeikerMarcacao;
          final itemColor =
              (isFerias || isConsulta || isAcontecimento || isTeikerMarcacao)
              ? (event['cor'] as Color? ?? color)
              : color;
          final rawTag = event['tag'] as String?;
          final tag = hideReminderTag && _isReminder(event) ? '' : rawTag;
          final seenCounterpart = isAcontecimento
              ? _isAcontecimentoSeenByCounterpart(event)
              : false;

          return EventItem(
            event: event,
            selectedColor: itemColor,
            showHours: !isFerias && !isAcontecimento && hasHourRange,
            readOnly: readOnly,
            tag: tag,
            onTap: isAcontecimento
                ? () => _showAcontecimentoDetailsDialog(event)
                : null,
            trailingWidget: isAcontecimento
                ? Icon(
                    seenCounterpart
                        ? Icons.visibility_rounded
                        : Icons.visibility_outlined,
                    color: itemColor,
                    size: 20,
                  )
                : null,
            onToggleDone: () {
              if (!readOnly) {
                _toggleDone(event);
              }
            },
            onDelete: () {
              if (!readOnly) {
                _deleteEvent(dayKey, event);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildSwipableEventLists({
    required DateTime dayKey,
    required List<Map<String, dynamic>> leftEvents,
    required List<Map<String, dynamic>> rightEvents,
    required String leftLabel,
    required String rightLabel,
    required int currentPage,
    required PageController controller,
    required ValueChanged<int> onPageChanged,
    required String leftEmptyMessage,
    required String rightEmptyMessage,
    bool hideLeftReminderTag = false,
    bool hideRightReminderTag = false,
  }) {
    final agendaCount = rightEvents.length;
    final showAgendaCount = currentPage != 1 && agendaCount > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 74;
        final tabSpacing = compact ? 0.0 : 10.0;
        final tabVerticalPadding = compact ? 4.0 : 10.0;
        final canShowList = constraints.maxHeight > (compact ? 36 : 74);

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _eventListTabButton(
                    label: leftLabel,
                    selected: currentPage == 0,
                    verticalPadding: tabVerticalPadding,
                    onTap: () => controller.animateToPage(
                      0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _eventListTabButton(
                    label: rightLabel,
                    selected: currentPage == 1,
                    count: showAgendaCount ? agendaCount : null,
                    verticalPadding: tabVerticalPadding,
                    onTap: () => controller.animateToPage(
                      1,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: tabSpacing),
            if (canShowList)
              Expanded(
                child: PageView(
                  controller: controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: onPageChanged,
                  children: [
                    _buildEventListBody(
                      events: leftEvents,
                      dayKey: dayKey,
                      color: selectedColor,
                      emptyMessage: leftEmptyMessage,
                      hideReminderTag: hideLeftReminderTag,
                    ),
                    _buildEventListBody(
                      events: rightEvents,
                      dayKey: dayKey,
                      color: selectedColor,
                      emptyMessage: rightEmptyMessage,
                      hideReminderTag: hideRightReminderTag,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAdminSwipableLists({
    required DateTime dayKey,
    required List<Map<String, dynamic>> reminderEvents,
    required List<Map<String, dynamic>> infoEvents,
  }) {
    return _buildSwipableEventLists(
      dayKey: dayKey,
      leftEvents: reminderEvents,
      rightEvents: infoEvents,
      leftLabel: 'Lembretes',
      rightLabel: 'Agenda',
      currentPage: _adminEventsPage,
      controller: _adminEventsPageController,
      onPageChanged: (index) => setState(() => _adminEventsPage = index),
      leftEmptyMessage: 'Sem lembretes neste dia.',
      rightEmptyMessage: 'Sem itens da agenda neste dia.',
      hideLeftReminderTag: true,
    );
  }

  Widget _buildTeikerSwipableLists({
    required DateTime dayKey,
    required List<Map<String, dynamic>> reminderEvents,
    required List<Map<String, dynamic>> infoEvents,
  }) {
    return _buildSwipableEventLists(
      dayKey: dayKey,
      leftEvents: reminderEvents,
      rightEvents: infoEvents,
      leftLabel: 'Lembretes',
      rightLabel: 'Agenda',
      currentPage: _teikerEventsPage,
      controller: _teikerEventsPageController,
      onPageChanged: (index) => setState(() => _teikerEventsPage = index),
      leftEmptyMessage: 'Sem lembretes neste dia.',
      rightEmptyMessage: 'Sem itens da agenda neste dia.',
      hideLeftReminderTag: true,
    );
  }

  Widget _eventListTabButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? count,
    double verticalPadding = 10,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: .14)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? selectedColor
                : selectedColor.withValues(alpha: .16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? selectedColor : Colors.black87,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selectedColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _teikerSubscription?.cancel();
    _adminRemindersSubscription?.cancel();
    _userRemindersSubscription?.cancel();
    _managerEventOpenSubscription?.cancel();
    _adminEventsPageController.dispose();
    _teikerEventsPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      final nextUser = next.asData?.value;
      _handleAuthenticatedUserChange(nextUser?.uid);
    });

    final authState = ref.watch(authStateProvider);
    final role = ref.watch(userRoleProvider);
    final isPrivileged = ref.watch(isPrivilegedProvider);
    final isHr = role.isHr;
    final isAdmin = role.isAdmin;
    final user = authState.asData?.value;
    final dayKey = _dayKey(_selectedDay);
    final normalEvents = _events[dayKey] ?? [];
    final consultasEventsAll = _consultas[dayKey] ?? [];
    final birthdayEvents = _birthdayEventsForDay(
      dayKey: dayKey,
      isAdmin: isPrivileged,
      userId: user?.uid,
    );

    final feriasEventsAll = teikersFerias
        .where((t) => t['dias'].any((d) => _dayKey(d) == dayKey))
        .map((t) {
          final bool isOwn = user != null && t['uid'] == user.uid;

          return {
            'uid': t['uid'],
            'title': isOwn ? "Estou de férias!" : "${t['nome']} está de férias",
            'done': false,
            'start': dayKey,
            'end': dayKey,
            'cor': t['cor'],
            'isFerias': true,
            'tag': 'Férias',
          };
        })
        .toList();
    final feriasEvents = isPrivileged
        ? feriasEventsAll
        : feriasEventsAll.where((event) => event['uid'] == user?.uid).toList();
    final baixasEventsAll = teikersBaixas
        .where((t) => t['dias'].any((d) => _dayKey(d) == dayKey))
        .map((t) {
          final bool isOwn = user != null && t['uid'] == user.uid;

          return {
            'uid': t['uid'],
            'title': isOwn ? "Estou de baixa!" : "${t['nome']} está de baixa",
            'done': false,
            'start': dayKey,
            'end': dayKey,
            'cor': t['cor'],
            'isFerias': true,
            'isBaixa': true,
            'tag': 'Baixa',
          };
        })
        .toList();
    final baixasEvents = isPrivileged
        ? baixasEventsAll
        : baixasEventsAll.where((event) => event['uid'] == user?.uid).toList();
    final consultasEvents = isPrivileged
        ? consultasEventsAll
        : consultasEventsAll
              .where((event) => event['uid'] == user?.uid)
              .toList();

    final reminderEvents = isHr
        ? <Map<String, dynamic>>[]
        : normalEvents.where(_isReminder).toList();
    final acontecimentoEvents = normalEvents.where(_isAcontecimento).toList();
    final teikerAgendaEvents = [
      ...birthdayEvents,
      ...feriasEvents,
      ...baixasEvents,
      ...consultasEvents,
    ];
    final adminAgendaEvents = [
      ...feriasEvents,
      ...baixasEvents,
      ...consultasEvents,
      ...birthdayEvents,
      ...acontecimentoEvents,
    ];

    final Map<DateTime, List<Map<String, dynamic>>> calendarEvents = {};
    for (final entry in _events.entries) {
      calendarEvents.putIfAbsent(entry.key, () => []);
      calendarEvents[entry.key]!.addAll(entry.value);
    }
    for (final entry in _consultas.entries) {
      calendarEvents.putIfAbsent(entry.key, () => []);
      calendarEvents[entry.key]!.addAll(entry.value);
    }
    final birthdayCalendar = _birthdayCalendarEvents(
      year: _focusedDay.year,
      isAdmin: isPrivileged,
      userId: user?.uid,
    );
    for (final entry in birthdayCalendar.entries) {
      calendarEvents.putIfAbsent(entry.key, () => []);
      calendarEvents[entry.key]!.addAll(entry.value);
    }

    return Scaffold(
      appBar: buildAppBar(_appBarTitle(), seta: false),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const controlsAndSpacingHeight = 84.0;
          const minEventsPanelHeight = 90.0;
          final targetCalendarHeight =
              MediaQuery.of(context).size.height * 0.45;
          final availableCalendarHeight = math.max(
            0.0,
            constraints.maxHeight -
                controlsAndSpacingHeight -
                minEventsPanelHeight,
          );
          final calendarMaxHeight = math.min(
            targetCalendarHeight,
            availableCalendarHeight,
          );

          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: MediaQuery.of(context).size.height * 0.50,
                      child: ClipPath(
                        clipper: CurvedCalendarClipper(),
                        child: Container(color: selectedColor),
                      ),
                    ),
                    Column(
                      children: [
                        // Calendário
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ModernCalendar(
                            focusedDay: _focusedDay,
                            selectedDay: _selectedDay,
                            primaryColor: selectedColor,
                            todayColor: Colors.greenAccent,
                            events: calendarEvents,
                            maxHeight: calendarMaxHeight,
                            onDaySelected: (day, month) {
                              setState(() {
                                _selectedDay = day;
                                _focusedDay = DateTime(
                                  month.year,
                                  month.month,
                                  1,
                                );
                              });
                            },
                            teikersFerias: [...teikersFerias, ...teikersBaixas],
                          ),
                        ),
                        // Botão para adicionar lembrete
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          margin: const EdgeInsets.only(top: 10),
                          child: isAdmin
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.add, size: 20),
                                        label: const Text(
                                          'Adicionar Lembrete',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: selectedColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          elevation: 4,
                                        ),
                                        onPressed: _showAddEventSheet,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(
                                          Icons.event_available_outlined,
                                          size: 20,
                                        ),
                                        label: const Text(
                                          'Acontecimento',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: selectedColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          elevation: 4,
                                        ),
                                        onPressed: _showAddAcontecimentoSheet,
                                      ),
                                    ),
                                  ],
                                )
                              : isHr
                              ? ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.event_available_outlined,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Acontecimento',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                  onPressed: _showAddAcontecimentoSheet,
                                )
                              : ElevatedButton.icon(
                                  icon: const Icon(Icons.add, size: 20),
                                  label: const Text(
                                    'Adicionar Lembrete',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                  onPressed: _showAddEventSheet,
                                ),
                        ),
                        const SizedBox(height: 10),
                        // Lista de eventos
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: isAdmin
                                ? _buildAdminSwipableLists(
                                    dayKey: dayKey,
                                    reminderEvents: reminderEvents,
                                    infoEvents: adminAgendaEvents,
                                  )
                                : isHr
                                ? _buildEventListBody(
                                    events: adminAgendaEvents,
                                    dayKey: dayKey,
                                    color: selectedColor,
                                    emptyMessage:
                                        'Sem itens da agenda neste dia.',
                                  )
                                : _buildTeikerSwipableLists(
                                    dayKey: dayKey,
                                    reminderEvents: reminderEvents,
                                    infoEvents: teikerAgendaEvents,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

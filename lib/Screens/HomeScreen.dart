import 'dart:async';

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
import 'package:teiker_app/auth/auth_notifier.dart';
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
  List<Clientes> _clientes = [];
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final Color selectedColor = AppColors.primaryGreen;
  String? _loadedUserId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _teikerSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _adminRemindersSubscription;
  bool _adminRemindersListening = false;

  DateTime _dayKey(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _loadFerias();
    _loadConsultas();
    _loadClientes();
    _startTeikerListener();
  }

  Future<void> _loadReminders(String userId) async {
    if (!mounted) return;
    final isAdmin = ref.read(isAdminProvider);

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

      final key = _dayKey(date);
      loaded.putIfAbsent(key, () => []);
      loaded[key]!.add({
        'id': doc.id,
        'title': data['title'],
        'done': data['done'] ?? false,
        'start': data['start'],
        'end': data['end'],
        'isFerias': false,
        'date': date,
        'clienteId': data['clienteId'],
        'clienteName': clienteName,
        'createdAt': createdAt,
        'subtitle': isAdmin && clienteName != null && createdAt != null
            ? 'Cliente: $clienteName • Adicionado: ${DateFormat('HH:mm').format(createdAt)}'
            : null,
        'adminReminderId': data['adminReminderId'],
        'adminSource': false,
      });
    }

    if (isAdmin) {
      final adminSnapshot = await FirebaseFirestore.instance
          .collection('admin_reminders')
          .get();

      for (final doc in adminSnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate();
        if (date == null) continue;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final clienteName = data['clienteName'] as String?;
        final key = _dayKey(date);
        loaded.putIfAbsent(key, () => []);
        loaded[key]!.add({
          'id': doc.id,
          'title': data['title'],
          'done': data['done'] ?? false,
          'start': data['start'],
          'end': data['end'],
          'isFerias': false,
          'date': date,
          'clienteId': data['clienteId'],
          'clienteName': clienteName,
          'createdAt': createdAt,
          'subtitle': clienteName != null && createdAt != null
              ? 'Cliente: $clienteName • Adicionado: ${DateFormat('HH:mm').format(createdAt)}'
              : null,
          'tag': 'Lembrete Teiker',
          'sourceUserId': data['sourceUserId'],
          'sourceReminderId': data['sourceReminderId'],
          'adminSource': true,
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

    if (isAdmin && !_adminRemindersListening) {
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

  Future<void> _loadClientes() async {
    if (!mounted) return;
    final authService = ref.read(authServiceProvider);
    final clientes = await authService.getClientes();
    if (!mounted) return;
    setState(() => _clientes = clientes);
  }

  void _startTeikerListener() {
    _teikerSubscription?.cancel();
    _teikerSubscription = FirebaseFirestore.instance
        .collection('teikers')
        .snapshots()
        .listen((_) {
          _loadFerias();
          _loadConsultas();
          _loadClientes();
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

  Future<void> _loadConsultas() async {
    if (!mounted) return;
    final authService = ref.read(authServiceProvider);
    final userId = ref.read(authStateProvider).asData?.value?.uid;
    final isAdmin = ref.read(isAdminProvider);
    final consultasRaw = await authService.getConsultasTeikers();

    final Map<DateTime, List<Map<String, dynamic>>> grouped = {};

    for (final c in consultasRaw) {
      final date = c['data'] as DateTime?;
      if (date == null) continue;

      final isOwn = userId != null && c['uid'] == userId;
      final title = (!isAdmin && isOwn)
          ? "Tenho consulta!"
          : (isOwn ? "Tenho consulta!" : "${c['nome']} tem consulta");

      final key = _dayKey(date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add({
        'title': title,
        'descricao': c['descricao'],
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
    final isAdmin = ref.read(isAdminProvider);
    final createdAt = event['createdAt'] as DateTime?;
    final clienteName = event['clienteName'] as String?;

    final newEvent = {
      'title': event['title'],
      'done': false,
      'start': event['start'],
      'end': event['end'],
      'isFerias': false,
      'date': event['date'],
      'clienteId': event['clienteId'],
      'clienteName': event['clienteName'],
      'createdAt': event['createdAt'],
      'subtitle': isAdmin && clienteName != null && createdAt != null
          ? 'Cliente: $clienteName • Adicionado: ${DateFormat('HH:mm').format(createdAt)}'
          : null,
      'adminReminderId': null,
    };

    final userId = _loadedUserId;

    Future<String?> saveToDb() async {
      if (userId == null) return null;
      final doc = await FirebaseFirestore.instance
          .collection('reminders')
          .doc(userId)
          .collection('items')
          .add({
            'title': newEvent['title'],
            'date': Timestamp.fromDate(newEvent['date']),
            'start': newEvent['start'],
            'end': newEvent['end'],
            'done': newEvent['done'],
            'clienteId': newEvent['clienteId'],
            'clienteName': newEvent['clienteName'],
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
      _events.putIfAbsent(key, () => []);
      _events[key]!.add(newEvent);
      _selectedDay = event['date'];
      _focusedDay = event['date'];
    });
  }

  Future<String?> _notifyAdminsIfNeeded(
    Map<String, dynamic> event, {
    required String? sourceUserId,
    required String? sourceReminderId,
  }) async {
    final isAdmin = ref.read(isAdminProvider);
    if (isAdmin) return null;
    final createdAt = event['createdAt'] as DateTime? ?? DateTime.now();
    final payload = {
      'title': event['title'],
      'date': Timestamp.fromDate(event['date'] as DateTime),
      'start': event['start'],
      'end': event['end'],
      'done': false,
      'clienteId': event['clienteId'],
      'clienteName': event['clienteName'],
      'createdAt': Timestamp.fromDate(createdAt),
      'createdById': _loadedUserId,
      'sourceUserId': sourceUserId,
      'sourceReminderId': sourceReminderId,
    };

    final doc = await FirebaseFirestore.instance
        .collection('admin_reminders')
        .add(payload);
    return doc.id;
  }

  void _deleteEvent(DateTime dayKey, Map<String, dynamic> event) {
    final userId = _loadedUserId;
    final eventId = event['id'] as String?;
    if (eventId != null) {
      if (event['adminSource'] == true) {
        FirebaseFirestore.instance
            .collection('admin_reminders')
            .doc(eventId)
            .delete();
        final sourceUserId = event['sourceUserId'] as String?;
        final sourceReminderId = event['sourceReminderId'] as String?;
        if (sourceUserId != null && sourceReminderId != null) {
          FirebaseFirestore.instance
              .collection('reminders')
              .doc(sourceUserId)
              .collection('items')
              .doc(sourceReminderId)
              .delete();
        }
      } else if (userId != null) {
        FirebaseFirestore.instance
            .collection('reminders')
            .doc(userId)
            .collection('items')
            .doc(eventId)
            .delete();
        final adminReminderId = event['adminReminderId'] as String?;
        if (adminReminderId != null) {
          FirebaseFirestore.instance
              .collection('admin_reminders')
              .doc(adminReminderId)
              .delete();
        }
      }
    }

    setState(() {
      _events[dayKey]?.remove(event);
      if ((_events[dayKey]?.isEmpty ?? true)) _events.remove(dayKey);
    });

    HapticFeedback.lightImpact();
  }

  void _toggleDone(Map<String, dynamic> event) {
    setState(() => event['done'] = !(event['done'] ?? false));
    HapticFeedback.mediumImpact();

    final userId = _loadedUserId;
    final eventId = event['id'] as String?;
    if (eventId != null) {
      if (event['adminSource'] == true) {
        FirebaseFirestore.instance
            .collection('admin_reminders')
            .doc(eventId)
            .update({'done': event['done']});
        final sourceUserId = event['sourceUserId'] as String?;
        final sourceReminderId = event['sourceReminderId'] as String?;
        if (sourceUserId != null && sourceReminderId != null) {
          FirebaseFirestore.instance
              .collection('reminders')
              .doc(sourceUserId)
              .collection('items')
              .doc(sourceReminderId)
              .update({'done': event['done']});
        }
      } else if (userId != null) {
        FirebaseFirestore.instance
            .collection('reminders')
            .doc(userId)
            .collection('items')
            .doc(eventId)
            .update({'done': event['done']});
        final adminReminderId = event['adminReminderId'] as String?;
        if (adminReminderId != null) {
          FirebaseFirestore.instance
              .collection('admin_reminders')
              .doc(adminReminderId)
              .update({'done': event['done']});
        }
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
      ),
    );
  }

  @override
  void dispose() {
    _teikerSubscription?.cancel();
    _adminRemindersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;
    if (user != null && user.uid != _loadedUserId) {
      _loadedUserId = user.uid;
      _loadReminders(user.uid);
      _loadFerias();
      _loadConsultas();
    }
    final dayKey = _dayKey(_selectedDay);
    final normalEvents = _events[dayKey] ?? [];
    final consultasEvents = _consultas[dayKey] ?? [];

    final feriasEvents = teikersFerias
        .where((t) => t['dias'].any((d) => _dayKey(d) == dayKey))
        .map((t) {
          final bool isOwn = user != null && t['uid'] == user.uid;

          return {
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

    final selectedEvents = [
      ...normalEvents,
      ...consultasEvents,
      ...feriasEvents,
    ];

    final Map<DateTime, List<Map<String, dynamic>>> calendarEvents = {
      ..._consultas,
    };

    return Scaffold(
      appBar: buildAppBar(_appBarTitle(), seta: false),
      body: Column(
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
                        onDaySelected: (day, month) {
                          setState(() {
                            _selectedDay = day;
                            _focusedDay = DateTime(month.year, month.month, 1);
                          });
                        },
                        teikersFerias: teikersFerias,
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
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text(
                          'Adicionar Lembrete',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                        child: selectedEvents.isEmpty
                            ? Card(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 2,
                                child: Center(
                                  child: Text(
                                    _getEmptyMessage(_selectedDay),
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: selectedEvents.length,
                                itemBuilder: (context, i) {
                                  final event = selectedEvents[i];
                                  final bool isFerias =
                                      event['isFerias'] == true;
                                  final bool isConsulta =
                                      event['isConsulta'] == true;
                                  final bool readOnly = isFerias || isConsulta;
                                  final color = (isFerias || isConsulta)
                                      ? (event['cor'] as Color? ??
                                            selectedColor)
                                      : selectedColor;

                                  return EventItem(
                                    event: event,
                                    selectedColor: color,
                                    showHours: !isFerias,
                                    readOnly: readOnly,
                                    tag: event['tag'] as String?,
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
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

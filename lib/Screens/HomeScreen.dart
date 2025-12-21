import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/EventAddSheet.dart';
import 'package:teiker_app/Widgets/EventItem.dart';
import 'package:teiker_app/Widgets/curve_appbar_clipper.dart';
import 'package:teiker_app/Widgets/modern_calendar.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/auth/auth_notifier.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends ConsumerState<HomeScreen> {
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};
  final Map<DateTime, List<Map<String, dynamic>>> _consultas = {};
  List<Map<String, dynamic>> teikersFerias = [];
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final Color selectedColor = const Color.fromARGB(255, 4, 76, 32);
  String? _loadedUserId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _teikerSubscription;

  DateTime _dayKey(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _loadFerias();
    _loadConsultas();
    _startTeikerListener();
  }

  Future<void> _loadReminders(String userId) async {
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
      });
    }

    if (!mounted) return;
    setState(() {
      _events
        ..clear()
        ..addAll(loaded);
      _loadedUserId = userId;
    });
  }

  Future<void> _loadFerias() async {
    final feriasRaw = await ref.read(authServiceProvider).getFeriasTeikers();

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

    if(!mounted) return;

    setState(() => teikersFerias = feriasProcessed);
  }

  void _startTeikerListener() {
    _teikerSubscription?.cancel();
    _teikerSubscription = FirebaseFirestore.instance
        .collection('teikers')
        .snapshots()
        .listen((_) {
      _loadFerias();
      _loadConsultas();
    });
  }

  Future<void> _loadConsultas() async {
    final consultasRaw =
        await ref.read(authServiceProvider).getConsultasTeikers();

    final Map<DateTime, List<Map<String, dynamic>>> grouped = {};

    for (final c in consultasRaw) {
      final date = c['data'] as DateTime?;
      if (date == null) continue;

      final key = _dayKey(date);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add({
        'title': "${c['nome']} tem consulta",
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

  void _addEvent(Map<String, dynamic> event) {
    final key = _dayKey(event['date']);
    final newEvent = {
      'title': event['title'],
      'done': false,
      'start': event['start'],
      'end': event['end'],
      'isFerias': false,
      'date': event['date'],
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
      });
      return doc.id;
    }

    saveToDb().then((id) {
      if (id != null) newEvent['id'] = id;
      if (!mounted) return;
      setState(() {
        _events.putIfAbsent(key, () => []);
        _events[key]!.add(newEvent);
        _selectedDay = event['date'];
        _focusedDay = event['date'];
      });
    });
  }

  void _deleteEvent(DateTime dayKey, Map<String, dynamic> event) {
    final userId = _loadedUserId;
    final eventId = event['id'] as String?;
    if (userId != null && eventId != null) {
      FirebaseFirestore.instance
          .collection('reminders')
          .doc(userId)
          .collection('items')
          .doc(eventId)
          .delete();
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
    if (userId != null && eventId != null) {
      FirebaseFirestore.instance
          .collection('reminders')
          .doc(userId)
          .collection('items')
          .doc(eventId)
          .update({'done': event['done']});
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
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (context) => EventAddSheet(
        initialDate: _selectedDay,
        primaryColor: selectedColor,
        onAddEvent: _addEvent,
      ),
    );
  }

  @override
  void dispose() {
    _teikerSubscription?.cancel();
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
                        focusedDay: DateTime.now(),
                        selectedDay: _selectedDay,
                        primaryColor: selectedColor,
                        todayColor: Colors.greenAccent,
                        events: calendarEvents,
                        onDaySelected: (day, month) {
                          setState(() => _selectedDay = day);
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
                                  final bool readOnly =
                                      isFerias || isConsulta;
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

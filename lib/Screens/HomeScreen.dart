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
import 'package:teiker_app/backend/auth_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends ConsumerState<HomeScreen> {
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};
  List<Map<String, dynamic>> teikersFerias = [];
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final Color selectedColor = const Color.fromARGB(255, 4, 76, 32);
  late final AuthService _authService;

  DateTime _dayKey(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _authService = ref.read(authServiceProvider);
    _loadFerias();
  }

  Future<void> _loadFerias() async {
    final feriasRaw = await _authService.getFeriasTeikers();

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

  void _addEvent(Map<String, dynamic> event) {
    final key = _dayKey(event['date']);
    setState(() {
      _events.putIfAbsent(key, () => []);
      _events[key]!.add({
        'title': event['title'],
        'done': false,
        'start': event['start'],
        'end': event['end'],
        'isFerias': false,
      });
      _selectedDay = event['date'];
      _focusedDay = event['date'];
    });
  }

  void _deleteEvent(DateTime dayKey, Map<String, dynamic> event) {
    setState(() {
      _events[dayKey]?.remove(event);
      if ((_events[dayKey]?.isEmpty ?? true)) _events.remove(dayKey);
    });

    HapticFeedback.lightImpact();
  }

  void _toggleDone(Map<String, dynamic> event) {
    setState(() => event['done'] = !(event['done'] ?? false));
    HapticFeedback.mediumImpact();
  }

  String _appBarTitle() {
    final now = DateTime.now();
    return 'Hoje é ${DateFormat('EEEE, dd MMMM', 'pt_PT').format(now)}';
  }

  String _getEmptyMessage(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(day.year, day.month, day.day);
    if (selected == today) return 'Nenhum lembrete para hoje!';
    if (selected == today.subtract(const Duration(days: 1))) {
      return 'Nenhum lembrete ontem!';
    }
    if (selected == today.add(const Duration(days: 1))) {
      return 'Nenhum lembrete para amanhã!';
    }
    return 'Nenhum lembrete!';
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
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;
    final dayKey = _dayKey(_selectedDay);
    final normalEvents = _events[dayKey] ?? [];

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
          };
        })
        .toList();

    final selectedEvents = [...normalEvents, ...feriasEvents];

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
                                  final color = event['isFerias']
                                      ? event['cor'] as Color
                                      : selectedColor;

                                  return EventItem(
                                    event: event,
                                    selectedColor: color,
                                    showHours: !(event['isFerias'] ?? false),
                                    onToggleDone: () {
                                      if (event['isFerias'] != true) {
                                        _toggleDone(event);
                                      }
                                    },
                                    onDelete: () {
                                      if (event['isFerias'] != true) {
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

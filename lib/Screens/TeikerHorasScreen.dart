import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/backend/firebase_service.dart';
import 'package:teiker_app/models/Clientes.dart';
import 'package:teiker_app/models/teiker_workload.dart';
import 'package:teiker_app/theme/app_colors.dart';
import 'package:teiker_app/work_sessions/domain/fixed_holiday_hours_policy.dart';

class TeikerHorasScreen extends StatefulWidget {
  const TeikerHorasScreen({super.key});

  @override
  State<TeikerHorasScreen> createState() => _TeikerHorasScreenState();
}

class _TeikerHorasScreenState extends State<TeikerHorasScreen> {
  final Color _primary = AppColors.primaryGreen;
  bool _loading = true;
  Map<DateTime, Map<String, double>> _hoursByDay = {};
  Map<DateTime, Map<DateTime, Map<String, double>>> _hoursByMonth = {};
  Map<DateTime, double> _totalsByMonth = {};
  List<DateTime> _months = [];
  DateTime? _selectedMonth;
  double _targetHoras = 0;
  int _workPercentage = TeikerWorkload.fullTime;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadHoras();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadHoras() async {
    final user = FirebaseService().currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final clientes = await AuthService().getClientes();
    final Map<String, Clientes> clientesMap = {
      for (final c in clientes) c.uid: c,
    };
    double targetHoras = TeikerWorkload.weeklyHoursForPercentage(
      TeikerWorkload.fullTime,
    );
    int workPercentage = TeikerWorkload.fullTime;
    try {
      final teikerDoc = await FirebaseFirestore.instance
          .collection('teikers')
          .doc(user.uid)
          .get();
      final data = teikerDoc.data();
      if (data != null) {
        workPercentage = TeikerWorkload.normalizePercentage(
          data['workPercentage'],
          fallbackWeeklyHours: (data['horas'] as num?)?.toDouble(),
        );
        targetHoras = TeikerWorkload.weeklyHoursForPercentage(workPercentage);
      }
    } catch (_) {}

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('workSessions')
          .where('teikerId', isEqualTo: user.uid)
          .get();
      _buildMonthlyData(
        snapshot.docs,
        clientesMap,
        targetHoras,
        workPercentage,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;

      final snapshot = await FirebaseFirestore.instance
          .collection('workSessions')
          .where('teikerId', isEqualTo: user.uid)
          .get();
      _buildMonthlyData(
        snapshot.docs,
        clientesMap,
        targetHoras,
        workPercentage,
      );
    }
  }

  void _buildMonthlyData(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, Clientes> clientesMap,
    double targetHoras,
    int workPercentage,
  ) {
    final Map<DateTime, Map<DateTime, Map<String, double>>> grouped = {};
    final Map<DateTime, double> totals = {};
    DateTime? earliestMonth;

    for (final doc in docs) {
      final data = doc.data();
      final clienteId = data['clienteId'] as String?;
      final start = (data['startTime'] as Timestamp?)?.toDate();
      final end = (data['endTime'] as Timestamp?)?.toDate();
      double? duration = (data['durationHours'] as num?)?.toDouble();
      final rawStored = (data['rawDurationHours'] as num?)?.toDouble();
      if (duration == null && rawStored != null && start != null) {
        final storedMultiplier = (data['durationMultiplier'] as num?)
            ?.toDouble();
        duration = storedMultiplier != null && storedMultiplier > 0
            ? rawStored * storedMultiplier
            : FixedHolidayHoursPolicy.applyToHours(
                workDate: start,
                rawHours: rawStored,
              );
      }
      duration ??= (start != null && end != null)
          ? FixedHolidayHoursPolicy.applyToHours(
              workDate: start,
              rawHours: end.difference(start).inMinutes / 60.0,
            )
          : null;

      if (duration == null || start == null) continue;
      final dur = duration;
      final monthKey = DateTime(start.year, start.month);
      final dayKey = DateTime(start.year, start.month, start.day);
      final clienteName = clienteId != null
          ? clientesMap[clienteId]?.nameCliente ?? clienteId
          : "Cliente";

      grouped.putIfAbsent(monthKey, () => {});
      grouped[monthKey]!.putIfAbsent(dayKey, () => {});
      grouped[monthKey]![dayKey]!.update(
        clienteName,
        (v) => v + dur,
        ifAbsent: () => dur,
      );

      totals.update(monthKey, (v) => v + dur, ifAbsent: () => dur);
      earliestMonth ??= monthKey;
      if (monthKey.isBefore(earliestMonth)) {
        earliestMonth = monthKey;
      }
    }

    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final DateTime firstMonth = earliestMonth ?? currentMonth;
    final List<DateTime> months = [];
    DateTime cursor = DateTime(firstMonth.year, firstMonth.month);
    while (!cursor.isAfter(currentMonth)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    for (final month in months) {
      grouped.putIfAbsent(month, () => {});
      totals.putIfAbsent(month, () => 0);
    }

    final initialIndex = months.indexOf(currentMonth);
    final selectedMonth = initialIndex >= 0
        ? months[initialIndex]
        : currentMonth;

    if (!mounted) return;
    setState(() {
      _hoursByMonth = grouped;
      _totalsByMonth = totals;
      _months = months;
      _selectedMonth = selectedMonth;
      _hoursByDay = grouped[selectedMonth] ?? {};
      _targetHoras = targetHoras;
      _workPercentage = workPercentage;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && initialIndex >= 0) {
        _pageController.jumpToPage(initialIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar("Horas do mês", seta: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_selectedMonth != null) ...[
                    _annualBalanceCard(_selectedMonth!),
                    const SizedBox(height: 12),
                  ],
                  if (_months.isNotEmpty)
                    SizedBox(
                      height: 114,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _months.length,
                        onPageChanged: _onMonthChanged,
                        itemBuilder: (context, index) {
                          final month = _months[index];
                          final total = _totalsByMonth[month] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _summaryCard(
                              month,
                              DateFormat('MMMM yyyy', 'pt_PT').format(month),
                              total,
                            ),
                          );
                        },
                      ),
                    )
                  else
                    _summaryCard(
                      DateTime(DateTime.now().year, DateTime.now().month),
                      "Sem registos",
                      0,
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_months.isNotEmpty)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_month),
                          label: const Text("Selecionar mês"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
                            side: BorderSide(color: _primary),
                          ),
                          onPressed: _openMonthPicker,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _hoursByDay.isEmpty
                        ? Center(
                            child: Text(
                              "Ainda sem registos este mês.",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView(
                            children:
                                (_hoursByDay.entries.toList()
                                      ..sort((a, b) => b.key.compareTo(a.key)))
                                    .map((e) => _dayCard(e.key, e.value))
                                    .toList(),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  double _monthlyTargetForMonth(DateTime month) {
    return TeikerWorkload.monthlyHoursForPercentage(_workPercentage, month);
  }

  double _monthBalance(DateTime month, double total) {
    return total - _monthlyTargetForMonth(month);
  }

  Color _balanceColor(double balance) {
    if (balance > 0.05) return Colors.green.shade700;
    if (balance < -0.05) return Colors.red.shade700;
    return Colors.grey.shade700;
  }

  String _balanceLabel(double balance) {
    if (balance > 0.05) {
      return 'Fez ${balance.toStringAsFixed(1)} h a mais';
    }
    if (balance < -0.05) {
      return 'Fez ${balance.abs().toStringAsFixed(1)} h a menos';
    }
    return 'Meta do mês atingida';
  }

  double _yearBalanceForYear(int year) {
    final monthsInYear = _months.where((month) => month.year == year);
    return monthsInYear.fold<double>(
      0,
      (total, month) =>
          total + _monthBalance(month, _totalsByMonth[month] ?? 0),
    );
  }

  String _yearBalanceLabel(double balance) {
    if (balance > 0.05) {
      return '${balance.toStringAsFixed(1)} h a mais';
    }
    if (balance < -0.05) {
      return '${balance.abs().toStringAsFixed(1)} h a menos';
    }
    return '0.0 h';
  }

  Widget _annualBalanceCard(DateTime month) {
    final yearBalance = _yearBalanceForYear(month.year);
    final accent = _balanceColor(yearBalance);
    final icon = yearBalance > 0.05
        ? Icons.trending_up_rounded
        : yearBalance < -0.05
        ? Icons.trending_down_rounded
        : Icons.balance_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withValues(alpha: .12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo anual ${month.year}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _yearBalanceLabel(yearBalance),
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onMonthChanged(int index) {
    if (index < 0 || index >= _months.length) return;
    final month = _months[index];
    setState(() {
      _selectedMonth = month;
      _hoursByDay = _hoursByMonth[month] ?? {};
    });
  }

  void _openMonthPicker() {
    if (_months.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        final monthsDesc = _months.reversed.toList();
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: monthsDesc.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final month = monthsDesc[index];
              final label = DateFormat('MMMM yyyy', 'pt_PT').format(month);
              final total = _totalsByMonth[month] ?? 0;
              final isSelected = month == _selectedMonth;
              return ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${total.toStringAsFixed(1)} h",
                      style: TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _balanceLabel(_monthBalance(month, total)),
                      style: TextStyle(
                        color: _balanceColor(_monthBalance(month, total)),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.pop(context);
                  final monthIndex = _months.indexOf(month);
                  if (monthIndex >= 0 && _pageController.hasClients) {
                    _pageController.animateToPage(
                      monthIndex,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    );
                  }
                  _onMonthChanged(monthIndex);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _summaryCard(DateTime month, String label, double total) {
    final balance = _monthBalance(month, total);
    final isPositive = balance >= 0;
    final isNeutral = balance.abs() < 0.05;
    final monthlyTarget = _monthlyTargetForMonth(month);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: isNeutral
                ? Colors.grey.shade700
                : isPositive
                ? Colors.green.shade700
                : Colors.red.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "Total: ${total.toStringAsFixed(1)} h",
                  style: TextStyle(
                    color: isPositive
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _balanceLabel(balance),
                  style: TextStyle(
                    color: _balanceColor(balance),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "Meta mês: ${monthlyTarget.toStringAsFixed(1)} h • Meta semanal: ${_targetHoras.toStringAsFixed(0)} h ($_workPercentage%)",
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(DateTime day, Map<String, double> clientes) {
    final totalDia = clientes.values.fold<double>(
      0,
      (previous, element) => previous + element,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withValues(alpha: .1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('dd MMMM', 'pt_PT').format(day),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                "${totalDia.toStringAsFixed(1)} h",
                style: TextStyle(color: _primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: clientes.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.home_work_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${entry.value.toStringAsFixed(1)} h",
                      style: TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

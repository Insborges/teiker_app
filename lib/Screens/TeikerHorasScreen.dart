import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/app_bottom_sheet_shell.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/SingleDatePickerBottomSheet.dart';
import 'package:teiker_app/Widgets/SingleTimePickerBottomSheet.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/backend/firebase_service.dart';
import 'package:teiker_app/backend/work_session_service.dart';
import 'package:teiker_app/models/Clientes.dart';
import 'package:teiker_app/models/Teikers.dart';
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
  double _hoursBalanceAdjustment = 0;
  Teiker? _currentTeiker;
  final WorkSessionService _workSessionService = WorkSessionService();
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
        final teiker = Teiker.fromMap(data, teikerDoc.id);
        _currentTeiker = teiker;
        workPercentage = teiker.workPercentage;
        targetHoras = teiker.weeklyTargetHours;
        _hoursBalanceAdjustment = teiker.hoursBalanceAdjustment;
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
        _currentTeiker,
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
        _currentTeiker,
      );
    }
  }

  Future<void> _openEditHoursSheet() async {
    final user = FirebaseService().currentUser;
    if (user == null) return;

    List<Clientes> clientes;
    List<_EditableWorkSession> sessions;
    try {
      clientes = await AuthService().getClientes();
      sessions = await _loadEditableHourSessions(user.uid, clientes);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Não foi possível carregar horas para editar: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
      return;
    }

    if (!mounted) return;
    if (sessions.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'Ainda não há horas para editar.',
        icon: Icons.info_outline,
        background: Colors.orange.shade700,
      );
      return;
    }

    final selectedSession = await showModalBottomSheet<_EditableWorkSession>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _EditableHoursPickerSheet(primaryColor: _primary, sessions: sessions),
    );
    if (selectedSession == null || !mounted) return;

    final result = await showModalBottomSheet<_EditHoursResult>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditHoursSheet(
        primaryColor: _primary,
        initialSession: selectedSession,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await _workSessionService.updateManualSessionForCurrentTeikerProfile(
        sessionId: selectedSession.id,
        clienteId: result.cliente.uid,
        clienteName: result.cliente.nameCliente,
        start: result.start,
        end: result.end,
      );
      await _loadHoras();
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Horas atualizadas.',
        icon: Icons.edit_calendar_rounded,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Erro a atualizar horas: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  Future<List<_EditableWorkSession>> _loadEditableHourSessions(
    String teikerId,
    List<Clientes> clientes,
  ) async {
    final clientsById = {for (final cliente in clientes) cliente.uid: cliente};
    final snapshot = await FirebaseFirestore.instance
        .collection('workSessions')
        .where('teikerId', isEqualTo: teikerId)
        .get();

    final sessions = <_EditableWorkSession>[];
    final cutoff = DateTime(2026, 4, 1);
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final clienteId = (data['clienteId'] as String?)?.trim() ?? '';
      final start = (data['startTime'] as Timestamp?)?.toDate();
      final end = (data['endTime'] as Timestamp?)?.toDate();
      if (clienteId.isEmpty || start == null || end == null) continue;
      if (start.isBefore(cutoff)) continue;

      final duration = _durationForSessionData(data, start, end);
      final cliente = clientsById[clienteId] ?? _placeholderCliente(clienteId);
      sessions.add(
        _EditableWorkSession(
          id: doc.id,
          cliente: cliente,
          start: start,
          end: end,
          durationHours: duration,
        ),
      );
    }

    sessions.sort((a, b) => b.start.compareTo(a.start));
    return sessions;
  }

  double _durationForSessionData(
    Map<String, dynamic> data,
    DateTime start,
    DateTime end,
  ) {
    final stored = (data['durationHours'] as num?)?.toDouble();
    if (stored != null) return stored;

    final raw = (data['rawDurationHours'] as num?)?.toDouble();
    if (raw != null) {
      final multiplier = (data['durationMultiplier'] as num?)?.toDouble();
      return multiplier != null && multiplier > 0 ? raw * multiplier : raw;
    }

    return FixedHolidayHoursPolicy.applyToHours(
      workDate: start,
      rawHours: end.difference(start).inMinutes / 60.0,
    );
  }

  Clientes _placeholderCliente(String clienteId) {
    return Clientes(
      uid: clienteId,
      nameCliente: clienteId.isEmpty ? 'Cliente' : clienteId,
      moradaCliente: '',
      cidadeCliente: '',
      codigoPostal: '',
      hourasCasa: 0,
      telemovel: 0,
      email: '',
      orcamento: 0,
      teikersIds: const [],
    );
  }

  void _buildMonthlyData(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, Clientes> clientesMap,
    double targetHoras,
    int workPercentage,
    Teiker? teiker,
  ) {
    final Map<DateTime, Map<DateTime, Map<String, double>>> grouped = {};
    final Map<DateTime, double> totals = {};

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
    }

    if (teiker != null) {
      final adjustedTotals = teiker.monthlyTotalsWithAdjustments(totals);
      for (final month in teiker.monthlyBalanceAdjustments.keys) {
        final adjustedMonthTotal = adjustedTotals[month] ?? 0;
        final rawMonthTotal = totals[month] ?? 0;
        final targetMonthTotal = _monthlyTargetForMonth(month);
        final balanceHours = teiker.monthlyBalanceAdjustmentFor(month);
        final normalizedHours = targetMonthTotal - rawMonthTotal;

        grouped.putIfAbsent(month, () => {});
        final adjustmentDay = DateTime(month.year, month.month, 1);
        grouped[month]!.putIfAbsent(adjustmentDay, () => {});

        if (normalizedHours.abs() >= 0.05) {
          grouped[month]![adjustmentDay]!.update(
            'Regularização da meta mensal',
            (value) => value + normalizedHours,
            ifAbsent: () => normalizedHours,
          );
        }

        final extraDisplayHours = adjustedMonthTotal - targetMonthTotal;
        if (extraDisplayHours.abs() >= 0.05) {
          grouped[month]![adjustmentDay]!.update(
            'Horas extra do mês',
            (value) => value + extraDisplayHours,
            ifAbsent: () => extraDisplayHours,
          );
        } else if (balanceHours.abs() >= 0.05) {
          grouped[month]![adjustmentDay]!.update(
            'Acerto do saldo do mês',
            (value) => value + balanceHours,
            ifAbsent: () => balanceHours,
          );
        }
      }
      totals
        ..clear()
        ..addAll(adjustedTotals);
    }

    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final sortedMonths = totals.keys.toList()..sort((a, b) => a.compareTo(b));
    final DateTime firstMonth = sortedMonths.isNotEmpty
        ? sortedMonths.first
        : currentMonth;
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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= 380;
    final wide = width >= 900;

    return Scaffold(
      appBar: buildAppBar(
        "Horas do mês",
        seta: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar_rounded),
            tooltip: 'Editar horas',
            onPressed: _openEditHoursSheet,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 980 : 760),
                child: Padding(
                  padding: EdgeInsets.all(compact ? 12 : 16),
                  child: Column(
                    children: [
                      if (_selectedMonth != null) ...[
                        _annualBalanceCard(_selectedMonth!),
                        const SizedBox(height: 12),
                      ],
                      if (_months.isNotEmpty)
                        SizedBox(
                          height: compact ? 214 : (wide ? 196 : 206),
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _months.length,
                            onPageChanged: _onMonthChanged,
                            itemBuilder: (context, index) {
                              final month = _months[index];
                              final total = _totalsByMonth[month] ?? 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: _summaryCard(
                                  month,
                                  DateFormat(
                                    'MMMM yyyy',
                                    'pt_PT',
                                  ).format(month),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_months.isNotEmpty)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month),
                              label: const Text("Selecionar mês"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primary,
                                side: BorderSide(color: _primary),
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 12 : 14,
                                  vertical: compact ? 10 : 12,
                                ),
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
                                padding: const EdgeInsets.only(bottom: 8),
                                children:
                                    (_hoursByDay.entries.toList()..sort(
                                          (a, b) => b.key.compareTo(a.key),
                                        ))
                                        .map((e) => _dayCard(e.key, e.value))
                                        .toList(),
                              ),
                      ),
                    ],
                  ),
                ),
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
        ) +
        _yearBalanceAdjustment(year);
  }

  int _adjustmentYear() {
    if (_months.isEmpty) return DateTime.now().year;
    final years = _months.map((month) => month.year).toList()..sort();
    return years.first;
  }

  double _yearBalanceAdjustment(int year) {
    if (_hoursBalanceAdjustment.abs() < 0.05) return 0;
    return year == _adjustmentYear() ? _hoursBalanceAdjustment : 0;
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

  Widget _metricChip({
    required IconData icon,
    required String label,
    required String value,
    required bool compact,
    Color? valueColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 15 : 17, color: _primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.black87,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 12 : 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _annualBalanceCard(DateTime month) {
    final yearBalance = _yearBalanceForYear(month.year);
    final accent = _balanceColor(yearBalance);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= 380;
    final wide = width >= 900;
    final icon = yearBalance > 0.05
        ? Icons.trending_up_rounded
        : yearBalance < -0.05
        ? Icons.trending_down_rounded
        : Icons.balance_rounded;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 18 : (compact ? 14 : 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withValues(alpha: .12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 44 : 48,
                height: compact ? 44 : 48,
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
                      'Horas Anuais ${month.year}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 16 : 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Acumulado do ano face à meta mensal',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (wide)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _yearBalanceLabel(yearBalance),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (!wide) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _yearBalanceLabel(yearBalance),
                textAlign: TextAlign.center,
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
            ),
          ],
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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= 380;
    final wide = width >= 900;
    final monthlyTarget = _monthlyTargetForMonth(month);
    final accent = _balanceColor(balance);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 18 : (compact ? 14 : 16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withValues(alpha: .12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 42 : 46,
                height: compact ? 42 : 46,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.calendar_month_rounded, color: _primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 16 : 18,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Resumo mensal face à meta de trabalho',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (wide)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _balanceLabel(balance),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (!wide) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _balanceLabel(balance),
                textAlign: TextAlign.center,
                style: TextStyle(color: accent, fontWeight: FontWeight.w800),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(
                icon: Icons.schedule_rounded,
                label: 'Horas',
                value: '${total.toStringAsFixed(1)} h',
                valueColor: _primary,
                compact: compact,
              ),
              _metricChip(
                icon: Icons.flag_outlined,
                label: 'Meta mês',
                value: '${monthlyTarget.toStringAsFixed(1)} h',
                compact: compact,
              ),
              _metricChip(
                icon: Icons.pie_chart_outline_rounded,
                label: 'Meta semanal',
                value:
                    '${_targetHoras.toStringAsFixed(0)} h ($_workPercentage%)',
                compact: compact,
              ),
            ],
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

class _EditableWorkSession {
  const _EditableWorkSession({
    required this.id,
    required this.cliente,
    required this.start,
    required this.end,
    required this.durationHours,
  });

  final String id;
  final Clientes cliente;
  final DateTime start;
  final DateTime end;
  final double durationHours;
}

class _EditHoursResult {
  const _EditHoursResult({
    required this.cliente,
    required this.start,
    required this.end,
  });

  final Clientes cliente;
  final DateTime start;
  final DateTime end;
}

class _EditHoursSheet extends StatefulWidget {
  const _EditHoursSheet({
    required this.primaryColor,
    required this.initialSession,
  });

  final Color primaryColor;
  final _EditableWorkSession initialSession;

  @override
  State<_EditHoursSheet> createState() => _EditHoursSheetState();
}

class _EditHoursSheetState extends State<_EditHoursSheet> {
  late Clientes _selectedCliente;
  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _selectedCliente = widget.initialSession.cliente;
    _selectedDate = DateTime(
      widget.initialSession.start.year,
      widget.initialSession.start.month,
      widget.initialSession.start.day,
    );
    _startTime = TimeOfDay.fromDateTime(widget.initialSession.start);
    _endTime = TimeOfDay.fromDateTime(widget.initialSession.end);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'pt_PT').format(date);
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Selecionar';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  DateTime _combine(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDate() async {
    final picked = await SingleDatePickerBottomSheet.show(
      context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      title: 'Dia das horas',
      subtitle: 'Escolhe o dia trabalhado',
      confirmLabel: 'Confirmar',
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await SingleTimePickerBottomSheet.show(
      context,
      initialTime: _startTime ?? TimeOfDay.now(),
      title: 'Hora de início',
      subtitle: 'Escolhe a hora inicial',
      confirmLabel: 'Confirmar',
    );
    if (picked == null) return;
    setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await SingleTimePickerBottomSheet.show(
      context,
      initialTime: _endTime ?? TimeOfDay.now(),
      title: 'Hora de fim',
      subtitle: 'Escolhe a hora final',
      confirmLabel: 'Confirmar',
    );
    if (picked == null) return;
    setState(() => _endTime = picked);
  }

  void _submit() {
    final startTime = _startTime;
    final endTime = _endTime;
    if (startTime == null || endTime == null) {
      AppSnackBar.show(
        context,
        message: 'Escolhe a hora de início e a hora de fim.',
        icon: Icons.info_outline,
        background: Colors.orange.shade700,
      );
      return;
    }

    final start = _combine(_selectedDate, startTime);
    final end = _combine(_selectedDate, endTime);
    final now = DateTime.now();
    if (start.isAfter(now) || end.isAfter(now)) {
      AppSnackBar.show(
        context,
        message: 'Não podes adicionar horas no futuro.',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
      return;
    }
    if (!end.isAfter(start)) {
      AppSnackBar.show(
        context,
        message: 'A hora de fim deve ser posterior à hora de início.',
        icon: Icons.info_outline,
        background: Colors.orange.shade700,
      );
      return;
    }

    Navigator.of(
      context,
    ).pop(_EditHoursResult(cliente: _selectedCliente, start: start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetShell(
      title: 'Alterar horas',
      subtitle: 'Corrige o registo de horas selecionado',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ManualHoursInfoTile(
            label: 'Cliente',
            value: _selectedCliente.nameCliente,
            icon: Icons.people_outline,
            primaryColor: widget.primaryColor,
          ),
          const SizedBox(height: 12),
          _ManualHoursSelectorTile(
            label: 'Dia',
            value: _formatDate(_selectedDate),
            icon: Icons.calendar_month_outlined,
            primaryColor: widget.primaryColor,
            onTap: _pickDate,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ManualHoursSelectorTile(
                  label: 'Início',
                  value: _formatTime(_startTime),
                  icon: Icons.play_circle_outline,
                  primaryColor: widget.primaryColor,
                  onTap: _pickStartTime,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ManualHoursSelectorTile(
                  label: 'Fim',
                  value: _formatTime(_endTime),
                  icon: Icons.stop_circle_outlined,
                  primaryColor: widget.primaryColor,
                  onTap: _pickEndTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: 'Cancelar',
                  outline: true,
                  color: widget.primaryColor,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  text: 'Atualizar',
                  icon: Icons.save_rounded,
                  color: widget.primaryColor,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualHoursSelectorTile extends StatelessWidget {
  const _ManualHoursSelectorTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.primaryColor,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primaryColor.withAlpha(32)),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ManualHoursInfoTile extends StatelessWidget {
  const _ManualHoursInfoTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.primaryColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withAlpha(32)),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableHoursPickerSheet extends StatelessWidget {
  const _EditableHoursPickerSheet({
    required this.primaryColor,
    required this.sessions,
  });

  final Color primaryColor;
  final List<_EditableWorkSession> sessions;

  String _formatSessionDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'pt_PT').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm', 'pt_PT').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetShell(
      title: 'Alterar horas',
      subtitle: 'Escolhe o registo que queres corrigir',
      child: SizedBox(
        height: 460,
        child: ListView.separated(
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final session = sessions[index];
            return InkWell(
              onTap: () => Navigator.of(context).pop(session),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withAlpha(40)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: primaryColor.withAlpha(18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.edit_calendar, color: primaryColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.cliente.nameCliente,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_formatSessionDate(session.start)} • ${_formatTime(session.start)} - ${_formatTime(session.end)}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${session.durationHours.toStringAsFixed(1)} h',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: primaryColor),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

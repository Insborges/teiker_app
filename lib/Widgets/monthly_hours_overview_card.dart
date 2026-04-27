import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/models/teiker_workload.dart';

class MonthlyHoursOverviewCard extends StatefulWidget {
  const MonthlyHoursOverviewCard({
    super.key,
    required this.monthlyTotals,
    required this.primaryColor,
    this.workPercentage,
    this.balanceAdjustmentHours = 0,
    this.title = 'Horas por mês',
    this.emptyMessage = 'Sem horas registadas.',
    this.showHeader = true,
  });

  final Map<DateTime, double> monthlyTotals;
  final Color primaryColor;
  final int? workPercentage;
  final double balanceAdjustmentHours;
  final String title;
  final String emptyMessage;
  final bool showHeader;

  @override
  State<MonthlyHoursOverviewCard> createState() =>
      _MonthlyHoursOverviewCardState();
}

class _MonthlyHoursOverviewCardState extends State<MonthlyHoursOverviewCard> {
  late int _selectedYear;
  bool _expanded = false;

  List<int> get _availableYears {
    final years = widget.monthlyTotals.keys.map((m) => m.year).toSet().toList();
    if (years.isEmpty) {
      return [DateTime.now().year];
    }
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  @override
  void initState() {
    super.initState();
    _selectedYear = _initialYear();
  }

  @override
  void didUpdateWidget(covariant MonthlyHoursOverviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final years = _availableYears;
    if (!years.contains(_selectedYear)) {
      _selectedYear = years.first;
    }
  }

  int _initialYear() {
    final nowYear = DateTime.now().year;
    final years = _availableYears;
    return years.contains(nowYear) ? nowYear : years.first;
  }

  double _monthTotal(int year, int month) {
    return widget.monthlyTotals[DateTime(year, month)] ?? 0;
  }

  double? _monthTarget(int year, int month) {
    final workPercentage = widget.workPercentage;
    if (workPercentage == null) return null;
    return TeikerWorkload.monthlyHoursForPercentage(
      workPercentage,
      DateTime(year, month),
    );
  }

  double? _monthBalance(int year, int month) {
    final target = _monthTarget(year, month);
    if (target == null) return null;
    return _monthTotal(year, month) - target;
  }

  List<int> _monthsForYear(int year) {
    final months = widget.monthlyTotals.keys
        .where((month) => month.year == year)
        .map((month) => month.month)
        .toSet()
        .toList();
    months.sort();
    return months;
  }

  double? _yearBalance(int year) {
    if (widget.monthlyTotals.isEmpty || widget.workPercentage == null) {
      final adjustment = _yearBalanceAdjustment(year);
      return adjustment.abs() < 0.05 ? null : adjustment;
    }
    final months = _monthsForYear(year);
    if (months.isEmpty) {
      final adjustment = _yearBalanceAdjustment(year);
      return adjustment.abs() < 0.05 ? null : adjustment;
    }

    return months.fold<double>(
          0,
          (total, month) => total + (_monthBalance(year, month) ?? 0),
        ) +
        _yearBalanceAdjustment(year);
  }

  int _adjustmentYear() {
    if (widget.monthlyTotals.isEmpty) return DateTime.now().year;
    final years = widget.monthlyTotals.keys.map((m) => m.year).toList()..sort();
    return years.first;
  }

  double _yearBalanceAdjustment(int year) {
    if (widget.balanceAdjustmentHours.abs() < 0.05) return 0;
    return year == _adjustmentYear() ? widget.balanceAdjustmentHours : 0;
  }

  Color _balanceColor(double balance) {
    if (balance > 0.05) return Colors.green.shade700;
    if (balance < -0.05) return Colors.red.shade700;
    return Colors.grey.shade700;
  }

  String _balanceLabel(double balance) {
    if (balance > 0.05) {
      return '${balance.toStringAsFixed(1)} h a mais';
    }
    if (balance < -0.05) {
      return '${balance.abs().toStringAsFixed(1)} h a menos';
    }
    return 'Meta do mês atingida';
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
        color: widget.primaryColor.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.primaryColor.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 15 : 17, color: widget.primaryColor),
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

  Widget _buildCurrentMonthCard({
    required DateTime now,
    required double currentMonthHours,
    required double? currentMonthBalance,
    required bool compact,
    required bool wide,
  }) {
    final currentMonthTarget = _monthTarget(now.year, now.month);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 16 : (compact ? 12 : 14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.primaryColor.withValues(alpha: .12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                width: compact ? 42 : 46,
                height: compact ? 42 : 46,
                decoration: BoxDecoration(
                  color: widget.primaryColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: widget.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy', 'pt_PT').format(now),
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
              if (currentMonthBalance != null && wide)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _balanceColor(
                      currentMonthBalance,
                    ).withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _balanceLabel(currentMonthBalance),
                    style: TextStyle(
                      color: _balanceColor(currentMonthBalance),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (currentMonthBalance != null && !wide) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _balanceColor(
                  currentMonthBalance,
                ).withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _balanceLabel(currentMonthBalance),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _balanceColor(currentMonthBalance),
                  fontWeight: FontWeight.w800,
                ),
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
                value: '${currentMonthHours.toStringAsFixed(1)} h',
                valueColor: widget.primaryColor,
                compact: compact,
              ),
              if (currentMonthTarget != null)
                _metricChip(
                  icon: Icons.flag_outlined,
                  label: 'Meta mês',
                  value: '${currentMonthTarget.toStringAsFixed(1)} h',
                  compact: compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYearToggle({
    required double? selectedYearBalance,
    required bool compact,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: widget.primaryColor.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.primaryColor.withValues(alpha: .12),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Horas anuais $_selectedYear',
                      style: TextStyle(
                        color: widget.primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 14 : 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _expanded ? 'Ocultar meses' : 'Ver meses',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedYearBalance != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _balanceColor(
                      selectedYearBalance,
                    ).withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _yearBalanceLabel(selectedYearBalance),
                    style: TextStyle(
                      color: _balanceColor(selectedYearBalance),
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 11 : 12,
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: widget.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthTile({
    required int year,
    required int month,
    required double total,
    required double? balance,
    required bool compact,
    required bool dense,
  }) {
    final target = _monthTarget(year, month);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? (compact ? 9 : 10) : (compact ? 10 : 12),
        vertical: dense ? (compact ? 8 : 9) : (compact ? 10 : 12),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.primaryColor.withValues(alpha: .12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: dense ? 8 : 12,
            offset: Offset(0, dense ? 3 : 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat(
                        compact ? 'MMM' : 'MMMM',
                        'pt_PT',
                      ).format(DateTime(year, month)),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: dense ? 13 : (compact ? 14 : 15),
                      ),
                    ),
                    if (target != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Meta ${target.toStringAsFixed(1)} h',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: dense ? 10.5 : (compact ? 11 : 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${total.toStringAsFixed(1)} h',
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: widget.primaryColor,
                  fontWeight: FontWeight.w800,
                  fontSize: dense ? 13 : (compact ? 14 : 15),
                ),
              ),
            ],
          ),
          if (balance != null) ...[
            SizedBox(height: dense ? 6 : 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 8 : 10,
                vertical: dense ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: _balanceColor(balance).withValues(alpha: .10),
                borderRadius: BorderRadius.circular(dense ? 9 : 10),
              ),
              child: Text(
                _balanceLabel(balance),
                style: TextStyle(
                  color: _balanceColor(balance),
                  fontWeight: FontWeight.w800,
                  fontSize: dense ? 10.5 : (compact ? 11 : 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonthHours = _monthTotal(now.year, now.month);
    final currentMonthBalance = _monthBalance(now.year, now.month);
    final selectedYearBalance = _yearBalance(_selectedYear);
    final years = _availableYears;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= 380;
    final wide = width >= 900;
    final denseMonths = !widget.showHeader;
    final monthsWithHours =
        widget.monthlyTotals.entries
            .where((entry) => entry.key.year == _selectedYear)
            .toList()
          ..sort((a, b) => a.key.month.compareTo(b.key.month));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader)
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: widget.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.primaryColor,
                    fontSize: 16,
                  ),
                ),
              ),
              if (years.length > 1)
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedYear,
                    style: TextStyle(
                      color: widget.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                    items: years
                        .map(
                          (year) => DropdownMenuItem<int>(
                            value: year,
                            child: Text('$year'),
                          ),
                        )
                        .toList(),
                    onChanged: (year) {
                      if (year == null) return;
                      setState(() => _selectedYear = year);
                    },
                  ),
                ),
            ],
          ),
        if (widget.showHeader) const SizedBox(height: 10),
        _buildCurrentMonthCard(
          now: now,
          currentMonthHours: currentMonthHours,
          currentMonthBalance: currentMonthBalance,
          compact: compact,
          wide: wide,
        ),
        if (!widget.showHeader && years.length > 1) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                style: TextStyle(
                  color: widget.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
                items: years
                    .map(
                      (year) => DropdownMenuItem<int>(
                        value: year,
                        child: Text('$year'),
                      ),
                    )
                    .toList(),
                onChanged: (year) {
                  if (year == null) return;
                  setState(() => _selectedYear = year);
                },
              ),
            ),
          ),
        ],
        SizedBox(height: widget.showHeader ? 10 : 6),
        _buildYearToggle(
          selectedYearBalance: selectedYearBalance,
          compact: compact,
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final spacing = denseMonths ? 8.0 : 10.0;
                    final targetWidth = denseMonths
                        ? (wide ? 178.0 : (compact ? 132.0 : 152.0))
                        : (wide ? 210.0 : (compact ? 150.0 : 180.0));
                    final columns = math.max(
                      1,
                      ((constraints.maxWidth + spacing) /
                              (targetWidth + spacing))
                          .floor(),
                    );
                    final tileWidth =
                        (constraints.maxWidth - (spacing * (columns - 1))) /
                        columns;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: monthsWithHours.map((entry) {
                        final month = entry.key.month;
                        final total = entry.value;
                        final balance = _monthBalance(_selectedYear, month);
                        return SizedBox(
                          width: tileWidth,
                          child: _buildMonthTile(
                            year: _selectedYear,
                            month: month,
                            total: total,
                            balance: balance,
                            compact: compact,
                            dense: denseMonths,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                if (monthsWithHours.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      widget.monthlyTotals.isEmpty
                          ? widget.emptyMessage
                          : 'Sem horas registadas em $_selectedYear.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

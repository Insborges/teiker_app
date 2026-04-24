import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/models/teiker_workload.dart';

class MonthlyHoursOverviewCard extends StatefulWidget {
  const MonthlyHoursOverviewCard({
    super.key,
    required this.monthlyTotals,
    required this.primaryColor,
    this.workPercentage,
    this.title = 'Horas por mês',
    this.emptyMessage = 'Sem horas registadas.',
    this.showHeader = true,
  });

  final Map<DateTime, double> monthlyTotals;
  final Color primaryColor;
  final int? workPercentage;
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
      return null;
    }
    final months = _monthsForYear(year);
    if (months.isEmpty) return null;

    return months.fold<double>(
      0,
      (total, month) => total + (_monthBalance(year, month) ?? 0),
    );
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonthHours = _monthTotal(now.year, now.month);
    final currentMonthBalance = _monthBalance(now.year, now.month);
    final selectedYearBalance = _yearBalance(_selectedYear);
    final years = _availableYears;
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.primaryColor.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.primaryColor.withValues(alpha: .2),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.today, color: widget.primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  DateFormat(
                    'MMMM yyyy',
                    'pt_PT',
                  ).format(DateTime(now.year, now.month)),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${currentMonthHours.toStringAsFixed(1)} h',
                    style: TextStyle(
                      color: widget.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (currentMonthBalance != null)
                    Text(
                      _balanceLabel(currentMonthBalance),
                      style: TextStyle(
                        color: _balanceColor(currentMonthBalance),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
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
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: widget.primaryColor,
                textStyle: const TextStyle(fontWeight: FontWeight.w400),
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => setState(() => _expanded = true),
              icon: const Icon(Icons.expand_more),
              label: Text(
                selectedYearBalance == null
                    ? 'Ver meses de $_selectedYear'
                    : 'Ver meses de $_selectedYear • ${_yearBalanceLabel(selectedYearBalance)}',
              ),
            ),
          ),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: widget.primaryColor,
                    textStyle: const TextStyle(fontWeight: FontWeight.w400),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => setState(() => _expanded = false),
                  icon: const Icon(Icons.expand_less),
                  label: Text(
                    selectedYearBalance == null
                        ? 'Ocultar meses de $_selectedYear'
                        : 'Ocultar meses de $_selectedYear • ${_yearBalanceLabel(selectedYearBalance)}',
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: monthsWithHours.map((entry) {
                  final month = entry.key.month;
                  final total = entry.value;
                  final balance = _monthBalance(_selectedYear, month);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: widget.primaryColor.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.primaryColor.withValues(alpha: .16),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'MMM',
                            'pt_PT',
                          ).format(DateTime(_selectedYear, month)),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${total.toStringAsFixed(1)}h',
                          style: TextStyle(
                            color: widget.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (balance != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _balanceLabel(balance),
                            style: TextStyle(
                              color: _balanceColor(balance),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
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
      ],
    );
  }
}

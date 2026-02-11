import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:teiker_app/Widgets/app_bottom_sheet_shell.dart';
import 'package:teiker_app/theme/app_colors.dart';

class SingleDatePickerBottomSheet {
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String title = 'Selecionar data',
    String subtitle = 'Escolhe o dia',
    String confirmLabel = 'Confirmar',
  }) async {
    return await showModalBottomSheet<DateTime?>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SingleDatePickerSheet(
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          title: title,
          subtitle: subtitle,
          confirmLabel: confirmLabel,
        );
      },
    );
  }
}

class _SingleDatePickerSheet extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String title;
  final String subtitle;
  final String confirmLabel;

  const _SingleDatePickerSheet({
    this.initialDate,
    this.firstDate,
    this.lastDate,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
  });

  @override
  State<_SingleDatePickerSheet> createState() => _SingleDatePickerSheetState();
}

class _SingleDatePickerSheetState extends State<_SingleDatePickerSheet> {
  static final DateTime _defaultFirstDay = DateTime.utc(1900, 1, 1);
  static final DateTime _defaultLastDay = DateTime.utc(2100, 12, 31);
  static const List<String> _monthNames = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  late final DateTime _firstDay;
  late final DateTime _lastDay;
  DateTime? selectedDate;
  DateTime focusedDay = DateTime.now();

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime _clampToRange(DateTime date) {
    if (date.isBefore(_firstDay)) return _firstDay;
    if (date.isAfter(_lastDay)) return _lastDay;
    return date;
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  void _goMonth(int delta) {
    setState(() {
      final moved = DateTime(focusedDay.year, focusedDay.month + delta, 1);
      focusedDay = _clampToRange(moved);
    });
  }

  Future<void> _pickYearQuickly() async {
    final pickedYear = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _YearPickerSheet(
        firstYear: _firstDay.year,
        lastYear: _lastDay.year,
        initialYear: focusedDay.year,
      ),
    );
    if (pickedYear == null) return;

    setState(() {
      final base = selectedDate ?? focusedDay;
      final safeDay = base.day
          .clamp(1, _daysInMonth(pickedYear, base.month))
          .toInt();
      final next = _clampToRange(DateTime(pickedYear, base.month, safeDay));
      focusedDay = next;
      if (selectedDate != null) {
        selectedDate = next;
      }
    });
  }

  Future<void> _pickMonthQuickly() async {
    final pickedMonth = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MonthPickerSheet(initialMonth: focusedDay.month),
    );
    if (pickedMonth == null) return;

    setState(() {
      final base = selectedDate ?? focusedDay;
      final safeDay = base.day
          .clamp(1, _daysInMonth(base.year, pickedMonth))
          .toInt();
      final next = _clampToRange(DateTime(base.year, pickedMonth, safeDay));
      focusedDay = next;
      if (selectedDate != null) {
        selectedDate = next;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _firstDay = _dayOnly(widget.firstDate ?? _defaultFirstDay);
    _lastDay = _dayOnly(widget.lastDate ?? _defaultLastDay);

    final normalizedNow = _dayOnly(DateTime.now());
    final initial = widget.initialDate != null
        ? _dayOnly(widget.initialDate!)
        : normalizedNow;
    final clampedInitial = _clampToRange(initial);

    selectedDate = widget.initialDate == null ? null : clampedInitial;
    focusedDay = clampedInitial;
  }

  CalendarStyle _calendarStyleClean() {
    const primary = AppColors.primaryGreenHex;

    return CalendarStyle(
      isTodayHighlighted: true,
      outsideDaysVisible: false,
      selectedDecoration: const BoxDecoration(
        color: primary,
        shape: BoxShape.circle,
      ),
      selectedTextStyle: const TextStyle(color: Colors.white),
      todayDecoration: const BoxDecoration(
        color: Color(0x33044C20),
        shape: BoxShape.circle,
      ),
      defaultDecoration: const BoxDecoration(shape: BoxShape.circle),
      weekendDecoration: const BoxDecoration(shape: BoxShape.circle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetShell(
      title: widget.title,
      subtitle: widget.subtitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _headerNavButton(Icons.chevron_left, () => _goMonth(-1)),
              const SizedBox(width: 4),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _pickMonthQuickly,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryGreenHex,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                      child: Text(
                        _monthNames[focusedDay.month - 1],
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 2),
                    TextButton(
                      onPressed: _pickYearQuickly,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryGreenHex,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                      child: Text(
                        '${focusedDay.year}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _headerNavButton(Icons.chevron_right, () => _goMonth(1)),
            ],
          ),
          const SizedBox(height: 8),
          TableCalendar(
            firstDay: _firstDay,
            lastDay: _lastDay,
            focusedDay: focusedDay,
            headerVisible: false,
            selectedDayPredicate: (day) {
              if (selectedDate == null) return false;
              return isSameDay(selectedDate, day);
            },
            calendarStyle: _calendarStyleClean(),
            onDaySelected: (selected, focused) {
              setState(() {
                selectedDate = DateTime(
                  selected.year,
                  selected.month,
                  selected.day,
                );
                focusedDay = _clampToRange(
                  DateTime(focused.year, focused.month, focused.day),
                );
              });
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dateChip('Data', selectedDate),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreenHex,
                ),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: selectedDate == null
                    ? null
                    : () => Navigator.pop(context, selectedDate),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreenHex,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(widget.confirmLabel),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _dateChip(String label, DateTime? date) {
    return AppLabeledValueChip(
      label: label,
      value: date != null ? _formatDate(date) : '--/--',
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Widget _headerNavButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primaryGreenHex.withValues(alpha: .25),
          ),
          color: Colors.grey.shade50,
        ),
        child: Icon(icon, color: AppColors.primaryGreenHex, size: 20),
      ),
    );
  }
}

class _YearPickerSheet extends StatefulWidget {
  const _YearPickerSheet({
    required this.firstYear,
    required this.lastYear,
    required this.initialYear,
  });

  final int firstYear;
  final int lastYear;
  final int initialYear;

  @override
  State<_YearPickerSheet> createState() => _YearPickerSheetState();
}

class _YearPickerSheetState extends State<_YearPickerSheet> {
  late final FixedExtentScrollController _controller;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear
        .clamp(widget.firstYear, widget.lastYear)
        .toInt();
    _controller = FixedExtentScrollController(
      initialItem: _selectedYear - widget.firstYear,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetShell(
      title: 'Selecionar ano',
      subtitle: 'Escolhe apenas o ano',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 210,
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: 44,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                setState(() => _selectedYear = widget.firstYear + index);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  if (index < 0 ||
                      index > (widget.lastYear - widget.firstYear)) {
                    return null;
                  }
                  final year = widget.firstYear + index;
                  final selected = year == _selectedYear;
                  return Center(
                    child: Text(
                      '$year',
                      style: TextStyle(
                        color: selected
                            ? AppColors.primaryGreenHex
                            : Colors.grey.shade600,
                        fontSize: selected ? 22 : 18,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreenHex,
                    side: const BorderSide(color: AppColors.primaryGreenHex),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selectedYear),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreenHex,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirmar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({required this.initialMonth});

  final int initialMonth;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  static const List<String> _monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  late final FixedExtentScrollController _controller;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth.clamp(1, 12).toInt();
    _controller = FixedExtentScrollController(initialItem: _selectedMonth - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetShell(
      title: 'Selecionar mês',
      subtitle: 'Escolhe apenas o mês',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 210,
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: 44,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                setState(() => _selectedMonth = index + 1);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  if (index < 0 || index >= _monthNames.length) return null;
                  final month = index + 1;
                  final selected = month == _selectedMonth;
                  return Center(
                    child: Text(
                      _monthNames[index],
                      style: TextStyle(
                        color: selected
                            ? AppColors.primaryGreenHex
                            : Colors.grey.shade600,
                        fontSize: selected ? 22 : 18,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreenHex,
                    side: const BorderSide(color: AppColors.primaryGreenHex),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selectedMonth),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreenHex,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirmar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

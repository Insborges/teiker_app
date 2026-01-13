import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class SingleDatePickerBottomSheet {
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDate,
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
  final String title;
  final String subtitle;
  final String confirmLabel;

  const _SingleDatePickerSheet({
    this.initialDate,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
  });

  @override
  State<_SingleDatePickerSheet> createState() => _SingleDatePickerSheetState();
}

class _SingleDatePickerSheetState extends State<_SingleDatePickerSheet> {
  DateTime? selectedDate;
  DateTime focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
    if (selectedDate != null) {
      focusedDay = selectedDate!;
    }
  }

  CalendarStyle _calendarStyleClean() {
    const primary = Color(0xFF044C20);

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
          Text(
            widget.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          TableCalendar(
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            focusedDay: focusedDay,
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
                focusedDay = focused;
              });
            },
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dateChip('Data', selectedDate),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF044C20),
                ),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: selectedDate == null
                    ? null
                    : () => Navigator.pop(context, selectedDate),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF044C20),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black45)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            date != null ? _formatDate(date) : '--/--',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

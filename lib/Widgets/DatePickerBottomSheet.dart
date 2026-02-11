import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:teiker_app/Widgets/app_bottom_sheet_shell.dart';
import 'package:teiker_app/theme/app_colors.dart';

class DatePickerBottomSheet {
  static Future<List<DateTime?>?> show(
    BuildContext context, {
    DateTime? initialStart,
    DateTime? initialEnd,
  }) async {
    return await showModalBottomSheet<List<DateTime?>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DatePickerSheet(
          initialStart: initialStart,
          initialEnd: initialEnd,
        );
      },
    );
  }
}

class _DatePickerSheet extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;

  const _DatePickerSheet({this.initialStart, this.initialEnd});

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  DateTime? startDate;
  DateTime? endDate;
  DateTime focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    startDate = widget.initialStart;
    endDate = widget.initialEnd;
  }

  // RANGE Intervalo Calendário
  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focused) {
    setState(() {
      startDate = start;
      endDate = end;
      focusedDay = focused;
    });
  }

  // Calendar Style
  CalendarStyle _calendarStyleClean() {
    const primary = AppColors.primaryGreenHex;

    return CalendarStyle(
      // === CONFIGURAÇÕES GERAIS ===
      isTodayHighlighted: true,
      outsideDaysVisible: false,

      rangeHighlightColor: Colors.transparent, // remove azul/retângulo default
      // === HOJE ===
      todayDecoration: const BoxDecoration(
        color: Color(0x33044C20), // mesma cor mas muito leve
        shape: BoxShape.circle,
      ),

      // === DIA SELECIONADO ===
      selectedDecoration: const BoxDecoration(
        color: primary,
        shape: BoxShape.circle,
      ),
      selectedTextStyle: TextStyle(color: Colors.white),

      // === INÍCIO DO RANGE ===
      rangeStartDecoration: const BoxDecoration(
        color: primary,
        shape: BoxShape.circle,
      ),
      rangeStartTextStyle: const TextStyle(color: Colors.white),

      // === FIM DO RANGE ===
      rangeEndDecoration: const BoxDecoration(
        color: primary,
        shape: BoxShape.circle,
      ),
      rangeEndTextStyle: const TextStyle(color: Colors.white),

      // === DIAS ENTRE O RANGE ===
      withinRangeDecoration: BoxDecoration(
        color: primary.withValues(alpha: 0.18), // mais clean e consistente
        shape: BoxShape.circle, // SEM quadrados
      ),
      withinRangeTextStyle: const TextStyle(color: Colors.black),

      // === DIAS NORMAIS ===
      defaultDecoration: const BoxDecoration(shape: BoxShape.circle),
      weekendDecoration: const BoxDecoration(shape: BoxShape.circle),
    );
  }

  // Intervalo escolha dias
  CalendarBuilders _calendarBuildersClean() {
    return CalendarBuilders(
      withinRangeBuilder: (context, day, focusedDay) {
        return Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE4F3EA), // verde claríssimo
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            "${day.day}",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheetShell(
      title: 'Selecionar férias',
      subtitle: 'Escolhe o intervalo de dias',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            focusedDay: focusedDay,
            rangeStartDay: startDate,
            rangeEndDay: endDate,
            rangeSelectionMode: RangeSelectionMode.toggledOn,
            calendarStyle: _calendarStyleClean(),
            calendarBuilders: _calendarBuildersClean(),
            onRangeSelected: _onRangeSelected,
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dateChip('Início', startDate),
              const Text('—', style: TextStyle(fontSize: 16)),
              _dateChip('Fim', endDate),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (startDate != null && endDate != null)
                  ? () => Navigator.pop(context, [startDate, endDate])
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreenHex,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Confirmar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

Widget _dateChip(String label, DateTime? date) {
  final value = date != null
      ? '${date.day}/${date.month}/${date.year}'
      : '--/--';
  return AppLabeledValueChip(label: label, value: value);
}

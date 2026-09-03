import 'package:teiker_app/utils/swiss_holiday_calendar.dart';

class FixedHolidayHoursPolicy {
  const FixedHolidayHoursPolicy._();

  static const double holidayMultiplier = 2.0;

  static bool isFixedHoliday(DateTime date) {
    return SwissHolidayCalendar.isHoliday(date);
  }

  static double multiplierFor(DateTime date, {bool isExtra = false}) {
    // Sábados, domingos e feriados contam a dobrar, incluindo horas extra.
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    return isWeekend || isFixedHoliday(date) ? holidayMultiplier : 1.0;
  }

  static double applyToHours({
    required DateTime workDate,
    required double rawHours,
    bool isExtra = false,
  }) {
    return rawHours * multiplierFor(workDate, isExtra: isExtra);
  }
}

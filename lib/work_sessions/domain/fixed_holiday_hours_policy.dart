import 'package:teiker_app/utils/swiss_holiday_calendar.dart';

class FixedHolidayHoursPolicy {
  const FixedHolidayHoursPolicy._();

  static const double holidayMultiplier = 2.0;

  static bool isFixedHoliday(DateTime date) {
    return SwissHolidayCalendar.isHoliday(date);
  }

  static double multiplierFor(DateTime date, {bool isExtra = false}) {
    // Domingos e feriados do calendário contam a dobrar, incluindo horas extra.
    return date.weekday == DateTime.sunday || isFixedHoliday(date)
        ? holidayMultiplier
        : 1.0;
  }

  static double applyToHours({
    required DateTime workDate,
    required double rawHours,
    bool isExtra = false,
  }) {
    return rawHours * multiplierFor(workDate, isExtra: isExtra);
  }
}

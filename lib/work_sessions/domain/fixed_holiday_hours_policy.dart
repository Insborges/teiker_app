class FixedHolidayHoursPolicy {
  const FixedHolidayHoursPolicy._();

  static const double holidayMultiplier = 2.0;

  static bool isFixedHoliday(DateTime date) {
    final month = date.month;
    final day = date.day;

    return (month == 1 && (day == 1 || day == 2)) ||
        (month == 8 && day == 1) ||
        (month == 12 && (day == 25 || day == 26));
  }

  static double multiplierFor(DateTime date) {
    return isFixedHoliday(date) ? holidayMultiplier : 1.0;
  }

  static double applyToHours({
    required DateTime workDate,
    required double rawHours,
  }) {
    return rawHours * multiplierFor(workDate);
  }
}

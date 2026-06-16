import 'package:teiker_app/utils/swiss_holiday_calendar.dart';

class TeikerWorkload {
  const TeikerWorkload._();

  static const int fiftyPercent = 50;
  static const int seventyPercent = 70;
  static const int fullTime = 100;

  static const List<int> supportedPercentages = <int>[
    fiftyPercent,
    seventyPercent,
    fullTime,
  ];

  static bool isSupported(int percentage) =>
      supportedPercentages.contains(percentage);

  static int inferPercentageFromHours(double? weeklyHours) {
    if (weeklyHours == null) return fullTime;
    if (weeklyHours <= 25) return fiftyPercent;
    if (weeklyHours <= 34) return seventyPercent;
    return fullTime;
  }

  static int normalizePercentage(dynamic raw, {double? fallbackWeeklyHours}) {
    final parsed = raw is int ? raw : int.tryParse('$raw');
    if (parsed != null && isSupported(parsed)) return parsed;
    return inferPercentageFromHours(fallbackWeeklyHours);
  }

  static double weeklyHoursForPercentage(int percentage) {
    switch (percentage) {
      case fiftyPercent:
        return 21;
      case seventyPercent:
        return 29;
      case fullTime:
      default:
        return 40;
    }
  }

  static double monthlyHoursForWeeklyHours(double weeklyHours, DateTime month) {
    // Calculate hours based on work-days (Mon-Fri) in the month,
    // excluding official holidays. Daily hours = weeklyHours / 5.
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    var cursor = monthStart;
    var businessDays = 0;
    while (!cursor.isAfter(monthEnd)) {
      final isWeekday =
          cursor.weekday >= DateTime.monday &&
          cursor.weekday <= DateTime.friday;
      final isHoliday = SwissHolidayCalendar.isHoliday(cursor);
      if (isWeekday && !isHoliday) businessDays += 1;
      cursor = cursor.add(const Duration(days: 1));
    }

    final dailyHours = weeklyHours / 5.0;
    return dailyHours * businessDays;
  }

  static double monthlyHoursForPercentage(int percentage, DateTime month) {
    final weeklyTarget = weeklyHoursForPercentage(percentage);
    return monthlyHoursForWeeklyHours(weeklyTarget, month);
  }

  static String labelForPercentage(int percentage) {
    switch (percentage) {
      case fiftyPercent:
        return 'Trabalha a 50%';
      case seventyPercent:
        return 'Trabalhar a 70%';
      case fullTime:
      default:
        return 'Trabalha 100%';
    }
  }
}

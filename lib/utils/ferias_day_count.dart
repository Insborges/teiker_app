import 'package:teiker_app/models/Teikers.dart';
import 'package:teiker_app/utils/swiss_holiday_calendar.dart';

DateTime _normalizeFeriasDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool _isBusinessDay(DateTime date) {
  return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
}

bool _isHoliday(DateTime date) {
  return SwissHolidayCalendar.isHoliday(date);
}

int countFeriasBusinessDays(
  List<FeriasPeriodo> periodos, {
  DateTime? legacyStart,
  DateTime? legacyEnd,
}) {
  final dayKeys = <DateTime>{};

  void addRange(DateTime start, DateTime end) {
    var cursor = _normalizeFeriasDate(start);
    final normalizedEnd = _normalizeFeriasDate(end);

    while (!cursor.isAfter(normalizedEnd)) {
      if (_isBusinessDay(cursor) && !_isHoliday(cursor)) {
        dayKeys.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  for (final periodo in periodos) {
    addRange(periodo.inicio, periodo.fim);
  }

  if (legacyStart != null && legacyEnd != null) {
    addRange(legacyStart, legacyEnd);
  }

  return dayKeys.length;
}

int countFeriasBusinessDaysInMonth(
  List<FeriasPeriodo> periodos,
  DateTime month, {
  DateTime? legacyStart,
  DateTime? legacyEnd,
}) {
  final dayKeys = <DateTime>{};
  final monthStart = DateTime(month.year, month.month, 1);
  final monthEnd = DateTime(month.year, month.month + 1, 0);

  void addRange(DateTime start, DateTime end) {
    final normalizedStart = _normalizeFeriasDate(start);
    final normalizedEnd = _normalizeFeriasDate(end);
    final effectiveStart = normalizedStart.isBefore(monthStart)
        ? monthStart
        : normalizedStart;
    final effectiveEnd = normalizedEnd.isAfter(monthEnd)
        ? monthEnd
        : normalizedEnd;

    if (effectiveStart.isAfter(effectiveEnd)) return;

    var cursor = effectiveStart;
    while (!cursor.isAfter(effectiveEnd)) {
      // Only count as vacation day if it's a business day AND not a holiday
      if (_isBusinessDay(cursor) && !_isHoliday(cursor)) {
        dayKeys.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  for (final periodo in periodos) {
    addRange(periodo.inicio, periodo.fim);
  }

  if (legacyStart != null && legacyEnd != null) {
    addRange(legacyStart, legacyEnd);
  }

  return dayKeys.length;
}

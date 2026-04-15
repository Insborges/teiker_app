import 'package:teiker_app/models/Teikers.dart';

DateTime _normalizeFeriasDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool _isBusinessDay(DateTime date) {
  return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
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
      if (_isBusinessDay(cursor)) {
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

class SwissHoliday {
  const SwissHoliday({
    required this.id,
    required this.name,
    required this.date,
    this.isHalfDay = false,
  });

  final String id;
  final String name;
  final DateTime date;
  final bool isHalfDay;
}

class SwissHolidayCalendar {
  const SwissHolidayCalendar._();

  static final Map<int, List<SwissHoliday>> _holidayCache = {};

  // Base oficial: cantão de Bern. Os feriados móveis são calculados por ano.
  static bool isHoliday(DateTime date) {
    return holidayForDate(date) != null;
  }

  static bool isBernDayOff(DateTime date) {
    return holidayForDate(date, includeHalfDays: true) != null;
  }

  static String? holidayName(DateTime date, {bool includeHalfDays = false}) {
    return holidayForDate(date, includeHalfDays: includeHalfDays)?.name;
  }

  static SwissHoliday? holidayForDate(
    DateTime date, {
    bool includeHalfDays = false,
  }) {
    final normalized = _normalize(date);
    for (final holiday in holidaysForYear(
      normalized.year,
      includeHalfDays: includeHalfDays,
    )) {
      if (holiday.date == normalized) {
        return holiday;
      }
    }
    return null;
  }

  static List<SwissHoliday> holidaysForYear(
    int year, {
    bool includeHalfDays = false,
  }) {
    final allDaysOff = _holidayCache.putIfAbsent(
      year,
      () => List<SwissHoliday>.unmodifiable(_buildBernDaysOff(year)),
    );

    if (includeHalfDays) return allDaysOff;
    return allDaysOff.where((holiday) => !holiday.isHalfDay).toList();
  }

  static List<SwissHoliday> _buildBernDaysOff(int year) {
    return _sorted(<SwissHoliday>[
      _fixed('new_year', 'Ano Novo', year, 1, 1),
      _fixed('berchtold', 'Berchtoldstag', year, 1, 2),
      _relative('good_friday', 'Sexta-feira Santa', year, -2),
      _relative('easter_monday', 'Segunda-feira de Páscoa', year, 1),
      _relative('ascension', 'Ascensão', year, 39),
      _relative('whit_monday', 'Segunda-feira de Pentecostes', year, 50),
      _fixed('national_day', 'Feriado Nacional Suíço', year, 8, 1),
      _fixed('christmas', 'Natal', year, 12, 25),
      _fixed('st_stephen', 'Santo Estêvão', year, 12, 26),
      _fixedHalfDay(
        'christmas_eve_afternoon',
        'Tarde livre de Véspera de Natal',
        year,
        12,
        24,
      ),
      _fixedHalfDay(
        'new_year_eve_afternoon',
        'Tarde livre de Véspera de Ano Novo',
        year,
        12,
        31,
      ),
    ]);
  }

  static List<SwissHoliday> _sorted(List<SwissHoliday> holidays) {
    holidays.sort((a, b) => a.date.compareTo(b.date));
    return holidays;
  }

  static SwissHoliday _fixed(
    String id,
    String name,
    int year,
    int month,
    int day,
  ) {
    return SwissHoliday(id: id, name: name, date: DateTime(year, month, day));
  }

  static SwissHoliday _fixedHalfDay(
    String id,
    String name,
    int year,
    int month,
    int day,
  ) {
    return SwissHoliday(
      id: id,
      name: name,
      date: DateTime(year, month, day),
      isHalfDay: true,
    );
  }

  static SwissHoliday _relative(
    String id,
    String name,
    int year,
    int offsetDays,
  ) {
    final easterSunday = _easterSunday(year);
    return SwissHoliday(
      id: id,
      name: name,
      date: _normalize(easterSunday.add(Duration(days: offsetDays))),
    );
  }

  static DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime _easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }
}

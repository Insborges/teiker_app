enum SwissHolidayProfile { companyDefault, zurich, geneva }

class SwissHoliday {
  const SwissHoliday({
    required this.id,
    required this.name,
    required this.date,
  });

  final String id;
  final String name;
  final DateTime date;
}

class SwissHolidayCalendar {
  const SwissHolidayCalendar._();

  static const SwissHolidayProfile defaultProfile =
      SwissHolidayProfile.companyDefault;

  static final Map<String, List<SwissHoliday>> _holidayCache = {};

  static bool isHoliday(
    DateTime date, {
    SwissHolidayProfile profile = defaultProfile,
  }) {
    final normalized = _normalize(date);
    return holidaysForYear(
      normalized.year,
      profile: profile,
    ).any((holiday) => holiday.date == normalized);
  }

  static String? holidayName(
    DateTime date, {
    SwissHolidayProfile profile = defaultProfile,
  }) {
    final normalized = _normalize(date);
    for (final holiday in holidaysForYear(normalized.year, profile: profile)) {
      if (holiday.date == normalized) {
        return holiday.name;
      }
    }
    return null;
  }

  static List<SwissHoliday> holidaysForYear(
    int year, {
    SwissHolidayProfile profile = defaultProfile,
  }) {
    final cacheKey = '${profile.name}-$year';
    return _holidayCache.putIfAbsent(
      cacheKey,
      () => List<SwissHoliday>.unmodifiable(_buildHolidays(year, profile)),
    );
  }

  static List<SwissHoliday> _buildHolidays(
    int year,
    SwissHolidayProfile profile,
  ) {
    switch (profile) {
      case SwissHolidayProfile.zurich:
        return _sorted(<SwissHoliday>[
          _fixed('new_year', 'Ano Novo', year, 1, 1),
          _relative('good_friday', 'Sexta-feira Santa', year, -2),
          _relative('easter_monday', 'Segunda-feira de Páscoa', year, 1),
          _fixed('labour_day', 'Dia do Trabalhador', year, 5, 1),
          _relative('ascension', 'Ascensão', year, 39),
          _relative('whit_monday', 'Segunda-feira de Pentecostes', year, 50),
          _fixed('national_day', 'Feriado Nacional Suíço', year, 8, 1),
          _fixed('christmas', 'Natal', year, 12, 25),
          _fixed('st_stephen', 'Santo Estêvão', year, 12, 26),
        ]);
      case SwissHolidayProfile.geneva:
        final newYear = DateTime(year, 1, 1);
        final nationalDay = DateTime(year, 8, 1);
        final christmas = DateTime(year, 12, 25);
        return _sorted(<SwissHoliday>[
          SwissHoliday(
            id: 'geneva_new_year',
            name: newYear.weekday == DateTime.sunday
                ? 'Ano Novo (observado)'
                : 'Ano Novo',
            date: _mondaySubstitute(newYear),
          ),
          _relative('good_friday', 'Sexta-feira Santa', year, -2),
          _relative('easter_monday', 'Segunda-feira de Páscoa', year, 1),
          _relative('ascension', 'Ascensão', year, 39),
          _relative('whit_monday', 'Segunda-feira de Pentecostes', year, 50),
          SwissHoliday(
            id: 'geneva_national_day',
            name: nationalDay.weekday == DateTime.sunday
                ? 'Feriado Nacional Suíço (observado)'
                : 'Feriado Nacional Suíço',
            date: _mondaySubstitute(nationalDay),
          ),
          SwissHoliday(
            id: 'geneva_fast',
            name: 'Jeûne genevois',
            date: _genevaFastDay(year),
          ),
          SwissHoliday(
            id: 'geneva_christmas',
            name: christmas.weekday == DateTime.sunday
                ? 'Natal (observado)'
                : 'Natal',
            date: _mondaySubstitute(christmas),
          ),
          _fixed(
            'republic_restoration',
            'Restauração da República',
            year,
            12,
            31,
          ),
        ]);
      case SwissHolidayProfile.companyDefault:
        // A app não guarda o cantão. Por isso usamos um calendário suíço
        // alargado com datas móveis para manter coerência na operação diária.
        return _sorted(<SwissHoliday>[
          _fixed('new_year', 'Ano Novo', year, 1, 1),
          _fixed('berchtold', 'Berchtoldstag', year, 1, 2),
          _relative('good_friday', 'Sexta-feira Santa', year, -2),
          _relative('easter_monday', 'Segunda-feira de Páscoa', year, 1),
          _fixed('labour_day', 'Dia do Trabalhador', year, 5, 1),
          _relative('ascension', 'Ascensão', year, 39),
          _relative('whit_monday', 'Segunda-feira de Pentecostes', year, 50),
          _fixed('national_day', 'Feriado Nacional Suíço', year, 8, 1),
          _fixed('christmas', 'Natal', year, 12, 25),
          _fixed('st_stephen', 'Santo Estêvão', year, 12, 26),
        ]);
    }
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

  static DateTime _genevaFastDay(int year) {
    final septemberFirst = DateTime(year, 9, 1);
    final offsetToSunday =
        (DateTime.sunday - septemberFirst.weekday + DateTime.daysPerWeek) %
        DateTime.daysPerWeek;
    final firstSunday = septemberFirst.add(Duration(days: offsetToSunday));
    return _normalize(firstSunday.add(const Duration(days: 4)));
  }

  static DateTime _mondaySubstitute(DateTime date) {
    if (date.weekday != DateTime.sunday) return _normalize(date);
    return _normalize(date.add(const Duration(days: 1)));
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

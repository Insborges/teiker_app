import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teiker_app/utils/swiss_holiday_calendar.dart';
import 'package:teiker_app/work_sessions/infrastructure/work_session_hours.dart';

void main() {
  Map<String, dynamic> session(DateTime date) => {
    'startTime': Timestamp.fromDate(date),
    'endTime': Timestamp.fromDate(date.add(const Duration(hours: 3))),
  };

  test('Sunday corrects cached normal hours, including extra hours', () {
    for (final extra in [false, true]) {
      expect(
        WorkSessionHours.resolve({
          ...session(DateTime(2026, 9, 6)),
          'durationHours': 3,
          'rawDurationHours': 3,
          'durationMultiplier': 1,
          'isExtra': extra,
        }),
        6,
      );
    }
  });

  test('ordinary Saturday removes the previous doubled rate', () {
    expect(
      WorkSessionHours.resolve({
        ...session(DateTime(2026, 9, 5)),
        'durationHours': 6,
        'rawDurationHours': 3,
        'durationMultiplier': 2,
      }),
      3,
    );
  });

  test('legacy Sunday uses timestamps and never doubles twice', () {
    for (final stored in [3, 6]) {
      expect(
        WorkSessionHours.resolve({
          ...session(DateTime(2026, 9, 6)),
          'durationHours': stored,
        }),
        6,
      );
    }
  });

  test('all calendar holidays double, including holidays on Saturday', () {
    for (final holiday in SwissHolidayCalendar.holidaysForYear(2026)) {
      expect(
        WorkSessionHours.resolve(session(holiday.date)),
        6,
        reason: holiday.name,
      );
    }
  });

  test('holiday on Sunday applies the rate only once', () {
    expect(WorkSessionHours.resolve(session(DateTime(2027, 8, 1))), 6);
  });

  test('ordinary weekday and transit keep actual hours', () {
    expect(WorkSessionHours.resolve(session(DateTime(2026, 9, 2))), 3);
    expect(
      WorkSessionHours.resolve({
        ...session(DateTime(2026, 9, 6)),
        'clienteId': 'DESLOCACAO',
      }),
      3,
    );
  });

  test('incomplete historical data preserves stored hours', () {
    expect(WorkSessionHours.resolve({'durationHours': 3}), 3);
    expect(
      WorkSessionHours.resolve({
        'startTime': Timestamp.fromDate(DateTime(2026, 9, 6)),
      }),
      isNull,
    );
  });
}

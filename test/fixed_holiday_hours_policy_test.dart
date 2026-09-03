import 'package:flutter_test/flutter_test.dart';
import 'package:teiker_app/work_sessions/domain/fixed_holiday_hours_policy.dart';

void main() {
  test('weekend hours count double, including extra hours', () {
    final saturday = DateTime(2026, 9, 5);
    final sunday = DateTime(2026, 9, 6);

    expect(
      FixedHolidayHoursPolicy.applyToHours(
        workDate: saturday,
        rawHours: 3,
        isExtra: true,
      ),
      6,
    );
    expect(
      FixedHolidayHoursPolicy.applyToHours(workDate: sunday, rawHours: 2),
      4,
    );
  });

  test('weekday hours retain their normal value when it is not a holiday', () {
    final weekday = DateTime(2026, 9, 2);

    expect(
      FixedHolidayHoursPolicy.applyToHours(workDate: weekday, rawHours: 3.5),
      3.5,
    );
  });
}

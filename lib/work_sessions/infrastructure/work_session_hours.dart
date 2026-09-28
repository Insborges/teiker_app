import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teiker_app/work_sessions/domain/fixed_holiday_hours_policy.dart';

/// Recomputes credited hours so historical cached rates cannot override the date.
class WorkSessionHours {
  const WorkSessionHours._();

  static double? resolve(Map<String, dynamic> data) {
    final start = (data['startTime'] as Timestamp?)?.toDate();
    final end = (data['endTime'] as Timestamp?)?.toDate();
    final stored = (data['durationHours'] as num?)?.toDouble();
    final multiplier = (data['durationMultiplier'] as num?)?.toDouble();
    var raw = (data['rawDurationHours'] as num?)?.toDouble();
    if (raw == null && start != null && end != null && !end.isBefore(start)) {
      raw = end.difference(start).inMinutes / 60.0;
    }
    if (raw == null && stored != null && multiplier != null && multiplier > 0) {
      raw = stored / multiplier;
    }
    // Without a date or recoverable raw duration, preserve the recorded value.
    if (start == null || raw == null) return stored ?? raw;
    if (data['clienteId'] == 'DESLOCACAO' || data['isTransit'] == true) {
      return raw;
    }
    return FixedHolidayHoursPolicy.applyToHours(
      workDate: start,
      rawHours: raw,
      isExtra: data['isExtra'] == true,
    );
  }
}

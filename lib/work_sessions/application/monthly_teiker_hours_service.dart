import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teiker_app/work_sessions/domain/fixed_holiday_hours_policy.dart';

class MonthlyTeikerHoursService {
  MonthlyTeikerHoursService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<Map<String, double>> fetchHoursByCliente({
    required String teikerId,
    DateTime? referenceDate,
  }) async {
    final now = referenceDate ?? DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

    try {
      final snapshot = await _firestore
          .collection('workSessions')
          .where('teikerId', isEqualTo: teikerId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
          )
          .where('startTime', isLessThan: Timestamp.fromDate(nextMonth))
          .get();
      docs = snapshot.docs;
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;

      final snapshot = await _firestore
          .collection('workSessions')
          .where('teikerId', isEqualTo: teikerId)
          .get();

      docs = snapshot.docs.where((doc) {
        final start = (doc.data()['startTime'] as Timestamp?)?.toDate();
        return start != null &&
            !start.isBefore(monthStart) &&
            start.isBefore(nextMonth);
      });
    }

    final Map<String, double> hoursByCliente = {};

    for (final doc in docs) {
      final data = doc.data();
      final clienteId = data['clienteId'] as String?;
      if (clienteId == null) continue;

      final duration = _resolveDurationHours(data);
      if (duration == null) continue;

      hoursByCliente.update(
        clienteId,
        (value) => value + duration,
        ifAbsent: () => duration,
      );
    }

    return hoursByCliente;
  }

  double? _resolveDurationHours(Map<String, dynamic> data) {
    var duration = (data['durationHours'] as num?)?.toDouble();
    if (duration != null) return duration;

    final rawStored = (data['rawDurationHours'] as num?)?.toDouble();
    final start = (data['startTime'] as Timestamp?)?.toDate();
    if (rawStored != null && start != null) {
      final storedMultiplier = (data['durationMultiplier'] as num?)?.toDouble();
      if (storedMultiplier != null && storedMultiplier > 0) {
        return rawStored * storedMultiplier;
      }
      return FixedHolidayHoursPolicy.applyToHours(
        workDate: start,
        rawHours: rawStored,
      );
    }

    final end = (data['endTime'] as Timestamp?)?.toDate();
    if (start == null || end == null) return null;

    return FixedHolidayHoursPolicy.applyToHours(
      workDate: start,
      rawHours: end.difference(start).inMinutes / 60.0,
    );
  }
}

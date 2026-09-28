import 'package:teiker_app/work_sessions/infrastructure/work_session_hours.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyHoursOverviewService {
  MonthlyHoursOverviewService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<Map<DateTime, double>> fetchMonthlyTotals({
    String? teikerId,
    String? clienteId,
  }) async {
    if ((teikerId == null || teikerId.isEmpty) &&
        (clienteId == null || clienteId.isEmpty)) {
      return {};
    }

    final docs = await _querySessions(teikerId: teikerId, clienteId: clienteId);
    final Map<DateTime, double> totals = {};

    for (final doc in docs) {
      final data = doc.data();
      final start = (data['startTime'] as Timestamp?)?.toDate();
      if (start == null) continue;

      final duration = _resolveDurationHours(data);
      if (duration == null) continue;

      final monthKey = DateTime(start.year, start.month);
      totals.update(
        monthKey,
        (value) => value + duration,
        ifAbsent: () => duration,
      );
    }

    if (totals.isEmpty) {
      return {};
    }

    final months = totals.keys.toList()..sort((a, b) => a.compareTo(b));
    final firstMonth = months.first;
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    var cursor = DateTime(firstMonth.year, firstMonth.month);
    while (!cursor.isAfter(currentMonth)) {
      totals.putIfAbsent(cursor, () => 0);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    return totals;
  }

  Future<Iterable<QueryDocumentSnapshot<Map<String, dynamic>>>> _querySessions({
    String? teikerId,
    String? clienteId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection('workSessions');
    if (teikerId != null && teikerId.isNotEmpty) {
      query = query.where('teikerId', isEqualTo: teikerId);
    }
    if (clienteId != null && clienteId.isNotEmpty) {
      query = query.where('clienteId', isEqualTo: clienteId);
    }

    try {
      final snapshot = await query.get();
      return snapshot.docs;
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;

      // Fallback sem índices compostos: filtra localmente.
      Query<Map<String, dynamic>> fallback = _firestore.collection(
        'workSessions',
      );
      if (teikerId != null && teikerId.isNotEmpty) {
        fallback = fallback.where('teikerId', isEqualTo: teikerId);
      } else if (clienteId != null && clienteId.isNotEmpty) {
        fallback = fallback.where('clienteId', isEqualTo: clienteId);
      }

      final snapshot = await fallback.get();
      return snapshot.docs.where((doc) {
        final data = doc.data();
        if (teikerId != null &&
            teikerId.isNotEmpty &&
            data['teikerId'] != teikerId) {
          return false;
        }
        if (clienteId != null &&
            clienteId.isNotEmpty &&
            data['clienteId'] != clienteId) {
          return false;
        }
        return true;
      });
    }
  }

  double? _resolveDurationHours(Map<String, dynamic> data) {
    return WorkSessionHours.resolve(data);
  }
}

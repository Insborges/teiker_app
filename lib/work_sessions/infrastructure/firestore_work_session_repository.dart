import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/work_session.dart';
import '../domain/work_session_repository.dart';

class FirestoreWorkSessionRepository implements WorkSessionRepository {
  final FirebaseFirestore firestore;

  FirestoreWorkSessionRepository(this.firestore);

  WorkSession _toWorkSession(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String fallbackTeikerId,
  }) {
    final data = doc.data();
    return WorkSession(
      id: doc.id,
      clienteId: data['clienteId'] as String,
      teikerId: (data['teikerId'] as String?) ?? fallbackTeikerId,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      durationHours: (data['durationHours'] as num?)?.toDouble(),
    );
  }

  @override
  Future<WorkSession?> findOpenSession({
    required String clienteId,
    required String teikerId,
  }) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      // Prefer the precise query (needs composite index in some projects)
      snapshot = await firestore
          .collection('workSessions')
          .where('clienteId', isEqualTo: clienteId)
          .where('teikerId', isEqualTo: teikerId)
          .where('endTime', isNull: true)
          .limit(1)
          .get();
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;

      // Fallback without composite index: fetch by teikerId and filter locally.
      final fallback = await firestore
          .collection('workSessions')
          .where('teikerId', isEqualTo: teikerId)
          .get();

      for (final doc in fallback.docs) {
        final data = doc.data();
        if (data['clienteId'] == clienteId && data['endTime'] == null) {
          return _toWorkSession(doc, fallbackTeikerId: teikerId);
        }
      }

      return null;
    }

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return _toWorkSession(doc, fallbackTeikerId: teikerId);
  }

  @override
  Future<WorkSession?> findAnyOpenSession({required String teikerId}) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await firestore
          .collection('workSessions')
          .where('teikerId', isEqualTo: teikerId)
          .where('endTime', isNull: true)
          .limit(1)
          .get();
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;

      final fallback = await firestore
          .collection('workSessions')
          .where('teikerId', isEqualTo: teikerId)
          .get();

      for (final doc in fallback.docs) {
        if (doc.data()['endTime'] == null) {
          return _toWorkSession(doc, fallbackTeikerId: teikerId);
        }
      }
      return null;
    }

    if (snapshot.docs.isEmpty) return null;
    return _toWorkSession(snapshot.docs.first, fallbackTeikerId: teikerId);
  }

  Future<Iterable<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _queryMonthlySessions({
    required String clienteId,
    required DateTime referenceDate,
    String? teikerId,
  }) async {
    final monthStart = DateTime(referenceDate.year, referenceDate.month, 1);
    final nextMonth = DateTime(referenceDate.year, referenceDate.month + 1, 1);

    try {
      Query<Map<String, dynamic>> query = firestore
          .collection('workSessions')
          .where('clienteId', isEqualTo: clienteId);

      if (teikerId != null) {
        query = query.where('teikerId', isEqualTo: teikerId);
      }

      final snapshot = await query
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
          )
          .where('startTime', isLessThan: Timestamp.fromDate(nextMonth))
          .get();

      return snapshot.docs;
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;

      Query<Map<String, dynamic>> fallback = firestore
          .collection('workSessions')
          .where(
            teikerId != null ? 'teikerId' : 'clienteId',
            isEqualTo: teikerId ?? clienteId,
          );

      final snapshot = await fallback.get();
      return snapshot.docs.where((doc) {
        final data = doc.data();
        if (teikerId != null && data['clienteId'] != clienteId) {
          return false;
        }

        final start = (data['startTime'] as Timestamp?)?.toDate();
        return start != null &&
            !start.isBefore(monthStart) &&
            start.isBefore(nextMonth);
      });
    }
  }

  double _sumDurationHours(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var totalHours = 0.0;
    for (final doc in docs) {
      final duration = _resolveDurationHours(doc.data());
      if (duration != null) {
        totalHours += duration;
      }
    }
    return totalHours;
  }

  double? _resolveDurationHours(Map<String, dynamic> data) {
    var duration = (data['durationHours'] as num?)?.toDouble();
    if (duration != null) return duration;

    final start = (data['startTime'] as Timestamp?)?.toDate();
    final end = (data['endTime'] as Timestamp?)?.toDate();
    if (start == null || end == null) return null;

    return end.difference(start).inMinutes / 60.0;
  }

  @override
  Future<WorkSession> startSession({
    required String clienteId,
    required String teikerId,
    required DateTime start,
  }) async {
    final doc = await firestore.collection('workSessions').add({
      'clienteId': clienteId,
      'teikerId': teikerId,
      'startTime': Timestamp.fromDate(start),
      'endTime': null,
      'durationHours': null,
    });

    return WorkSession(
      id: doc.id,
      clienteId: clienteId,
      teikerId: teikerId,
      startTime: start,
      endTime: null,
      durationHours: null,
    );
  }

  @override
  Future<WorkSession> closeSession({
    required String sessionId,
    required DateTime end,
  }) async {
    final docRef = firestore.collection('workSessions').doc(sessionId);
    late WorkSession closedSession;

    await firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);

      if (!snapshot.exists) {
        throw Exception('Sessão não encontrada.');
      }

      final data = snapshot.data();
      if (data == null) {
        throw Exception('Sessão sem dados.');
      }

      if (data['endTime'] != null) {
        throw Exception('Sessão já fechada.');
      }

      final startTime = (data['startTime'] as Timestamp?)?.toDate();
      if (startTime == null) {
        throw Exception('Sessão sem hora de início válida.');
      }
      if (!end.isAfter(startTime)) {
        throw Exception('A hora de fim deve ser posterior ao início.');
      }

      final durationHours = end.difference(startTime).inMinutes / 60.0;

      tx.update(docRef, {
        'endTime': Timestamp.fromDate(end),
        'durationHours': durationHours,
      });

      closedSession = WorkSession(
        id: sessionId,
        clienteId: data['clienteId'] as String,
        teikerId: (data['teikerId'] as String?) ?? '',
        startTime: startTime,
        endTime: end,
        durationHours: durationHours,
      );
    });

    return closedSession;
  }

  @override
  Future<WorkSession> addManualSession({
    required String clienteId,
    required String teikerId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (!end.isAfter(start)) {
      throw Exception('A hora de fim deve ser posterior ao início.');
    }
    final duration = end.difference(start).inMinutes / 60.0;

    final doc = await firestore.collection('workSessions').add({
      'clienteId': clienteId,
      'teikerId': teikerId,
      'startTime': Timestamp.fromDate(start),
      'endTime': Timestamp.fromDate(end),
      'durationHours': duration,
    });

    return WorkSession(
      id: doc.id,
      clienteId: clienteId,
      teikerId: teikerId,
      startTime: start,
      endTime: end,
      durationHours: duration,
    );
  }

  @override
  Future<bool> hasSessionOverlap({
    required String teikerId,
    required DateTime start,
    required DateTime end,
    String? excludingSessionId,
  }) async {
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

    try {
      final snapshot = await firestore
          .collection('workSessions')
          .where('teikerId', isEqualTo: teikerId)
          .where('startTime', isLessThan: Timestamp.fromDate(end))
          .get();
      docs = snapshot.docs;
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      final fallback = await firestore
          .collection('workSessions')
          .where('teikerId', isEqualTo: teikerId)
          .get();
      docs = fallback.docs;
    }

    for (final doc in docs) {
      if (excludingSessionId != null && doc.id == excludingSessionId) {
        continue;
      }

      final data = doc.data();
      final sessionStart = (data['startTime'] as Timestamp?)?.toDate();
      if (sessionStart == null) continue;

      final sessionEndRaw = data['endTime'];
      final sessionEnd = sessionEndRaw is Timestamp
          ? sessionEndRaw.toDate()
          : DateTime.now();

      final overlaps = sessionStart.isBefore(end) && sessionEnd.isAfter(start);
      if (overlaps) return true;
    }

    return false;
  }

  @override
  Future<double> calculateMonthlyTotal({
    required String clienteId,
    required DateTime referenceDate,
  }) async {
    final docs = await _queryMonthlySessions(
      clienteId: clienteId,
      referenceDate: referenceDate,
    );
    final totalHours = _sumDurationHours(docs);

    await firestore.collection('clientes').doc(clienteId).update({
      'hourasCasa': totalHours,
    });

    return totalHours;
  }

  @override
  Future<double> calculateMonthlyTotalForTeiker({
    required String clienteId,
    required String teikerId,
    required DateTime referenceDate,
  }) async {
    final docs = await _queryMonthlySessions(
      clienteId: clienteId,
      teikerId: teikerId,
      referenceDate: referenceDate,
    );
    return _sumDurationHours(docs);
  }
}

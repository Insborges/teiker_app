import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../domain/work_session.dart';
import '../domain/work_session_repository.dart';

class FirestoreWorkSessionRepository implements WorkSessionRepository {
  final FirebaseFirestore firestore;

  FirestoreWorkSessionRepository(this.firestore);

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
          return WorkSession(
            id: doc.id,
            clienteId: data['clienteId'] as String,
            teikerId: (data['teikerId'] as String?) ?? teikerId,
            startTime: (data['startTime'] as Timestamp).toDate(),
            endTime: null,
            durationHours: (data['durationHours'] as num?)?.toDouble(),
          );
        }
      }

      return null;
    }

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = doc.data();

    final storedTeikerId = (data['teikerId'] as String?) ?? teikerId;

    return WorkSession(
      id: doc.id,
      clienteId: data['clienteId'] as String,
      teikerId: storedTeikerId,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      durationHours: (data['durationHours'] as num?)?.toDouble(),
    );
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
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      throw Exception('Sessão não encontrada.');
    }

    final data = snapshot.data();
    if (data == null) {
      throw Exception('Sessão sem dados.');
    }

    final startTime = (data['startTime'] as Timestamp?)?.toDate();
    if (startTime == null) {
      throw Exception('Sessão sem hora de início válida.');
    }

    final durationHours = end.difference(startTime).inMinutes / 60.0;

    // ✅ Só agora escreve
    await docRef.update({
      'endTime': Timestamp.fromDate(end),
      'durationHours': durationHours,
    });

    return WorkSession(
      id: sessionId,
      clienteId: data['clienteId'] as String,
      teikerId: (data['teikerId'] as String?) ?? '',
      startTime: startTime,
      endTime: end,
      durationHours: durationHours,
    );
  }

  @override
  Future<WorkSession> addManualSession({
    required String clienteId,
    required String teikerId,
    required DateTime start,
    required DateTime end,
  }) async {
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
  Future<double> calculateMonthlyTotal({
    required String clienteId,
    required DateTime referenceDate,
  }) async {
    final monthStart = DateTime(referenceDate.year, referenceDate.month, 1);
    final nextMonth = DateTime(referenceDate.year, referenceDate.month + 1, 1);

    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

    try {
      final snapshot = await firestore
          .collection('workSessions')
          .where('clienteId', isEqualTo: clienteId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
          )
          .where('startTime', isLessThan: Timestamp.fromDate(nextMonth))
          .get();
      docs = snapshot.docs;
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;

      // Fallback: fetch all sessions for clienteId and filter by date locally.
      final snapshot = await firestore
          .collection('workSessions')
          .where('clienteId', isEqualTo: clienteId)
          .get();

      docs = snapshot.docs.where((doc) {
        final start = (doc.data()['startTime'] as Timestamp?)?.toDate();
        return start != null &&
            !start.isBefore(monthStart) &&
            start.isBefore(nextMonth);
      });
    }

    double totalHours = 0;
    for (final doc in docs) {
      final data = doc.data();
      double? duration = (data['durationHours'] as num?)?.toDouble();
      final start = (data['startTime'] as Timestamp?)?.toDate();
      final end = (data['endTime'] as Timestamp?)?.toDate();

      duration ??= (start != null && end != null)
          ? end.difference(start).inMinutes / 60.0
          : null;

      if (duration != null) {
        totalHours += duration;
      }
    }

    await firestore.collection('clientes').doc(clienteId).update({
      'hourasCasa': totalHours,
    });

    return totalHours;
  }
}

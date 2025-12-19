import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WorkSessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _currentUserId => _auth.currentUser?.uid;

  Future<String> startSession({required String clienteId}) async {
    final teikerId = _currentUserId;
    if (teikerId == null) {
      throw Exception("Utilizador não autenticado");
    }

    final now = DateTime.now();

    final doc = await _firestore.collection('workSessions').add({
      'clienteId': clienteId,
      'teikerId': teikerId,
      'startTime': Timestamp.fromDate(now),
      'endTime': null,
      'durationHours': null,
    });

    return doc.id;
  }

  Future<double> finishSession({
    required String clienteId,
    String? sessionId,
  }) async {
    final teikerId = _currentUserId;
    if (teikerId == null) {
      throw Exception("Utilizador não autenticado");
    }

    final query = sessionId != null
        ? _firestore.collection('workSessions').doc(sessionId).get()
        : await _firestore
              .collection('workSessions')
              .where('clienteId', isEqualTo: clienteId)
              .where('teikerId', isEqualTo: teikerId)
              .where('endTime', isNull: true)
              .limit(1)
              .get();

    DocumentSnapshot<Map<String, dynamic>>? sessionDoc;
    if (query is DocumentSnapshot<Map<String, dynamic>>) {
      sessionDoc = query;
    } else if (query is QuerySnapshot<Map<String, dynamic>> &&
        query.docs.isNotEmpty) {
      sessionDoc = query.docs.first;
    }

    if (sessionDoc == null || !sessionDoc.exists) {
      throw Exception("Não existe sessão iniciada para este cliente.");
    }

    final data = sessionDoc.data();
    if(data == null){throw Exception("Sessão sem dados disponíveis");}
    final Map<String, dynamic> nonNullData = data;
    final startTimestamp = nonNullData['startTime'] as Timestamp?;
    final start = startTimestamp?.toDate();
    if (start == null) {
      throw Exception("Sessão sem hora de inicio válida.");
    }

    final end = DateTime.now();
    final duration = end.difference(start).inMinutes / 60.0;

    await sessionDoc.reference.update({
      'endTime': Timestamp.fromDate(end),
      'durationHours': duration,
    });

    final total = await _refreshMonthlyTotal(clienteId, referenceDate: start);

    return total;
  }

  Future<double> addManualSession({
    required String clienteId,
    required DateTime start,
    required DateTime end,
  }) async {
    final teikerId = _currentUserId;

    if (teikerId == null) {
      throw Exception("Utilizador não autenticado");
    }

    final duration = end.difference(start).inMinutes / 60.0;

    await _firestore.collection('workSessions').add({
      'clienteId': clienteId,
      'teikerId': teikerId,
      'startTime': Timestamp.fromDate(start),
      'endTime': Timestamp.fromDate(end),
      'durationHours': duration,
    });

    final total = await _refreshMonthlyTotal(clienteId, referenceDate: start);

    return total;
  }

  Future<double> closePendingSession({
    required String clienteId,
    required String sessionId,
    required DateTime start,
    required DateTime end,
  }) async {
    final teikerId = _currentUserId;
    if (teikerId == null) {
      throw Exception("Utilizador não autenticado");
    }

    final duration = end.difference(start).inMinutes / 60.0;

    await _firestore.collection('workSessions').doc(sessionId).update({
      'clienteId': clienteId,
      'teikerId': teikerId,
      'startTime': Timestamp.fromDate(start),
      'endTime': Timestamp.fromDate(end),
      'durationHours': duration,
    });

    final total = await _refreshMonthlyTotal(clienteId, referenceDate: start);

    return total;
  }

  Future<Map<String, dynamic>?> findOpenSession(String clienteId) async {
    final teikerId = _currentUserId;
    if (teikerId == null) return null;

    final snapshot = await _firestore
        .collection('workSessions')
        .where('clienteId', isEqualTo: clienteId)
        .where('teikerId', isEqualTo: teikerId)
        .where('endTime', isNull: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return {'id': snapshot.docs.first.id, ...snapshot.docs.first.data()};
  }

  Future<double> _refreshMonthlyTotal(
    String clienteId, {
    DateTime? referenceDate,
  }) async {
    final date = referenceDate ?? DateTime.now();
    final monthStart = DateTime(date.year, date.month, 1);
    final nextMonth = DateTime(date.year, date.month + 1, 1);

    final snapshot = await _firestore
        .collection('workSessions')
        .where('clienteId', isEqualTo: clienteId)
        .where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
        )
        .where('startTime', isLessThan: Timestamp.fromDate(nextMonth))
        .get();

    double totalHours = 0;
    for(final doc in snapshot.docs){
      final data = doc.data();
      double? duration = (data['durationHours'] as num?)?.toDouble();
      if(duration == null){
        final start = (data['startTime'] as Timestamp?)?.toDate();
        final end = (data['endTime'] as Timestamp?)?.toDate();

        if(start != null && end != null){
          duration = end.difference(start).inMinutes / 60.0;
        }
      }

      if(duration != null){
        totalHours += duration;
      }
    }

    await _firestore.collection('clientes').doc(clienteId).update({'hourasCasa': totalHours});

    return totalHours;
  }
}

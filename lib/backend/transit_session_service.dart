import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teiker_app/auth/app_user_role.dart';
import 'package:teiker_app/work_sessions/domain/work_session_repository.dart';
import 'package:teiker_app/work_sessions/infrastructure/firestore_work_session_repository.dart';

/// Admin corrections to completed trips. Trips always count at their real duration.
class TransitSessionService {
  TransitSessionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    WorkSessionRepository? repository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _repository =
           repository ??
           FirestoreWorkSessionRepository(
             firestore ?? FirebaseFirestore.instance,
           );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final WorkSessionRepository _repository;

  String _requireAdmin() {
    final user = _auth.currentUser;
    if (user == null || !AppUserRoleResolver.fromEmail(user.email).isAdmin) {
      throw Exception('Só a admin pode gerir deslocações.');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> _sessionRef(
    String sessionId,
    String teikerId,
  ) {
    if (sessionId.trim().isEmpty || teikerId.trim().isEmpty) {
      throw Exception('Deslocação inválida.');
    }
    return _firestore.collection('workSessions').doc(sessionId);
  }

  void _validateSession(Map<String, dynamic>? data, String teikerId) {
    if (data == null || data['clienteId'] != 'DESLOCACAO') {
      throw Exception('Deslocação não encontrada.');
    }
    if (data['teikerId'] != teikerId) {
      throw Exception('Esta deslocação pertence a outra teiker.');
    }
    if (data['endTime'] == null) {
      throw Exception('A deslocação ainda não terminou.');
    }
  }

  Future<void> update({
    required String sessionId,
    required String teikerId,
    required DateTime start,
    required DateTime end,
  }) async {
    final adminId = _requireAdmin();
    final ref = _sessionRef(sessionId, teikerId);
    if (!end.isAfter(start)) {
      throw Exception('A hora de fim deve ser posterior ao início.');
    }
    if (start.isAfter(DateTime.now()) || end.isAfter(DateTime.now())) {
      throw Exception('Não podes registar deslocações no futuro.');
    }
    if (await _repository.hasSessionOverlap(
      teikerId: teikerId,
      start: start,
      end: end,
      excludingSessionId: sessionId,
    )) {
      throw Exception('Esse intervalo já está registado noutra sessão.');
    }
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      _validateSession(snapshot.data(), teikerId);
      final hours = end.difference(start).inMinutes / 60.0;
      transaction.update(ref, {
        'startTime': Timestamp.fromDate(start),
        'endTime': Timestamp.fromDate(end),
        'durationHours': hours,
        'rawDurationHours': hours,
        'durationMultiplier': 1.0,
        'isFixedHolidayRateApplied': false,
        'updatedById': adminId,
        'updatedByRole': AppUserRoleResolver.fromEmail(
          _auth.currentUser?.email,
        ).name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> delete({
    required String sessionId,
    required String teikerId,
  }) async {
    _requireAdmin();
    final ref = _sessionRef(sessionId, teikerId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      _validateSession(snapshot.data(), teikerId);
      transaction.delete(ref);
    });
  }
}

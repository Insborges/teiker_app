import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teiker_app/work_sessions/application/finish_work_session_use_case.dart';
import 'package:teiker_app/work_sessions/domain/work_session.dart';
import 'package:teiker_app/work_sessions/domain/work_session_repository.dart';
import 'package:teiker_app/work_sessions/infrastructure/firestore_work_session_repository.dart';

class WorkSessionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final WorkSessionRepository _repository;
  late final FinishWorkSessionUseCase _finishUseCase;

  WorkSessionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance {
    _repository = FirestoreWorkSessionRepository(_firestore);
    _finishUseCase = FinishWorkSessionUseCase(_repository);
  }

  String _requireUser() {
    final id = _auth.currentUser?.uid;
    if (id == null) {
      throw Exception('Utilizador não autenticado');
    }
    return id;
  }

  Future<WorkSession> startSession({required String clienteId}) async {
    final teikerId = _requireUser();

    final existing = await _repository.findOpenSession(
      clienteId: clienteId,
      teikerId: teikerId,
    );

    if (existing != null) {
      throw Exception('Já existe uma sessão aberta para este cliente.');
    }

    final now = DateTime.now();
    return _repository.startSession(
      clienteId: clienteId,
      teikerId: teikerId,
      start: now,
    );
  }

  Future<double> finishSession({required String clienteId}) async {
    final teikerId = _requireUser();

    return _finishUseCase.execute(clienteId: clienteId, teikerId: teikerId);
  }

  Future<double> addManualSession({
    required String clienteId,
    required DateTime start,
    required DateTime end,
  }) async {
    final teikerId = _requireUser();

    await _repository.addManualSession(
      clienteId: clienteId,
      teikerId: teikerId,
      start: start,
      end: end,
    );

    return _repository.calculateMonthlyTotal(
      clienteId: clienteId,
      referenceDate: start,
    );
  }

  Future<double> closePendingSession({
    required String clienteId,
    required String sessionId,
    required DateTime end,
  }) async {
    final teikerId = _requireUser();

    final session = await _repository.findOpenSession(
      clienteId: clienteId,
      teikerId: teikerId,
    );

    if (session == null || session.id != sessionId) {
      throw Exception('Não existe sessão iniciada para este cliente.');
    }

    await _repository.closeSession(sessionId: sessionId, end: end);

    return _repository.calculateMonthlyTotal(
      clienteId: clienteId,
      referenceDate: session.startTime,
    );
  }

  Future<WorkSession?> findOpenSession(String clienteId) async {
    final teikerId = _auth.currentUser?.uid;
    if (teikerId == null) return null;

    return _repository.findOpenSession(
      clienteId: clienteId,
      teikerId: teikerId,
    );
  }

  Future<double> finishSessionById({
    required String clienteId,
    required String sessionId,
    required DateTime startTime,
  }) async {
    await _repository.closeSession(sessionId: sessionId, end: DateTime.now());

    return _repository.calculateMonthlyTotal(
      clienteId: clienteId,
      referenceDate: startTime,
    );
  }

}

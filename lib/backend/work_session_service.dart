import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teiker_app/work_sessions/application/finish_work_session_use_case.dart';
import 'package:teiker_app/work_sessions/domain/work_session.dart';
import 'package:teiker_app/work_sessions/domain/work_session_repository.dart';
import 'package:teiker_app/work_sessions/infrastructure/firestore_work_session_repository.dart';
import 'notification_service.dart';

class WorkSessionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final WorkSessionRepository _repository;
  late final FinishWorkSessionUseCase _finishUseCase;
  final NotificationService _notificationService = NotificationService();

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

  void _ensureNotFuture(DateTime value) {
    if (value.isAfter(DateTime.now())) {
      throw Exception('Não podes adicionar antes da hora');
    }
  }

  Future<void> _ensureNoOverlap({
    required String teikerId,
    required DateTime start,
    required DateTime end,
    String? excludingSessionId,
  }) async {
    final hasOverlap = await _repository.hasSessionOverlap(
      teikerId: teikerId,
      start: start,
      end: end,
      excludingSessionId: excludingSessionId,
    );
    if (hasOverlap) {
      throw Exception('Esse intervalo já está registado noutra sessão.');
    }
  }

  Future<WorkSession> startSession({
    required String clienteId,
    required String clienteName,
  }) async {
    if (clienteId.trim().isEmpty) {
      throw Exception('Cliente inválido.');
    }
    if (clienteName.trim().isEmpty) {
      throw Exception('Nome do cliente inválido.');
    }

    final teikerId = _requireUser();

    final existing = await _repository.findOpenSession(
      clienteId: clienteId,
      teikerId: teikerId,
    );

    if (existing != null) {
      throw Exception('Já existe uma sessão aberta para este cliente.');
    }

    final anyOpen = await _repository.findAnyOpenSession(teikerId: teikerId);
    if (anyOpen != null) {
      throw Exception('Já tens uma sessão ativa noutro cliente.');
    }

    final now = DateTime.now();
    final session = await _repository.startSession(
      clienteId: clienteId,
      teikerId: teikerId,
      start: now,
    );

    await _notificationService.schedulePendingSessionReminder(
      sessionId: session.id,
      clienteId: clienteId,
      clienteName: clienteName,
      startTime: now,
    );

    return session;
  }

  Future<double> finishSession({required String clienteId}) async {
    final teikerId = _requireUser();

    final open = await _repository.findOpenSession(
      clienteId: clienteId,
      teikerId: teikerId,
    );

    if (open != null) {
      await _ensureNoOverlap(
        teikerId: teikerId,
        start: open.startTime,
        end: DateTime.now(),
        excludingSessionId: open.id,
      );
    }

    final total = await _finishUseCase.execute(
      clienteId: clienteId,
      teikerId: teikerId,
    );

    if (open != null) {
      await _notificationService.cancelPendingSessionReminder(open.id);
    }
    return total;
  }

  Future<double> addManualSession({
    required String clienteId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (clienteId.trim().isEmpty) {
      throw Exception('Cliente inválido.');
    }
    if (!end.isAfter(start)) {
      throw Exception('A hora de fim deve ser posterior ao início.');
    }
    _ensureNotFuture(start);
    _ensureNotFuture(end);

    final teikerId = _requireUser();
    await _ensureNoOverlap(teikerId: teikerId, start: start, end: end);

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

  Future<double> calculateMonthlyTotalForCurrentUser({
    required String clienteId,
    required DateTime referenceDate,
  }) async {
    final teikerId = _requireUser();
    return _repository.calculateMonthlyTotalForTeiker(
      clienteId: clienteId,
      teikerId: teikerId,
      referenceDate: referenceDate,
    );
  }

  Future<double> closePendingSession({
    required String clienteId,
    required String sessionId,
    required DateTime end,
  }) async {
    if (clienteId.trim().isEmpty || sessionId.trim().isEmpty) {
      throw Exception('Sessão inválida.');
    }

    final teikerId = _requireUser();

    final session = await _repository.findOpenSession(
      clienteId: clienteId,
      teikerId: teikerId,
    );

    if (session == null || session.id != sessionId) {
      throw Exception('Não existe sessão iniciada para este cliente.');
    }
    _ensureNotFuture(end);
    await _ensureNoOverlap(
      teikerId: teikerId,
      start: session.startTime,
      end: end,
      excludingSessionId: session.id,
    );

    await _repository.closeSession(sessionId: sessionId, end: end);

    await _notificationService.cancelPendingSessionReminder(sessionId);

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
    final teikerId = _requireUser();
    final open = await _repository.findOpenSession(
      clienteId: clienteId,
      teikerId: teikerId,
    );

    if (open == null || open.id != sessionId) {
      throw Exception('Não existe sessão iniciada para este cliente.');
    }
    final end = DateTime.now();
    await _ensureNoOverlap(
      teikerId: teikerId,
      start: open.startTime,
      end: end,
      excludingSessionId: open.id,
    );

    await _repository.closeSession(sessionId: sessionId, end: end);

    await _notificationService.cancelPendingSessionReminder(sessionId);

    return _repository.calculateMonthlyTotal(
      clienteId: clienteId,
      referenceDate: startTime,
    );
  }
}

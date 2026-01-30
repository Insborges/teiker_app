import 'work_session.dart';

abstract class WorkSessionRepository {
  Future<WorkSession?> findOpenSession({
    required String clienteId,
    required String teikerId,
  });

  Future<WorkSession> startSession({
    required String clienteId,
    required String teikerId,
    required DateTime start,
  });

  Future<WorkSession> closeSession({
    required String sessionId,
    required DateTime end,
  });

  Future<WorkSession> addManualSession({
    required String clienteId,
    required String teikerId,
    required DateTime start,
    required DateTime end,
  });

  Future<double> calculateMonthlyTotal({
    required String clienteId,
    required DateTime referenceDate,
  });

  Future<double> calculateMonthlyTotalForTeiker({
    required String clienteId,
    required String teikerId,
    required DateTime referenceDate,
  });
}

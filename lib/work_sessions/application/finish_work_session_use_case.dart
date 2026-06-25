import '../domain/work_session_repository.dart';

class FinishWorkSessionUseCase {
  final WorkSessionRepository repository;

  FinishWorkSessionUseCase(this.repository);

  Future<MonthlyTotals> execute({
    required String clienteId,
    required String teikerId,
  }) async {
    final session = await repository.findOpenSession(
      clienteId: clienteId,
      teikerId: teikerId,
    );

    if (session == null) {
      return MonthlyTotals(normal: 0.0, extra: 0.0);
    }

    await repository.closeSession(sessionId: session.id, end: DateTime.now());

    return repository.calculateMonthlyTotal(
      clienteId: clienteId,
      referenceDate: session.startTime,
    );
  }
}

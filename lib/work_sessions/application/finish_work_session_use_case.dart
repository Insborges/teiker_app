import '../domain/work_session_repository.dart';

class FinishWorkSessionUseCase {
  final WorkSessionRepository repository;

  FinishWorkSessionUseCase(this.repository);

  Future<double> execute({
    required String clienteId,
    required String teikerId,
  }) async {
    final session = await repository.findOpenSession(
      clienteId: clienteId,
      teikerId: teikerId,
    );

    if (session == null) {
      return 0.0;
      /*throw Exception(
        'Não foi possível localizar uma sessão ativa. '
        'Tenta novamente dentro de alguns segundos.',
      );*/
    }

    await repository.closeSession(sessionId: session.id, end: DateTime.now());

    return repository.calculateMonthlyTotal(
      clienteId: clienteId,
      referenceDate: session.startTime,
    );
  }
}

class WorkSession {
  final String id;
  final String clienteId;
  final String teikerId;
  final DateTime startTime;
  final DateTime? endTime;
  final double? durationHours;

  WorkSession({
    required this.id,
    required this.clienteId,
    required this.teikerId,
    required this.startTime,
    this.endTime,
    this.durationHours,
  });

  bool get isOpen => endTime == null;
}

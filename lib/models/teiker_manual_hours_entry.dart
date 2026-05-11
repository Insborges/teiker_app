import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _parseEntryDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

double _parseEntryHours(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0.0;
  return 0.0;
}

class TeikerManualHoursEntry {
  const TeikerManualHoursEntry({
    required this.id,
    required this.teikerId,
    required this.clienteId,
    required this.clienteName,
    required this.workDate,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.createdAt,
    required this.createdById,
    required this.createdByName,
    required this.createdByRole,
    this.linkedWorkSessionId,
  });

  final String id;
  final String teikerId;
  final String clienteId;
  final String clienteName;
  final DateTime workDate;
  final DateTime startTime;
  final DateTime endTime;
  final double durationHours;
  final DateTime createdAt;
  final String createdById;
  final String createdByName;
  final String createdByRole;
  final String? linkedWorkSessionId;

  factory TeikerManualHoursEntry.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    final startTime = _parseEntryDate(data['startTime']) ?? DateTime.now();
    final endTime = _parseEntryDate(data['endTime']) ?? startTime;
    final workDate = _parseEntryDate(data['workDate']) ?? startTime;
    final createdAt = _parseEntryDate(data['createdAt']) ?? startTime;

    return TeikerManualHoursEntry(
      id: documentId,
      teikerId: (data['teikerId'] as String? ?? '').trim(),
      clienteId: (data['clienteId'] as String? ?? '').trim(),
      clienteName: (data['clienteName'] as String? ?? '').trim(),
      workDate: DateTime(workDate.year, workDate.month, workDate.day),
      startTime: startTime,
      endTime: endTime,
      durationHours: _parseEntryHours(data['durationHours']),
      createdAt: createdAt,
      createdById: (data['createdById'] as String? ?? '').trim(),
      createdByName: (data['createdByName'] as String? ?? '').trim(),
      createdByRole: (data['createdByRole'] as String? ?? '').trim(),
      linkedWorkSessionId: (data['linkedWorkSessionId'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teikerId': teikerId,
      'clienteId': clienteId,
      'clienteName': clienteName,
      'workDate': Timestamp.fromDate(workDate),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationHours': durationHours,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdById': createdById,
      'createdByName': createdByName,
      'createdByRole': createdByRole,
      'linkedWorkSessionId': linkedWorkSessionId,
    };
  }
}

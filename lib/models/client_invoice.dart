import 'package:cloud_firestore/cloud_firestore.dart';

class ClientInvoice {
  const ClientInvoice({
    required this.id,
    required this.clientId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.periodMonthKey,
    required this.periodLabel,
    required this.clientName,
    required this.clientAddress,
    required this.clientPostalCode,
    required this.clientCity,
    required this.totalHours,
    required this.hourlyRate,
    required this.additionalServices,
    required this.servicesTotal,
    required this.subtotal,
    required this.vatRate,
    required this.vatAmount,
    required this.total,
    required this.createdAt,
  });

  final String id;
  final String clientId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String periodMonthKey;
  final String periodLabel;
  final String clientName;
  final String clientAddress;
  final String clientPostalCode;
  final String clientCity;
  final double totalHours;
  final double hourlyRate;
  final Map<String, double> additionalServices;
  final double servicesTotal;
  final double subtotal;
  final double vatRate;
  final double vatAmount;
  final double total;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'invoiceNumber': invoiceNumber,
      'invoiceDate': Timestamp.fromDate(invoiceDate),
      'periodMonthKey': periodMonthKey,
      'periodLabel': periodLabel,
      'clientName': clientName,
      'clientAddress': clientAddress,
      'clientPostalCode': clientPostalCode,
      'clientCity': clientCity,
      'totalHours': totalHours,
      'hourlyRate': hourlyRate,
      'additionalServices': additionalServices,
      'servicesTotal': servicesTotal,
      'subtotal': subtotal,
      'vatRate': vatRate,
      'vatAmount': vatAmount,
      'total': total,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ClientInvoice.fromMap({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return ClientInvoice(
      id: id,
      clientId: (map['clientId'] as String?) ?? '',
      invoiceNumber: (map['invoiceNumber'] as String?) ?? '',
      invoiceDate: _readDate(map['invoiceDate']) ?? DateTime.now(),
      periodMonthKey: (map['periodMonthKey'] as String?) ?? '',
      periodLabel: (map['periodLabel'] as String?) ?? '',
      clientName: (map['clientName'] as String?) ?? '',
      clientAddress: (map['clientAddress'] as String?) ?? '',
      clientPostalCode: (map['clientPostalCode'] as String?) ?? '',
      clientCity: (map['clientCity'] as String?) ?? '',
      totalHours: (map['totalHours'] as num?)?.toDouble() ?? 0,
      hourlyRate: (map['hourlyRate'] as num?)?.toDouble() ?? 0,
      additionalServices: _readAdditionalServices(map['additionalServices']),
      servicesTotal: (map['servicesTotal'] as num?)?.toDouble() ?? 0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      vatRate: (map['vatRate'] as num?)?.toDouble() ?? 0,
      vatAmount: (map['vatAmount'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _readDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  static Map<String, double> _readAdditionalServices(dynamic raw) {
    if (raw is! Map) return const <String, double>{};

    final result = <String, double>{};
    raw.forEach((key, value) {
      final name = key.toString().trim();
      if (name.isEmpty) return;
      final parsed = value is num
          ? value.toDouble()
          : double.tryParse('$value');
      if (parsed == null) return;
      result[name] = parsed;
    });
    return result;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class Clientes {
  String uid;
  String nameCliente;
  String moradaCliente;
  String cidadeCliente;
  String codigoPostal;
  double hourasCasa;
  int telemovel;
  String phoneCountryIso;
  Map<String, double> additionalServicePrices;
  Map<String, Map<String, double>> additionalServicePricesByMonth;
  String email;
  double orcamento;
  List<String> teikersIds;
  bool isArchived;
  String? archivedBy;
  DateTime? archivedAt;

  Clientes({
    required this.uid,
    required this.nameCliente,
    required this.moradaCliente,
    required this.cidadeCliente,
    required this.codigoPostal,
    required this.hourasCasa,
    required this.telemovel,
    this.phoneCountryIso = 'PT',
    Map<String, double>? additionalServicePrices,
    Map<String, Map<String, double>>? additionalServicePricesByMonth,
    required this.email,
    required this.orcamento,
    required this.teikersIds,
    this.isArchived = false,
    this.archivedBy,
    this.archivedAt,
  }) : additionalServicePrices = additionalServicePrices ?? {},
       additionalServicePricesByMonth = additionalServicePricesByMonth ?? {};

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nameCliente': nameCliente,
      'moradaCliente': moradaCliente,
      'cidadeCliente': cidadeCliente,
      'codigoPostal': codigoPostal,
      'hourasCasa': hourasCasa,
      'telemovel': telemovel,
      'phoneCountryIso': phoneCountryIso,
      'additionalServicePrices': additionalServicePrices,
      'additionalServicePricesByMonth': additionalServicePricesByMonth,
      'email': email,
      'orcamento': orcamento,
      'teikersIds': teikersIds,
      'isArchived': isArchived,
      'archivedBy': archivedBy,
      'archivedAt': archivedAt?.toIso8601String(),
    };
  }

  factory Clientes.fromMap(Map<String, dynamic> map) {
    final telemovelRaw = map['telemovel'];
    final telemovel = telemovelRaw is int
        ? telemovelRaw
        : int.tryParse('$telemovelRaw') ?? 0;

    final archivedAtRaw = map['archivedAt'];
    DateTime? archivedAt;
    if (archivedAtRaw is String) {
      archivedAt = DateTime.tryParse(archivedAtRaw);
    } else if (archivedAtRaw is Timestamp) {
      archivedAt = archivedAtRaw.toDate();
    } else if (archivedAtRaw is DateTime) {
      archivedAt = archivedAtRaw;
    } else if (archivedAtRaw is int) {
      archivedAt = DateTime.fromMillisecondsSinceEpoch(archivedAtRaw);
    }

    final archivedByRaw = map['archivedBy'];
    final archivedBy = archivedByRaw == null
        ? null
        : archivedByRaw.toString().trim().isEmpty
        ? null
        : archivedByRaw.toString();

    final additionalRaw = map['additionalServicePrices'];
    final additionalServicePrices = <String, double>{};
    if (additionalRaw is Map) {
      additionalRaw.forEach((key, value) {
        final service = key.toString().trim();
        if (service.isEmpty) return;
        final price = value is num
            ? value.toDouble()
            : double.tryParse('$value');
        if (price == null) return;
        additionalServicePrices[service] = price;
      });
    }

    final additionalByMonthRaw = map['additionalServicePricesByMonth'];
    final additionalServicePricesByMonth = <String, Map<String, double>>{};
    if (additionalByMonthRaw is Map) {
      additionalByMonthRaw.forEach((monthKeyRaw, servicesRaw) {
        final monthKey = monthKeyRaw.toString().trim();
        if (monthKey.isEmpty || servicesRaw is! Map) return;
        final monthServices = <String, double>{};
        servicesRaw.forEach((serviceRaw, valueRaw) {
          final service = serviceRaw.toString().trim();
          if (service.isEmpty) return;
          final price = valueRaw is num
              ? valueRaw.toDouble()
              : double.tryParse('$valueRaw');
          if (price == null) return;
          monthServices[service] = price;
        });
        additionalServicePricesByMonth[monthKey] = monthServices;
      });
    }

    return Clientes(
      uid: map['uid'] as String? ?? '',
      nameCliente: map['nameCliente'] as String? ?? '',
      moradaCliente: map['moradaCliente'] as String? ?? '',
      cidadeCliente: _resolveCidadeCliente(map),
      codigoPostal: _resolveCodigoPostal(map),
      hourasCasa: (map['hourasCasa'] as num?)?.toDouble() ?? 0.0,
      telemovel: telemovel,
      phoneCountryIso: (map['phoneCountryIso'] as String? ?? 'PT')
          .trim()
          .toUpperCase(),
      additionalServicePrices: additionalServicePrices,
      additionalServicePricesByMonth: additionalServicePricesByMonth,
      email: map['email'] as String? ?? '',
      orcamento: (map['orcamento'] as num?)?.toDouble() ?? 0.0,
      teikersIds: List<String>.from(map['teikersIds'] ?? []),
      isArchived: map['isArchived'] == true,
      archivedBy: archivedBy,
      archivedAt: archivedAt,
    );
  }

  static String _resolveCidadeCliente(Map<String, dynamic> map) {
    final explicit = (map['cidadeCliente'] as String?)?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;

    final rawPostal = map['codigoPostal']?.toString().trim() ?? '';
    final match = RegExp(
      r'^([0-9]{4,5}(?:-[0-9]{3,4})?)\s+(.+)$',
    ).firstMatch(rawPostal);
    if (match == null) return '';

    final possibleCity = (match.group(2) ?? '').trim();
    if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(possibleCity)) return '';
    return possibleCity;
  }

  static String _resolveCodigoPostal(Map<String, dynamic> map) {
    final rawPostal = map['codigoPostal']?.toString().trim() ?? '';
    if (rawPostal.isEmpty) return '';

    final match = RegExp(
      r'^([0-9]{4,5}(?:-[0-9]{3,4})?)\s+(.+)$',
    ).firstMatch(rawPostal);
    if (match == null) return rawPostal;

    final possibleCity = (match.group(2) ?? '').trim();
    if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(possibleCity)) return rawPostal;
    return (match.group(1) ?? '').trim();
  }
}

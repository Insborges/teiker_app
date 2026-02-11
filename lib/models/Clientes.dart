class Clientes {
  String uid;
  String nameCliente;
  String moradaCliente;
  String codigoPostal;
  double hourasCasa;
  int telemovel;
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
    required this.codigoPostal,
    required this.hourasCasa,
    required this.telemovel,
    required this.email,
    required this.orcamento,
    required this.teikersIds,
    this.isArchived = false,
    this.archivedBy,
    this.archivedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nameCliente': nameCliente,
      'moradaCliente': moradaCliente,
      'codigoPostal': codigoPostal,
      'hourasCasa': hourasCasa,
      'telemovel': telemovel,
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
    final archivedAt = archivedAtRaw is String
        ? DateTime.tryParse(archivedAtRaw)
        : null;

    return Clientes(
      uid: map['uid'] as String? ?? '',
      nameCliente: map['nameCliente'] as String? ?? '',
      moradaCliente: map['moradaCliente'] as String? ?? '',
      codigoPostal: map['codigoPostal'] ?? '',
      hourasCasa: (map['hourasCasa'] as num?)?.toDouble() ?? 0.0,
      telemovel: telemovel,
      email: map['email'] as String? ?? '',
      orcamento: (map['orcamento'] as num?)?.toDouble() ?? 0.0,
      teikersIds: List<String>.from(map['teikersIds'] ?? []),
      isArchived: map['isArchived'] == true,
      archivedBy: map['archivedBy'] as String?,
      archivedAt: archivedAt,
    );
  }
}

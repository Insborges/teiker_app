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
    };
  }

  factory Clientes.fromMap(Map<String, dynamic> map) {
    final telemovelRaw = map['telemovel'];
    final telemovel = telemovelRaw is int
        ? telemovelRaw
        : int.tryParse('$telemovelRaw') ?? 0;

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
    );
  }
}

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
    return Clientes(
      uid: map['uid'],
      nameCliente: map['nameCliente'],
      moradaCliente: map['moradaCliente'],
      codigoPostal: map['codigoPostal'] ?? '',
      hourasCasa: (map['hourasCasa'] as num).toDouble(),
      telemovel: map['telemovel'],
      email: map['email'],
      orcamento: (map['orcamento'] as num).toDouble(),
      teikersIds: List<String>.from(map['teikersIds'] ?? []),
    );
  }
}

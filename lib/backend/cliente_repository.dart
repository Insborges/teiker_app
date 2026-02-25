import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:teiker_app/models/Clientes.dart';

class ClienteRepository {
  ClienteRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _clientesRef =>
      _firestore.collection('clientes');

  Future<void> createCliente(Clientes cliente) async {
    if (cliente.uid.trim().isEmpty) {
      throw Exception('UID do cliente inválido.');
    }
    cliente.isArchived = false;
    cliente.archivedBy = null;
    cliente.archivedAt = null;
    await _clientesRef.doc(cliente.uid).set(cliente.toMap());
  }

  Future<void> updateCliente(Clientes cliente) async {
    if (cliente.uid.trim().isEmpty) {
      throw Exception('UID do cliente inválido.');
    }
    await _clientesRef.doc(cliente.uid).update(cliente.toMap());
  }

  Future<List<Clientes>> getClientes({
    bool includeArchived = false,
    bool onlyArchived = false,
  }) async {
    final snapshot = await _clientesRef.get();

    return snapshot.docs
        .map((doc) => Clientes.fromMap({...doc.data(), 'uid': doc.id}))
        .where((cliente) {
          if (onlyArchived) return cliente.isArchived;
          if (includeArchived) return true;
          return !cliente.isArchived;
        })
        .where((cliente) => cliente.uid.trim().isNotEmpty)
        .toList();
  }

  Future<void> archiveClientes(
    List<String> clienteIds, {
    required String archivedBy,
  }) async {
    final ids = clienteIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;

    final batch = _firestore.batch();
    for (final id in ids) {
      batch.update(_clientesRef.doc(id), {
        'isArchived': true,
        'archivedBy': archivedBy,
        'archivedAt': DateTime.now().toIso8601String(),
      });
    }
    await batch.commit();
  }

  Future<void> unarchiveClientes(List<String> clienteIds) async {
    final ids = clienteIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;

    final batch = _firestore.batch();
    for (final id in ids) {
      batch.update(_clientesRef.doc(id), {
        'isArchived': false,
        'archivedBy': null,
        'archivedAt': null,
      });
    }
    await batch.commit();
  }

  Future<void> deleteClientes(List<String> clienteIds) async {
    final ids = clienteIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;

    final batch = _firestore.batch();
    for (final id in ids) {
      batch.delete(_clientesRef.doc(id));
    }
    await batch.commit();

    final teikersSnapshot = await _firestore.collection('teikers').get();
    for (final doc in teikersSnapshot.docs) {
      await doc.reference.update({'teikersIds': FieldValue.arrayRemove(ids)});
    }
  }
}

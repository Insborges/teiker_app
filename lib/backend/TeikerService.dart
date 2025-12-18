import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/Teikers.dart';

class TeikerService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _ref => _db.collection('teikers');

  // ADD
  Future<void> addTeiker(Teiker teiker) async {
    await _ref.doc(teiker.uid).set(teiker.toMap());
  }

  // UPDATE COMPLETO
  Future<void> updateTeiker(Teiker teiker) async {
    await _ref.doc(teiker.uid).update(teiker.toMap());
  }

  // STREAM
  Stream<List<Teiker>> streamTeikers() {
    return _ref.snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => Teiker.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    });
  }

  // ADD CLIENTE
  Future<void> addClienteToTeiker(String teikerId, String clienteId) async {
    await _ref.doc(teikerId).update({
      'clientesIds': FieldValue.arrayUnion([clienteId]),
    });
  }

  // REMOVE CLIENTE
  Future<void> removeClienteFromTeiker(
    String teikerId,
    String clienteId,
  ) async {
    await _ref.doc(teikerId).update({
      'clientesIds': FieldValue.arrayRemove([clienteId]),
    });
  }

  // UPDATE FÉRIAS
  Future<void> updateFerias(
    String teikerId,
    DateTime? inicio,
    DateTime? fim,
  ) async {
    await _ref.doc(teikerId).update({
      'feriasInicio': inicio?.toIso8601String(),
      'feriasFim': fim?.toIso8601String(),
    });
  }

  // MARCAR COMO WORKING
  Future<void> startWorking(String teikerId) async {
    await _ref.doc(teikerId).update({
      'isWorking': true,
      'startTime': DateTime.now().toIso8601String(),
    });
  }

  // PARAR TRABALHO
  Future<void> stopWorking(String teikerId) async {
    await _ref.doc(teikerId).update({'isWorking': false, 'startTime': null});
  }
}

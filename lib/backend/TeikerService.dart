import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/Teikers.dart';

class TeikerService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _ref => _db.collection('teikers');

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

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

  Future<void> addFeriasPeriodo(
    String teikerId,
    DateTime inicio,
    DateTime fim,
  ) async {
    final docRef = _ref.doc(teikerId);
    await _db.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      final data = snapshot.data() as Map<String, dynamic>? ?? {};

      final List<Map<String, dynamic>> merged = [];
      final seen = <String>{};

      void addPeriodo(DateTime start, DateTime end) {
        final key = '${start.toIso8601String()}|${end.toIso8601String()}';
        if (!seen.add(key)) return;
        merged.add({
          'inicio': start.toIso8601String(),
          'fim': end.toIso8601String(),
        });
      }

      final existing = (data['feriasPeriodos'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw));
      for (final periodo in existing) {
        final startRaw = periodo['inicio'];
        final endRaw = periodo['fim'];
        final start = startRaw is String ? DateTime.tryParse(startRaw) : null;
        final end = endRaw is String ? DateTime.tryParse(endRaw) : null;
        if (start != null && end != null) addPeriodo(start, end);
      }

      final legacyInicioRaw = data['feriasInicio'];
      final legacyFimRaw = data['feriasFim'];
      final legacyInicio = legacyInicioRaw is String
          ? DateTime.tryParse(legacyInicioRaw)
          : null;
      final legacyFim = legacyFimRaw is String
          ? DateTime.tryParse(legacyFimRaw)
          : null;
      if (legacyInicio != null && legacyFim != null) {
        addPeriodo(legacyInicio, legacyFim);
      }

      addPeriodo(inicio, fim);

      tx.update(docRef, {
        'feriasInicio': inicio.toIso8601String(),
        'feriasFim': fim.toIso8601String(),
        'feriasPeriodos': merged,
      });
    });
  }

  Future<void> saveFeriasPeriodos(
    String teikerId,
    List<FeriasPeriodo> periodos,
  ) async {
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};

    final sorted = [...periodos]..sort((a, b) => a.inicio.compareTo(b.inicio));
    for (final periodo in sorted) {
      final key =
          '${periodo.inicio.toIso8601String()}|${periodo.fim.toIso8601String()}';
      if (!seen.add(key)) continue;
      merged.add({
        'inicio': periodo.inicio.toIso8601String(),
        'fim': periodo.fim.toIso8601String(),
      });
    }

    final last = sorted.isEmpty ? null : sorted.last;
    await _ref.doc(teikerId).update({
      'feriasPeriodos': merged,
      'feriasInicio': last?.inicio.toIso8601String(),
      'feriasFim': last?.fim.toIso8601String(),
    });
  }

  Future<void> addBaixaPeriodo(
    String teikerId,
    DateTime inicio,
    DateTime fim,
    String motivo,
  ) async {
    final normalizedMotivo = motivo.trim();
    if (normalizedMotivo.isEmpty) return;

    final docRef = _ref.doc(teikerId);
    await _db.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      final data = snapshot.data() as Map<String, dynamic>? ?? {};

      final List<Map<String, dynamic>> merged = [];
      final seen = <String>{};

      void addPeriodo(DateTime start, DateTime end, String reason) {
        final key =
            '${start.toIso8601String()}|${end.toIso8601String()}|${reason.trim()}';
        if (!seen.add(key)) return;
        merged.add({
          'inicio': start.toIso8601String(),
          'fim': end.toIso8601String(),
          'motivo': reason.trim(),
        });
      }

      final existing = (data['baixasPeriodos'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw));
      for (final periodo in existing) {
        final start = _parseDate(periodo['inicio']);
        final end = _parseDate(periodo['fim']);
        final reason = (periodo['motivo'] as String? ?? '').trim();
        if (start == null || end == null || reason.isEmpty) continue;
        addPeriodo(start, end, reason);
      }

      addPeriodo(inicio, fim, normalizedMotivo);

      tx.update(docRef, {'baixasPeriodos': merged});
    });
  }

  Future<void> saveBaixasPeriodos(
    String teikerId,
    List<BaixaPeriodo> periodos,
  ) async {
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};

    final sorted = [...periodos]..sort((a, b) => a.inicio.compareTo(b.inicio));
    for (final periodo in sorted) {
      final motivo = periodo.motivo.trim();
      if (motivo.isEmpty) continue;
      final key =
          '${periodo.inicio.toIso8601String()}|${periodo.fim.toIso8601String()}|$motivo';
      if (!seen.add(key)) continue;
      merged.add({
        'inicio': periodo.inicio.toIso8601String(),
        'fim': periodo.fim.toIso8601String(),
        'motivo': motivo,
      });
    }

    await _ref.doc(teikerId).update({'baixasPeriodos': merged});
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

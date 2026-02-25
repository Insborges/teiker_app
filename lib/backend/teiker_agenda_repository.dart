import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:teiker_app/models/Teikers.dart';

class TeikerAgendaRepository {
  TeikerAgendaRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  bool _isAdminEmail(String? email) =>
      email?.trim().endsWith('@teiker.ch') ?? false;

  bool get _isCurrentUserAdmin => _isAdminEmail(_auth.currentUser?.email);

  Color _parseTeikerColor(dynamic corRaw) {
    if (corRaw is int) return Color(corRaw);
    if (corRaw is String && corRaw.isNotEmpty) {
      return Color(int.tryParse(corRaw) ?? Colors.green.toARGB32());
    }
    return Colors.green;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  List<DateTime> _expandRangeDays(DateTime inicio, DateTime fim) {
    final dias = <DateTime>[];
    final seen = <DateTime>{};
    var d = DateTime.utc(inicio.year, inicio.month, inicio.day);
    final end = DateTime.utc(fim.year, fim.month, fim.day);
    while (!d.isAfter(end)) {
      if (seen.add(d)) dias.add(d);
      d = d.add(const Duration(days: 1));
    }
    return dias;
  }

  Future<List<Map<String, dynamic>>> getFeriasTeikers() async {
    final user = _auth.currentUser;
    final admin = _isCurrentUserAdmin;
    final snapshot = await _firestore.collection('teikers').get();

    final ferias = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final corRaw = data['cor'];

      if (!admin && doc.id != user?.uid) continue;

      final cor = _parseTeikerColor(corRaw);
      final dias = <DateTime>[];
      final diasSet = <DateTime>{};
      final periodos = <Map<String, dynamic>>[
        ...(data['feriasPeriodos'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw)),
      ];

      final inicioLegacy = data['feriasInicio'];
      final fimLegacy = data['feriasFim'];
      if (inicioLegacy != null && fimLegacy != null) {
        periodos.add({'inicio': inicioLegacy, 'fim': fimLegacy});
      }

      for (final periodo in periodos) {
        final inicio = _parseDate(periodo['inicio']);
        final fim = _parseDate(periodo['fim']);
        if (inicio == null || fim == null) continue;
        for (final day in _expandRangeDays(inicio, fim)) {
          if (diasSet.add(day)) dias.add(day);
        }
      }

      if (dias.isEmpty) continue;

      ferias.add({
        'uid': doc.id,
        'nome': data['name'] ?? '',
        'cor': cor,
        'dias': dias,
      });
    }

    return ferias;
  }

  Future<List<Map<String, dynamic>>> getBaixasTeikers() async {
    final user = _auth.currentUser;
    final admin = _isCurrentUserAdmin;
    final snapshot = await _firestore.collection('teikers').get();

    final baixas = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      if (!admin && doc.id != user?.uid) continue;

      final data = doc.data();
      final periodos = (data['baixasPeriodos'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList();
      if (periodos.isEmpty) continue;

      final dias = <DateTime>[];
      final diasSet = <DateTime>{};

      for (final periodo in periodos) {
        final inicio = _parseDate(periodo['inicio']);
        final fim = _parseDate(periodo['fim']);
        if (inicio == null || fim == null) continue;

        for (final day in _expandRangeDays(inicio, fim)) {
          if (diasSet.add(day)) dias.add(day);
        }
      }

      if (dias.isEmpty) continue;
      baixas.add({
        'uid': doc.id,
        'nome': data['name'] ?? '',
        'dias': dias,
        'cor': Colors.red.shade700,
      });
    }

    return baixas;
  }

  Future<List<Map<String, dynamic>>> getConsultasTeikers() async {
    final user = _auth.currentUser;
    final admin = _isCurrentUserAdmin;
    final snapshot = await _firestore.collection('teikers').get();

    final consultas = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      if (!admin && doc.id != user?.uid) continue;

      final data = doc.data();
      final corRaw = data['cor'];
      final rawConsultas = data['consultas'] as List<dynamic>? ?? [];
      final cor = _parseTeikerColor(corRaw);

      for (final c in rawConsultas) {
        if (c is! Map<String, dynamic>) continue;
        try {
          final consulta = Consulta.fromMap(c);
          consultas.add({
            'uid': doc.id,
            'nome': data['name'] ?? '',
            'descricao': consulta.descricao,
            'data': consulta.data,
            'cor': cor,
          });
        } catch (_) {
          continue;
        }
      }
    }

    return consultas;
  }
}

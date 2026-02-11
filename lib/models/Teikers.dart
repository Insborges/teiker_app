import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value);
  if (value is Timestamp) return value.toDate();
  return null;
}

Color _parseColor(dynamic value) {
  if (value is int) return Color(value);
  if (value is String && value.isNotEmpty) {
    return Color(int.tryParse(value) ?? Colors.green.toARGB32());
  }
  return Colors.green;
}

class Teiker {
  final String uid;
  final String nameTeiker;
  final String email;
  final int telemovel;
  final double horas;
  final List<String> clientesIds;
  final List<Consulta> consultas;
  final DateTime? feriasInicio;
  final DateTime? feriasFim;
  final Color corIdentificadora;
  final bool isWorking;
  final DateTime? startTime;

  Teiker({
    required this.uid,
    required this.nameTeiker,
    required this.email,
    required this.telemovel,
    required this.horas,
    required this.clientesIds,
    required this.consultas,
    required this.corIdentificadora,
    required this.isWorking,
    this.feriasInicio,
    this.feriasFim,
    this.startTime,
  });

  factory Teiker.fromMap(Map<String, dynamic> data, String documentId) {
    return Teiker(
      uid: documentId,
      nameTeiker: data['name'] ?? '',
      email: data['email'] ?? '',
      telemovel: data['telemovel'] ?? 0,
      horas: (data['horas'] ?? 0).toDouble(),
      corIdentificadora: _parseColor(data['cor']),
      clientesIds: List<String>.from(data['clientesIds'] ?? []),
      consultas: (data['consultas'] as List<dynamic>? ?? [])
          .map((c) => Consulta.fromMap(c as Map<String, dynamic>? ?? {}))
          .toList(),

      feriasInicio: _parseDate(data['feriasInicio']),
      feriasFim: _parseDate(data['feriasFim']),

      isWorking: data['isWorking'] ?? false,
      startTime: _parseDate(data['startTime']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': nameTeiker,
      'email': email,
      'telemovel': telemovel,
      'horas': horas,
      'cor': corIdentificadora.toARGB32(),
      'clientesIds': clientesIds,
      'consultas': consultas.map((c) => c.toMap()).toList(),
      'feriasInicio': feriasInicio?.toIso8601String(),
      'feriasFim': feriasFim?.toIso8601String(),
      'isWorking': isWorking,
      'startTime': startTime?.toIso8601String(),
    };
  }

  Teiker copyWith({
    String? uid,
    String? nameTeiker,
    String? email,
    int? telemovel,
    double? horas,
    List<String>? clientesIds,
    List<Consulta>? consultas,
    DateTime? feriasInicio,
    DateTime? feriasFim,
    Color? corIdentificadora,
    bool? isWorking,
    DateTime? startTime,
  }) {
    return Teiker(
      uid: uid ?? this.uid,
      nameTeiker: nameTeiker ?? this.nameTeiker,
      email: email ?? this.email,
      telemovel: telemovel ?? this.telemovel,
      horas: horas ?? this.horas,
      clientesIds: clientesIds ?? this.clientesIds,
      consultas: consultas ?? this.consultas,
      feriasInicio: feriasInicio ?? this.feriasInicio,
      feriasFim: feriasFim ?? this.feriasFim,
      corIdentificadora: corIdentificadora ?? this.corIdentificadora,
      isWorking: isWorking ?? this.isWorking,
      startTime: startTime ?? this.startTime,
    );
  }
}

class Consulta {
  final DateTime data;
  final String descricao;

  Consulta({required this.data, required this.descricao});

  factory Consulta.fromMap(Map<String, dynamic> map) {
    final rawDate = map['data'];
    DateTime? parsed;
    if (rawDate is Timestamp) parsed = rawDate.toDate();
    if (rawDate is String) parsed = DateTime.tryParse(rawDate);

    return Consulta(
      data: parsed ?? DateTime.now(),
      descricao: map['descricao'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'data': data.toIso8601String(), 'descricao': descricao};
  }
}

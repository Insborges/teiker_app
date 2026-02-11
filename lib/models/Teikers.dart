import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:teiker_app/models/teiker_workload.dart';

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

class FeriasPeriodo {
  final DateTime inicio;
  final DateTime fim;

  const FeriasPeriodo({required this.inicio, required this.fim});

  factory FeriasPeriodo.fromMap(Map<String, dynamic> map) {
    final inicio = _parseDate(map['inicio']) ?? DateTime.now();
    final fim = _parseDate(map['fim']) ?? inicio;
    return FeriasPeriodo(inicio: inicio, fim: fim);
  }

  Map<String, dynamic> toMap() {
    return {'inicio': inicio.toIso8601String(), 'fim': fim.toIso8601String()};
  }
}

class BaixaPeriodo {
  final DateTime inicio;
  final DateTime fim;
  final String motivo;

  const BaixaPeriodo({
    required this.inicio,
    required this.fim,
    required this.motivo,
  });

  factory BaixaPeriodo.fromMap(Map<String, dynamic> map) {
    final inicio = _parseDate(map['inicio']) ?? DateTime.now();
    final fim = _parseDate(map['fim']) ?? inicio;
    final motivo = (map['motivo'] as String? ?? '').trim();
    return BaixaPeriodo(inicio: inicio, fim: fim, motivo: motivo);
  }

  Map<String, dynamic> toMap() {
    return {
      'inicio': inicio.toIso8601String(),
      'fim': fim.toIso8601String(),
      'motivo': motivo,
    };
  }
}

class Teiker {
  final String uid;
  final String nameTeiker;
  final String email;
  final DateTime? birthDate;
  final int telemovel;
  final String phoneCountryIso;
  final double horas;
  final int workPercentage;
  final List<String> clientesIds;
  final List<Consulta> consultas;
  final DateTime? feriasInicio;
  final DateTime? feriasFim;
  final List<FeriasPeriodo> feriasPeriodos;
  final List<BaixaPeriodo> baixasPeriodos;
  final Color corIdentificadora;
  final bool isWorking;
  final DateTime? startTime;

  Teiker({
    required this.uid,
    required this.nameTeiker,
    required this.email,
    this.birthDate,
    required this.telemovel,
    this.phoneCountryIso = 'PT',
    required this.horas,
    this.workPercentage = TeikerWorkload.fullTime,
    required this.clientesIds,
    required this.consultas,
    required this.corIdentificadora,
    required this.isWorking,
    this.feriasInicio,
    this.feriasFim,
    this.feriasPeriodos = const [],
    this.baixasPeriodos = const [],
    this.startTime,
  });

  factory Teiker.fromMap(Map<String, dynamic> data, String documentId) {
    final parsedPeriodos = (data['feriasPeriodos'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .map(FeriasPeriodo.fromMap)
        .toList();
    final legacyInicio = _parseDate(data['feriasInicio']);
    final legacyFim = _parseDate(data['feriasFim']);
    final seen = <String>{};
    final periodosRaw = <FeriasPeriodo>[];
    for (final periodo in parsedPeriodos) {
      final key =
          '${periodo.inicio.toIso8601String()}|${periodo.fim.toIso8601String()}';
      if (seen.add(key)) {
        periodosRaw.add(periodo);
      }
    }
    if (legacyInicio != null && legacyFim != null) {
      final key =
          '${legacyInicio.toIso8601String()}|${legacyFim.toIso8601String()}';
      if (seen.add(key)) {
        periodosRaw.add(FeriasPeriodo(inicio: legacyInicio, fim: legacyFim));
      }
    }
    final baixasRaw = (data['baixasPeriodos'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .map(BaixaPeriodo.fromMap)
        .toList();

    final storedWeeklyHours = (data['horas'] as num?)?.toDouble();
    final workPercentage = TeikerWorkload.normalizePercentage(
      data['workPercentage'],
      fallbackWeeklyHours: storedWeeklyHours,
    );
    final weeklyHours =
        storedWeeklyHours ??
        TeikerWorkload.weeklyHoursForPercentage(workPercentage);

    return Teiker(
      uid: documentId,
      nameTeiker: data['name'] ?? '',
      email: data['email'] ?? '',
      birthDate:
          _parseDate(data['birthDate']) ?? _parseDate(data['dataNascimento']),
      workPercentage: workPercentage,
      telemovel: data['telemovel'] ?? 0,
      phoneCountryIso: (data['phoneCountryIso'] as String? ?? 'PT')
          .trim()
          .toUpperCase(),
      horas: weeklyHours,
      corIdentificadora: _parseColor(data['cor']),
      clientesIds: List<String>.from(data['clientesIds'] ?? []),
      consultas: (data['consultas'] as List<dynamic>? ?? [])
          .map((c) => Consulta.fromMap(c as Map<String, dynamic>? ?? {}))
          .toList(),

      feriasInicio: _parseDate(data['feriasInicio']),
      feriasFim: _parseDate(data['feriasFim']),
      feriasPeriodos: periodosRaw,
      baixasPeriodos: baixasRaw,

      isWorking: data['isWorking'] ?? false,
      startTime: _parseDate(data['startTime']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': nameTeiker,
      'email': email,
      'birthDate': birthDate?.toIso8601String(),
      'telemovel': telemovel,
      'phoneCountryIso': phoneCountryIso,
      'horas': horas,
      'workPercentage': workPercentage,
      'cor': corIdentificadora.toARGB32(),
      'clientesIds': clientesIds,
      'consultas': consultas.map((c) => c.toMap()).toList(),
      'feriasInicio': feriasInicio?.toIso8601String(),
      'feriasFim': feriasFim?.toIso8601String(),
      'feriasPeriodos': feriasPeriodos.map((p) => p.toMap()).toList(),
      'baixasPeriodos': baixasPeriodos.map((p) => p.toMap()).toList(),
      'isWorking': isWorking,
      'startTime': startTime?.toIso8601String(),
    };
  }

  Teiker copyWith({
    String? uid,
    String? nameTeiker,
    String? email,
    DateTime? birthDate,
    int? telemovel,
    String? phoneCountryIso,
    double? horas,
    int? workPercentage,
    List<String>? clientesIds,
    List<Consulta>? consultas,
    DateTime? feriasInicio,
    DateTime? feriasFim,
    List<FeriasPeriodo>? feriasPeriodos,
    List<BaixaPeriodo>? baixasPeriodos,
    Color? corIdentificadora,
    bool? isWorking,
    DateTime? startTime,
  }) {
    return Teiker(
      uid: uid ?? this.uid,
      nameTeiker: nameTeiker ?? this.nameTeiker,
      email: email ?? this.email,
      birthDate: birthDate ?? this.birthDate,
      telemovel: telemovel ?? this.telemovel,
      phoneCountryIso: phoneCountryIso ?? this.phoneCountryIso,
      horas: horas ?? this.horas,
      workPercentage: workPercentage ?? this.workPercentage,
      clientesIds: clientesIds ?? this.clientesIds,
      consultas: consultas ?? this.consultas,
      feriasInicio: feriasInicio ?? this.feriasInicio,
      feriasFim: feriasFim ?? this.feriasFim,
      feriasPeriodos: feriasPeriodos ?? this.feriasPeriodos,
      baixasPeriodos: baixasPeriodos ?? this.baixasPeriodos,
      corIdentificadora: corIdentificadora ?? this.corIdentificadora,
      isWorking: isWorking ?? this.isWorking,
      startTime: startTime ?? this.startTime,
    );
  }

  double get weeklyTargetHours =>
      TeikerWorkload.weeklyHoursForPercentage(workPercentage);

  String get workPercentageLabel =>
      TeikerWorkload.labelForPercentage(workPercentage);
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

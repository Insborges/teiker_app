import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'package:teiker_app/models/Clientes.dart';
import 'package:teiker_app/models/Teikers.dart';
import 'package:teiker_app/models/teiker_workload.dart';

class AuthService {
  final _firebase = FirebaseService();

  Color _parseTeikerColor(dynamic corRaw) {
    if (corRaw is int) return Color(corRaw);
    if (corRaw is String && corRaw.isNotEmpty) {
      return Color(int.tryParse(corRaw) ?? Colors.green.toARGB32());
    }
    return Colors.green;
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

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

  Future<bool?> _hasAccountForEmail(String email) async {
    try {
      if (isAdminEmail(email)) return null;
      final snapshot = await FirebaseFirestore.instance
          .collection('teikers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (_) {
      return null;
    }
  }

  Future<String> _mapLoginErrorMessage({
    required String code,
    required String email,
  }) async {
    switch (code) {
      case 'invalid-email':
        return 'Email invalido. Verifica o formato.';
      case 'user-disabled':
        return 'Esta conta esta desativada.';
      case 'user-not-found':
        return 'Conta nao existente.';
      case 'wrong-password':
        return 'A palavra-passe nao corresponde ao email.';
      case 'too-many-requests':
        return 'Muitas tentativas seguidas. Tenta novamente daqui a pouco.';
      case 'invalid-credential':
        final hasAccount = await _hasAccountForEmail(email);
        if (hasAccount == false) {
          return 'Conta nao existente.';
        }
        if (hasAccount == true) {
          return 'A palavra-passe nao corresponde ao email.';
        }
        return 'Email ou palavra-passe incorretos.';
      default:
        return 'Nao foi possivel iniciar sessao. Tenta novamente.';
    }
  }

  // Registo
  Future<UserCredential> signUp(String email, String password) async {
    return await _firebase.auth.createUserWithEmailAndPassword(
      email: _normalizeEmail(email),
      password: password,
    );
  }

  // Login
  Future<UserCredential> login(String email, String password) async {
    final normalizedEmail = _normalizeEmail(email);
    try {
      if (!isAdminEmail(normalizedEmail)) {
        final hasAccount = await _hasAccountForEmail(normalizedEmail);
        if (hasAccount == false) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'Conta nao existente.',
          );
        }
      }

      final credential = await _firebase.auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      if (!isAdminEmail(credential.user?.email)) {
        final uid = credential.user?.uid;
        if (uid == null) {
          await _firebase.auth.signOut();
          throw FirebaseAuthException(
            code: 'invalid-user',
            message: 'Conta inválida.',
          );
        }
        final teikerDoc = await FirebaseFirestore.instance
            .collection('teikers')
            .doc(uid)
            .get();
        if (!teikerDoc.exists) {
          await _firebase.auth.signOut();
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'Conta nao existente.',
          );
        }
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      final mappedMessage = await _mapLoginErrorMessage(
        code: e.code,
        email: normalizedEmail,
      );
      throw FirebaseAuthException(code: e.code, message: mappedMessage);
    }
  }

  // Logout
  Future<void> logout() async {
    await _firebase.auth.signOut();
  }

  // Recuperação de password
  Future<void> resetPassword(String email) async {
    try {
      await _firebase.auth.sendPasswordResetEmail(
        email: _normalizeEmail(email),
      );
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Erro a enviar email.";
    } catch (e) {
      throw "Erro inesperado.";
    }
  }

  //É admin ou não
  bool get isCurrentUserAdmin =>
      isAdminEmail(_firebase.auth.currentUser?.email);

  static bool isAdminEmail(String? email) {
    if (email == null) return false;

    return email.trim().endsWith("@teiker.ch");
  }

  Future<void> createTeiker({
    required String name,
    required String email,
    required String password,
    required int telemovel,
    String phoneCountryIso = 'PT',
    required int workPercentage,
    DateTime? birthDate,
    List<String>? clientesIds,
    Color? cor,
  }) async {
    if (name.trim().isEmpty) {
      throw Exception('Nome da teiker é obrigatório.');
    }
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      throw Exception('Email da teiker é obrigatório.');
    }
    if (password.trim().length < 6) {
      throw Exception('A password deve ter pelo menos 6 caracteres.');
    }
    if (telemovel <= 0) {
      throw Exception('Telemóvel inválido.');
    }
    if (!TeikerWorkload.isSupported(workPercentage)) {
      throw Exception('Percentagem de trabalho inválida.');
    }
    final weeklyHours = TeikerWorkload.weeklyHoursForPercentage(workPercentage);

    final creatorAuth = await _firebase.secondaryAuth;
    final userCredential = await creatorAuth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    final teiker = Teiker(
      uid: userCredential.user!.uid,
      nameTeiker: name,
      email: normalizedEmail,
      birthDate: birthDate,
      telemovel: telemovel,
      phoneCountryIso: phoneCountryIso,
      horas: weeklyHours,
      workPercentage: workPercentage,
      clientesIds: clientesIds ?? [],
      consultas: const [],
      corIdentificadora: cor ?? Colors.green,
      isWorking: false,
      startTime: null,
    );

    try {
      await FirebaseFirestore.instance
          .collection("teikers")
          .doc(teiker.uid)
          .set(teiker.toMap());
    } catch (e) {
      try {
        await userCredential.user?.delete();
      } catch (_) {}
      throw Exception('Conta criada, mas falhou ao guardar dados: $e');
    }
  }

  Future<void> updateTeikerContact({
    required String uid,
    required int newTelemovel,
    String? phoneCountryIso,
  }) async {
    try {
      // Atualiza Firestore
      final payload = <String, dynamic>{'telemovel': newTelemovel};
      if (phoneCountryIso != null && phoneCountryIso.trim().isNotEmpty) {
        payload['phoneCountryIso'] = phoneCountryIso.trim().toUpperCase();
      }
      await FirebaseService().firestore
          .collection('teikers')
          .doc(uid)
          .update(payload);
    } catch (e) {
      throw "Erro ao atualizar email e contacto: $e";
    }
  }

  Future<List<Map<String, dynamic>>> getFeriasTeikers() async {
    final user = FirebaseAuth.instance.currentUser;
    final admin = isCurrentUserAdmin;

    final snapshot = await FirebaseFirestore.instance
        .collection('teikers')
        .get();

    final ferias = <Map<String, dynamic>>[];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final corRaw = data['cor'];

      // Restringir para não-admin
      if (!admin && doc.id != user!.uid) continue;

      // Cor blindada: se falhar, aplica default
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
          if (diasSet.add(day)) {
            dias.add(day);
          }
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
    final user = FirebaseAuth.instance.currentUser;
    final admin = isCurrentUserAdmin;

    final snapshot = await FirebaseFirestore.instance
        .collection('teikers')
        .get();

    final baixas = <Map<String, dynamic>>[];

    for (var doc in snapshot.docs) {
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
          if (diasSet.add(day)) {
            dias.add(day);
          }
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
    final user = FirebaseAuth.instance.currentUser;
    final admin = isCurrentUserAdmin;

    final snapshot = await FirebaseFirestore.instance
        .collection('teikers')
        .get();

    final List<Map<String, dynamic>> consultas = [];

    for (var doc in snapshot.docs) {
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

  Future<void> createCliente(Clientes cliente) async {
    if (cliente.uid.trim().isEmpty) {
      throw Exception('UID do cliente inválido.');
    }
    cliente.isArchived = false;
    cliente.archivedBy = null;
    cliente.archivedAt = null;
    await FirebaseFirestore.instance
        .collection("clientes")
        .doc(cliente.uid)
        .set(cliente.toMap());
  }

  Future<void> updateCliente(Clientes cliente) async {
    if (cliente.uid.trim().isEmpty) {
      throw Exception('UID do cliente inválido.');
    }
    await FirebaseFirestore.instance
        .collection("clientes")
        .doc(cliente.uid)
        .update(cliente.toMap());
  }

  Future<List<Clientes>> getClientes({
    bool includeArchived = false,
    bool onlyArchived = false,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection("clientes")
        .get();

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

    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      final ref = FirebaseFirestore.instance.collection('clientes').doc(id);
      batch.update(ref, {
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

    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      final ref = FirebaseFirestore.instance.collection('clientes').doc(id);
      batch.update(ref, {
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

    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      final ref = FirebaseFirestore.instance.collection('clientes').doc(id);
      batch.delete(ref);
    }
    await batch.commit();

    final teikersSnapshot = await FirebaseFirestore.instance
        .collection('teikers')
        .get();
    for (final doc in teikersSnapshot.docs) {
      await doc.reference.update({'clientesIds': FieldValue.arrayRemove(ids)});
    }
  }

  Future<void> deleteTeikers(List<Teiker> teikers) async {
    final valid = teikers.where((t) => t.uid.trim().isNotEmpty).toList();
    if (valid.isEmpty) return;

    final ids = valid.map((t) => t.uid).toList();
    final emails = valid.map((t) => t.email.trim().toLowerCase()).toList();

    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(FirebaseFirestore.instance.collection('teikers').doc(id));
    }
    await batch.commit();

    final clientesSnapshot = await FirebaseFirestore.instance
        .collection('clientes')
        .get();
    for (final doc in clientesSnapshot.docs) {
      await doc.reference.update({'teikersIds': FieldValue.arrayRemove(ids)});
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final currentEmail = currentUser.email?.trim().toLowerCase();
      if (currentEmail != null && emails.contains(currentEmail)) {
        await currentUser.delete();
      }
    }
  }
}

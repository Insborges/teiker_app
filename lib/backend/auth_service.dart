import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:teiker_app/models/Clientes.dart';
import 'package:teiker_app/models/Teikers.dart';

import 'firebase_service.dart';

class AuthService {
  final _firebase = FirebaseService();

  // Registo
  Future<UserCredential> signUp(String email, String password) async {
    return await _firebase.auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Login
  Future<UserCredential> login(String email, String password) async {
    return _firebase.auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Logout
  Future<void> logout() async {
    await _firebase.auth.signOut();
  }

  // Recuperação de password
  Future<void> resetPassword(String email) async {
    try {
      await _firebase.auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "Erro a enviar email.";
    } catch (e) {
      throw "Erro inesperado.";
    }
  }

  //É admin ou não
  bool get isCurrentUserAdmin => isAdminEmail(_firebase.auth.currentUser?.email);

  static bool isAdminEmail(String? email){
    if(email == null) return false;

    return email.trim().endsWith("@teiker.ch");
  }

  Future<void> createTeiker({
    required String name,
    required String email,
    required String password,
    required int telemovel,
    required double horas,
    List<String>? clientesIds,
    Color? cor,
  }) async {
    // Cria user no Auth
    final userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    final teiker = Teiker(
      uid: userCredential.user!.uid,
      nameTeiker: name,
      email: email,
      telemovel: telemovel,
      horas: horas,
      clientesIds: clientesIds ?? [],
      consultas: const [],
      corIdentificadora: cor ?? Colors.green,
      isWorking: false,
      startTime: null,
    );

    // Salva no Firestore
    await FirebaseFirestore.instance
        .collection("teikers")
        .doc(teiker.uid)
        .set(teiker.toMap());
  }

  Future<void> updateTeikerContact({
    required String uid,
    required int newTelemovel,
  }) async {
    try {
      // Atualiza Firestore
      await FirebaseService().firestore.collection('teikers').doc(uid).update({
        'telemovel': newTelemovel,
      });
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

    List<Map<String, dynamic>> ferias = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();

      final inicioRaw = data['feriasInicio'];
      final fimRaw = data['feriasFim'];
      final corRaw = data['cor'];

      // SKIP se não tem férias definidas
      if (inicioRaw == null || fimRaw == null) continue;

      // Converter datas com máxima tolerância
      DateTime? inicio;
      DateTime? fim;

      try {
        if (inicioRaw is Timestamp) {
          inicio = inicioRaw.toDate();
        } else if (inicioRaw is String && inicioRaw.isNotEmpty) {
          inicio = DateTime.parse(inicioRaw);
        }

        if (fimRaw is Timestamp) {
          fim = fimRaw.toDate();
        } else if (fimRaw is String && fimRaw.isNotEmpty) {
          fim = DateTime.parse(fimRaw);
        }
      } catch (_) {
        continue;
      }

      if (inicio == null || fim == null) continue;

      // Restringir para não-admin
      if (!admin && doc.id != user!.uid) continue;

      // Cor blindada: se falhar, aplica default
      Color cor;
      if (corRaw is int) {
        cor = Color(corRaw);
      } else if (corRaw is String && corRaw.isNotEmpty) {
        cor = Color(int.parse(corRaw));
      } else {
        cor = Colors.green;
      }

      // Gerar lista de dias das férias
      final dias = <DateTime>[];
      DateTime d = inicio;
      while (!d.isAfter(fim)) {
        dias.add(DateTime.utc(d.year, d.month, d.day));
        d = d.add(const Duration(days: 1));
      }

      ferias.add({
        'uid': doc.id,
        'nome': data['name'] ?? '',
        'cor': cor,
        'dias': dias,
      });
    }

    return ferias;
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

      Color cor;
      if (corRaw is int) {
        cor = Color(corRaw);
      } else if (corRaw is String && corRaw.isNotEmpty) {
        cor = Color(int.tryParse(corRaw) ?? Colors.green.value);
      } else {
        cor = Colors.green;
      }

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
    await FirebaseFirestore.instance
        .collection("clientes")
        .doc(cliente.uid)
        .set(cliente.toMap());
  }

  Future<void> updateCliente(Clientes cliente) async {
    await FirebaseFirestore.instance
        .collection("clientes")
        .doc(cliente.uid)
        .update(cliente.toMap());
  }

  Future<List<Clientes>> getClientes() async {
    final snapshot = await FirebaseFirestore.instance
        .collection("clientes")
        .get();

    return snapshot.docs.map((doc) => Clientes.fromMap(doc.data())).toList();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:teiker_app/backend/cliente_repository.dart';
import 'package:teiker_app/backend/teiker_agenda_repository.dart';
import 'firebase_service.dart';
import 'package:teiker_app/models/Clientes.dart';
import 'package:teiker_app/models/Teikers.dart';
import 'package:teiker_app/models/teiker_workload.dart';

class AuthService {
  final _firebase = FirebaseService();
  final ClienteRepository _clienteRepository = ClienteRepository();
  final TeikerAgendaRepository _teikerAgendaRepository =
      TeikerAgendaRepository();
  CollectionReference<Map<String, dynamic>> get _teikersRef =>
      FirebaseFirestore.instance.collection('teikers');
  CollectionReference<Map<String, dynamic>> get _clientesRef =>
      FirebaseFirestore.instance.collection('clientes');
  CollectionReference<Map<String, dynamic>> get _workSessionsRef =>
      FirebaseFirestore.instance.collection('workSessions');

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findTeikerByEmail(
    String normalizedEmail,
  ) async {
    final exactMatch = await _teikersRef
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (exactMatch.docs.isNotEmpty) {
      return exactMatch.docs.first;
    }

    // Fallback for legacy docs with email casing/spacing inconsistencies.
    final allTeikers = await _teikersRef.get();
    for (final doc in allTeikers.docs) {
      final rawEmail = doc.data()['email'];
      final email = rawEmail is String ? rawEmail.trim().toLowerCase() : '';
      if (email == normalizedEmail) {
        return doc;
      }
    }
    return null;
  }

  Future<bool?> _hasAccountForEmail(String email) async {
    try {
      if (isAdminEmail(email)) return null;
      final teiker = await _findTeikerByEmail(email);
      return teiker != null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _migrateClienteTeikerIds({
    required String oldTeikerId,
    required String newTeikerId,
  }) async {
    final snapshot = await _clientesRef
        .where('teikersIds', arrayContains: oldTeikerId)
        .get();
    if (snapshot.docs.isEmpty) return;

    var batch = FirebaseFirestore.instance.batch();
    var pending = 0;

    for (final doc in snapshot.docs) {
      final current = List<String>.from(doc.data()['teikersIds'] ?? const []);
      final replaced = current
          .map((id) => id == oldTeikerId ? newTeikerId : id)
          .toList();
      final deduped = <String>[];
      final seen = <String>{};
      for (final id in replaced) {
        if (seen.add(id)) deduped.add(id);
      }

      batch.update(doc.reference, {'teikersIds': deduped});
      pending++;
      if (pending >= 450) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        pending = 0;
      }
    }

    if (pending > 0) {
      await batch.commit();
    }
  }

  Future<void> _migrateWorkSessionsTeikerId({
    required String oldTeikerId,
    required String newTeikerId,
  }) async {
    final snapshot = await _workSessionsRef
        .where('teikerId', isEqualTo: oldTeikerId)
        .get();
    if (snapshot.docs.isEmpty) return;

    var batch = FirebaseFirestore.instance.batch();
    var pending = 0;

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'teikerId': newTeikerId});
      pending++;
      if (pending >= 450) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        pending = 0;
      }
    }

    if (pending > 0) {
      await batch.commit();
    }
  }

  Future<bool> _ensureTeikerProfileByUidOrEmail({
    required String uid,
    required String normalizedEmail,
  }) async {
    final uidRef = _teikersRef.doc(uid);
    final uidDoc = await uidRef.get();

    if (uidDoc.exists) {
      final currentEmail = (uidDoc.data()?['email'] as String?)
          ?.trim()
          .toLowerCase();
      if (currentEmail != normalizedEmail) {
        await uidRef.set({'email': normalizedEmail}, SetOptions(merge: true));
      }
      return true;
    }

    final legacyDoc = await _findTeikerByEmail(normalizedEmail);
    if (legacyDoc == null) {
      return false;
    }

    final legacyId = legacyDoc.id;
    final legacyData = Map<String, dynamic>.from(legacyDoc.data());
    legacyData['email'] = normalizedEmail;
    await uidRef.set(legacyData, SetOptions(merge: true));

    if (legacyId != uid) {
      try {
        await _migrateClienteTeikerIds(oldTeikerId: legacyId, newTeikerId: uid);
        await _migrateWorkSessionsTeikerId(
          oldTeikerId: legacyId,
          newTeikerId: uid,
        );
        await legacyDoc.reference.set({
          'migratedToUid': uid,
          'migratedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Falha parcial na migracao de UID da teiker: $e');
      }
    }

    return true;
  }

  Future<String> _mapLoginErrorMessage({
    required String code,
    required String email,
    String? fallbackMessage,
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
      case 'network-request-failed':
        return 'Falha de ligacao ao Firebase (rede/firewall/VPN). Tenta novamente.';
      case 'operation-not-allowed':
        return 'Login com email/password nao esta ativo no Firebase.';
      case 'invalid-api-key':
      case 'app-not-authorized':
        return 'Aplicacao nao autorizada no Firebase para este bundle ID.';
      case 'internal-error':
        return 'Erro interno de autenticacao. Tenta novamente em alguns segundos.';
      case 'invalid-user':
        return 'Conta inválida.';
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
        final raw = (fallbackMessage ?? '').trim();
        if (raw.isNotEmpty) {
          return raw;
        }
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
      final credential = await _firebase.auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      if (!isAdminEmail(credential.user?.email)) {
        final user = credential.user;
        if (user == null) {
          await _firebase.auth.signOut();
          throw FirebaseAuthException(
            code: 'invalid-user',
            message: 'Conta inválida.',
          );
        }
        final ensured = await _ensureTeikerProfileByUidOrEmail(
          uid: user.uid,
          normalizedEmail: normalizedEmail,
        );
        if (!ensured) {
          await _firebase.auth.signOut();
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'Conta nao existente.',
          );
        }
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Login falhou no FirebaseAuth [${e.code}] ${e.message ?? ''}');
      final mappedMessage = await _mapLoginErrorMessage(
        code: e.code,
        email: normalizedEmail,
        fallbackMessage: e.message,
      );
      throw FirebaseAuthException(code: e.code, message: mappedMessage);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
          'Conta autenticada, mas sem permissao para aceder ao perfil. Contacta a administracao.',
        );
      }
      final message = e.message?.trim();
      throw Exception(
        message == null || message.isEmpty
            ? 'Falha ao validar perfil no Firestore.'
            : message,
      );
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
    return _teikerAgendaRepository.getFeriasTeikers();
  }

  Future<List<Map<String, dynamic>>> getBaixasTeikers() async {
    return _teikerAgendaRepository.getBaixasTeikers();
  }

  Future<List<Map<String, dynamic>>> getConsultasTeikers() async {
    return _teikerAgendaRepository.getConsultasTeikers();
  }

  Future<void> createCliente(Clientes cliente) async {
    await _clienteRepository.createCliente(cliente);
  }

  Future<void> updateCliente(Clientes cliente) async {
    await _clienteRepository.updateCliente(cliente);
  }

  Future<List<Clientes>> getClientes({
    bool includeArchived = false,
    bool onlyArchived = false,
  }) async {
    return _clienteRepository.getClientes(
      includeArchived: includeArchived,
      onlyArchived: onlyArchived,
    );
  }

  Future<void> archiveClientes(
    List<String> clienteIds, {
    required String archivedBy,
  }) async {
    await _clienteRepository.archiveClientes(
      clienteIds,
      archivedBy: archivedBy,
    );
  }

  Future<void> unarchiveClientes(List<String> clienteIds) async {
    await _clienteRepository.unarchiveClientes(clienteIds);
  }

  Future<void> deleteClientes(List<String> clienteIds) async {
    await _clienteRepository.deleteClientes(clienteIds);
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

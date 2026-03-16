import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:teiker_app/models/teiker_document.dart';
import 'package:url_launcher/url_launcher.dart';

class TeikerDocumentService {
  TeikerDocumentService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _documentsCollection(
    String teikerId,
  ) {
    return _firestore
        .collection('teikers')
        .doc(teikerId)
        .collection('documents');
  }

  Stream<List<TeikerDocument>> watchTeikerDocuments(String teikerId) {
    final safeTeikerId = teikerId.trim();
    if (safeTeikerId.isEmpty) {
      return Stream.value(const <TeikerDocument>[]);
    }

    return _documentsCollection(safeTeikerId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TeikerDocument.fromMap(id: doc.id, map: doc.data()))
              .toList(),
        );
  }

  Future<TeikerDocument> uploadDocument({
    required String teikerId,
    required File file,
    String? uploadedById,
    String? uploadedByName,
  }) async {
    final safeTeikerId = teikerId.trim();
    if (safeTeikerId.isEmpty) {
      throw Exception('Teiker inválida.');
    }
    if (!file.existsSync()) {
      throw Exception('Ficheiro não encontrado.');
    }

    final rawFileName = p.basename(file.path).trim();
    if (rawFileName.isEmpty) {
      throw Exception('Nome de ficheiro inválido.');
    }

    final docRef = _documentsCollection(safeTeikerId).doc();
    final safeFileName = _sanitizeFileName(rawFileName);
    final storagePath =
        'teiker_documents/$safeTeikerId/${docRef.id}_${DateTime.now().millisecondsSinceEpoch}_$safeFileName';
    final storageRef = _storage.ref().child(storagePath);

    try {
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();
      final now = DateTime.now();
      final currentUser = _auth.currentUser;

      final document = TeikerDocument(
        id: docRef.id,
        teikerId: safeTeikerId,
        fileName: rawFileName,
        downloadUrl: downloadUrl,
        storagePath: storagePath,
        sizeBytes: await file.length(),
        uploadedAt: now,
        uploadedById: uploadedById?.trim().isNotEmpty == true
            ? uploadedById!.trim()
            : (currentUser?.uid ?? ''),
        uploadedByName: uploadedByName?.trim().isNotEmpty == true
            ? uploadedByName!.trim()
            : _fallbackUploaderName(currentUser),
      );

      await docRef.set(document.toMap());
      return document;
    } on FirebaseException catch (e) {
      final code = e.code.trim();
      if (code == 'permission-denied' || code == 'unauthorized') {
        throw Exception(
          'Sem permissao no Firebase Storage. As regras de Storage precisam de permitir upload/leitura para esta conta.',
        );
      }
      throw Exception('Firebase ${e.plugin}/${e.code}: ${e.message ?? 'erro'}');
    }
  }

  Future<void> deleteDocument({
    required String teikerId,
    required TeikerDocument document,
  }) async {
    final safeTeikerId = teikerId.trim();
    if (safeTeikerId.isEmpty) {
      throw Exception('Teiker inválida.');
    }

    final safeDocId = document.id.trim();
    if (safeDocId.isEmpty) return;

    await _documentsCollection(safeTeikerId).doc(safeDocId).delete();

    final storagePath = document.storagePath.trim();
    if (storagePath.isEmpty) return;

    try {
      await _storage.ref().child(storagePath).delete();
    } catch (_) {
      // Ignore storage cleanup failures after metadata deletion.
    }
  }

  Future<void> openDocument(TeikerDocument document) async {
    final rawUrl = document.downloadUrl.trim();
    if (rawUrl.isEmpty) {
      throw Exception('URL do documento inválida.');
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      throw Exception('URL do documento inválida.');
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw Exception('Não foi possível abrir o documento.');
    }
  }

  String _fallbackUploaderName(User? user) {
    final displayName = user?.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) return displayName;

    final email = user?.email?.trim() ?? '';
    if (email.isNotEmpty) return email;

    return 'Admin';
  }

  String _sanitizeFileName(String fileName) {
    final cleaned = fileName
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9._\-]'), '');
    if (cleaned.isEmpty) return 'documento';
    return cleaned;
  }
}

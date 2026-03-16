import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Widgets/AppBar.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/backend/firebase_service.dart';
import 'package:teiker_app/backend/teiker_document_service.dart';
import 'package:teiker_app/models/teiker_document.dart';
import 'package:teiker_app/theme/app_colors.dart';

class TeikerDocumentsScreen extends StatefulWidget {
  const TeikerDocumentsScreen({super.key});

  @override
  State<TeikerDocumentsScreen> createState() => _TeikerDocumentsScreenState();
}

class _TeikerDocumentsScreenState extends State<TeikerDocumentsScreen> {
  final TeikerDocumentService _documentService = TeikerDocumentService();
  final Set<String> _openingDocumentIds = <String>{};

  Future<void> _openDocument(TeikerDocument document) async {
    if (_openingDocumentIds.contains(document.id)) return;

    setState(() => _openingDocumentIds.add(document.id));
    try {
      await _documentService.openDocument(document);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Não foi possível abrir o documento: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    } finally {
      if (mounted) {
        setState(() => _openingDocumentIds.remove(document.id));
      }
    }
  }

  String _formatFileSize(int sizeBytes) {
    if (sizeBytes <= 0) return '0 B';
    if (sizeBytes < 1024) return '$sizeBytes B';

    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';

    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';

    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final userId = (FirebaseService().currentUser?.uid ?? '').trim();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: buildAppBar('Documentos', seta: true),
      body: userId.isEmpty
          ? const Center(
              child: Text(
                'Sem sessão ativa.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : StreamBuilder<List<TeikerDocument>>(
              stream: _documentService.watchTeikerDocuments(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Não foi possível carregar os documentos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }

                final documents = snapshot.data ?? const <TeikerDocument>[];
                if (documents.isEmpty) {
                  return Center(
                    child: Text(
                      'Ainda não tens documentos disponíveis.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }

                final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_PT');

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    final isOpening = _openingDocumentIds.contains(document.id);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primaryGreen.withValues(alpha: .14),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(
                          12,
                          10,
                          12,
                          10,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryGreen.withValues(
                            alpha: .12,
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        title: Text(
                          document.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${dateFormat.format(document.uploadedAt)} • ${_formatFileSize(document.sizeBytes)}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        trailing: isOpening
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                tooltip: 'Abrir / Transferir',
                                icon: const Icon(
                                  Icons.download_rounded,
                                  color: AppColors.primaryGreen,
                                ),
                                onPressed: () => _openDocument(document),
                              ),
                        onTap: () => _openDocument(document),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: documents.length,
                );
              },
            ),
    );
  }
}

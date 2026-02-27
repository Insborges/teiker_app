import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReunioesTemplateService {
  static const String _templateAssetPath = 'Template_Reunioes.docx';

  Future<File> buildTemplate({
    required String nomeTeiker,
    required String nota,
    required String quemEscreveuNota,
    required DateTime dataHora,
    String? tipoMarcacao,
  }) async {
    final templateData = await rootBundle.load(_templateAssetPath);
    final templateBytes = templateData.buffer.asUint8List();

    final archive = ZipDecoder().decodeBytes(templateBytes, verify: false);
    final documentFile = archive.findFile('word/document.xml');
    if (documentFile == null) {
      throw Exception('Template de reuniões inválido (document.xml em falta).');
    }

    var xml = utf8.decode(documentFile.content);

    xml = _replaceBookmarkField(
      xml,
      bookmarkName: 'nome_teiker',
      value: nomeTeiker.trim(),
    );
    xml = _replaceBookmarkField(xml, bookmarkName: 'nota', value: nota.trim());
    xml = _replaceBookmarkField(
      xml,
      bookmarkName: 'quem_escreveu_a_nota',
      value: quemEscreveuNota.trim(),
    );
    xml = _replaceBookmarkField(
      xml,
      bookmarkName: 'data_e_hora',
      value: DateFormat('dd/MM/yyyy HH:mm', 'pt_PT').format(dataHora),
    );

    archive.addFile(ArchiveFile.string(documentFile.name, xml));
    final encodedArchive = ZipEncoder().encode(archive);

    final tempDir = await getTemporaryDirectory();
    final safeTeiker = _sanitizeFilePart(nomeTeiker);
    final safeTipo = _sanitizeFilePart(tipoMarcacao ?? 'marcacao');
    final stamp = DateFormat('yyyyMMdd_HHmm').format(dataHora);
    final fileName = 'anotacao_${safeTipo}_${safeTeiker}_$stamp.docx';
    final output = File(p.join(tempDir.path, fileName));
    await output.writeAsBytes(encodedArchive, flush: true);
    return output;
  }

  Future<void> shareTemplate({
    required String nomeTeiker,
    required String nota,
    required String quemEscreveuNota,
    required DateTime dataHora,
    String? tipoMarcacao,
    Rect? sharePositionOrigin,
  }) async {
    final file = await buildTemplate(
      nomeTeiker: nomeTeiker,
      nota: nota,
      quemEscreveuNota: quemEscreveuNota,
      dataHora: dataHora,
      tipoMarcacao: tipoMarcacao,
    );

    final shareText = 'Anotação de ${tipoMarcacao ?? 'marcação'}';
    final subject = 'Anotação ${tipoMarcacao ?? 'marcação'}';
    final xFile = XFile(
      file.path,
      mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      name: p.basename(file.path),
    );

    try {
      await Share.shareXFiles(
        [xFile],
        text: shareText,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      );
      return;
    } on PlatformException {
      // Fallback for some iOS/iPad/macOS share sheet combinations that fail
      // when an XML mime type or name override is provided.
      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      );
    }
  }

  String _replaceBookmarkField(
    String xml, {
    required String bookmarkName,
    required String value,
  }) {
    final bookmarkPattern = RegExp(
      '(<w:bookmarkStart[^>]*w:name="${RegExp.escape(bookmarkName)}"[^>]*/?>)(.*?)(<w:bookmarkEnd[^>]*/>)',
      dotAll: true,
    );

    return xml.replaceFirstMapped(bookmarkPattern, (match) {
      final prefix = match.group(1)!;
      final segment = match.group(2)!;
      final suffix = match.group(3)!;

      var replaced = false;
      final updatedSegment = segment.replaceAllMapped(
        RegExp(r'<w:t[^>]*>.*?</w:t>', dotAll: true),
        (textMatch) {
          if (replaced) return '<w:t></w:t>';
          replaced = true;
          return '<w:t>${_escapeXml(value)}</w:t>';
        },
      );

      return '$prefix$updatedSegment$suffix';
    });
  }

  String _sanitizeFilePart(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '');
    return cleaned.isEmpty ? 'documento' : cleaned;
  }

  String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

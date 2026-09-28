import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:teiker_app/models/client_invoice.dart';

class InvoiceDocxService {
  static const String _templateAssetPath = 'Invoice(Fatura)_Teiker.docx';
  static final RegExp _tablePattern = RegExp(r'<w:tbl\b[^>]*>[\s\S]*?</w:tbl>');
  static final RegExp _rowPattern = RegExp(r'<w:tr\b[^>]*>[\s\S]*?</w:tr>');
  static const double _minLineAmount = 0.0001;

  Future<File> buildInvoiceDocument(ClientInvoice invoice) async {
    final templateData = await rootBundle.load(_templateAssetPath);
    final templateBytes = templateData.buffer.asUint8List();

    final archive = ZipDecoder().decodeBytes(templateBytes, verify: false);
    final documentFile = archive.findFile('word/document.xml');
    if (documentFile == null) {
      throw Exception('Template de fatura invalido (document.xml em falta).');
    }

    final originalXml = utf8.decode(documentFile.content);
    final updatedXml = _applyInvoiceData(originalXml, invoice);
    archive.addFile(ArchiveFile.string(documentFile.name, updatedXml));

    final relsFile = archive.findFile('word/_rels/document.xml.rels');
    if (relsFile != null) {
      final relsXml = utf8.decode(relsFile.content);
      final updatedRels = _applyEmailToRels(relsXml);
      archive.addFile(ArchiveFile.string(relsFile.name, updatedRels));
    }

    final encodedArchive = ZipEncoder().encode(archive);

    final tempDir = await getApplicationDocumentsDirectory();
    final safeInvoiceNumber = _sanitizeFilePart(invoice.invoiceNumber);
    final safeClientName = _sanitizeFilePart(invoice.clientName);
    final fileName = 'Invoice_${safeClientName}_$safeInvoiceNumber.docx';
    final outputPath = p.join(tempDir.path, fileName);
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(encodedArchive, flush: true);
    return outputFile;
  }

  String _applyInvoiceData(String xml, ClientInvoice invoice) {
    var updated = xml;

    updated = updated.replaceAll(
      'invoice_date',
      _escapeXml(DateFormat('dd/MM/yyyy').format(invoice.invoiceDate)),
    );
    updated = updated.replaceAll(
      'invoice_number',
      _escapeXml(invoice.invoiceNumber),
    );
    updated = updated.replaceAll('client_name', _escapeXml(invoice.clientName));
    updated = updated.replaceAll(
      'client_address',
      _escapeXml(invoice.clientAddress),
    );
    updated = updated.replaceAll(
      'client_postal_code',
      _escapeXml(invoice.clientPostalCode),
    );
    updated = updated.replaceAll('client_city', _escapeXml(invoice.clientCity));

    updated = _replaceStaticIssuerName(updated);
    updated = _updateMainInvoiceTable(updated, (tableXml) {
      var nextTable = tableXml;
      nextTable = _replaceServiceRowsInTable(nextTable, invoice);
      nextTable = _replaceVatAndTotalRowsInTable(nextTable, invoice);
      return nextTable;
    });
    updated = _replaceFirstEmailText(updated, 'info@teiker.ch');

    return updated;
  }

  String _updateMainInvoiceTable(
    String xml,
    String Function(String tableXml) updateTable,
  ) {
    final tableMatches = _tablePattern.allMatches(xml).toList();
    for (final tableMatch in tableMatches) {
      final tableXml = tableMatch.group(0)!;
      if (!_isInvoiceTable(tableXml)) continue;

      final updatedTable = updateTable(tableXml);
      return xml.replaceRange(tableMatch.start, tableMatch.end, updatedTable);
    }
    throw const FormatException('Template de fatura: tabela em falta.');
  }

  static final RegExp _cellPattern = RegExp(r'<w:tc\b[^>]*>[\s\S]*?</w:tc>');
  static final RegExp _textPattern = RegExp(r'<w:t\b[^>]*>([\s\S]*?)</w:t>');

  // Word may split the same visible text across any number of formatted runs.
  String _visibleText(String xml) => _textPattern
      .allMatches(xml)
      .map((match) => match.group(1)!)
      .join()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<String> _cellTexts(String row) => _cellPattern
      .allMatches(row)
      .map((match) => _visibleText(match.group(0)!))
      .toList();

  bool _isInvoiceTable(String tableXml) {
    final header = _rowPattern.firstMatch(tableXml);
    if (header == null) return false;
    final cells = _cellTexts(header.group(0)!);
    return cells.length == 4 &&
        cells[0] == 'Description' &&
        cells[1] == 'Unit' &&
        cells[2] == 'Price Per Hour' &&
        cells[3] == 'Total';
  }

  String _replaceServiceRowsInTable(String tableXml, ClientInvoice invoice) {
    final rows = _rowPattern.allMatches(tableXml).toList();
    final vatIndex = rows.indexWhere((row) => _isVatRow(row.group(0)!));
    if (vatIndex < 2 || _cellTexts(rows[1].group(0)!).length != 4) {
      throw const FormatException(
        'Template de fatura: linha de servico em falta.',
      );
    }
    return tableXml.replaceRange(
      rows[1].start,
      rows[vatIndex].start,
      _buildInvoiceLineRows(rows[1].group(0)!, invoice),
    );
  }

  String _replaceVatAndTotalRowsInTable(
    String tableXml,
    ClientInvoice invoice,
  ) {
    var foundVat = false;
    var foundTotal = false;
    final updated = tableXml.replaceAllMapped(_rowPattern, (match) {
      final row = match.group(0)!;
      if (_isVatRow(row)) {
        foundVat = true;
        return _replaceCells(row, [
          'TVA ${(invoice.vatRate * 100).toStringAsFixed(1)}%',
          _formatMoney(invoice.vatAmount),
        ]);
      }
      final cells = _cellTexts(row);
      if (cells.length == 2 && cells.first == 'Total') {
        foundTotal = true;
        return _replaceCells(row, ['Total', _formatMoney(invoice.total)]);
      }
      return row;
    });
    if (!foundVat || !foundTotal) {
      throw const FormatException('Template de fatura: IVA ou total em falta.');
    }
    return updated;
  }

  bool _isVatRow(String row) {
    final cells = _cellTexts(row);
    return cells.length == 2 && cells.first.startsWith('TVA ');
  }

  String _replaceCells(String row, List<String> values) {
    if (_cellPattern.allMatches(row).length != values.length) {
      throw const FormatException('Template de fatura: colunas invalidas.');
    }
    var index = 0;
    return row.replaceAllMapped(_cellPattern, (match) {
      final value = _escapeXml(values[index++]);
      var written = false;
      final cell = match.group(0)!.replaceAllMapped(_textPattern, (text) {
        if (written) return '<w:t></w:t>';
        written = true;
        return '<w:t xml:space="preserve">$value</w:t>';
      });
      if (!written) {
        throw const FormatException('Template de fatura: celula sem texto.');
      }
      return cell;
    });
  }

  String _buildInvoiceLineRows(String templateRow, ClientInvoice invoice) {
    final lines = <_InvoiceTableLine>[];
    if (invoice.totalHours > _minLineAmount &&
        invoice.subtotal > _minLineAmount) {
      lines.add(
        _InvoiceTableLine(
          description:
              'Services ${_capitalizedMonth(DateTime.tryParse('${invoice.periodMonthKey}-01') ?? invoice.invoiceDate)} Teiker',
          unitsText: '${invoice.totalHours.toStringAsFixed(1)}h',
          unitPrice: invoice.hourlyRate,
          total: invoice.subtotal,
        ),
      );
    }
    lines.addAll(_buildAdditionalServiceLines(invoice));

    return lines.map((line) => _buildRowFromTemplate(templateRow, line)).join();
  }

  List<_InvoiceTableLine> _buildAdditionalServiceLines(ClientInvoice invoice) {
    final entries = invoice.additionalServices.entries.toList()
      ..removeWhere(
        (entry) => !entry.value.isFinite || entry.value <= _minLineAmount,
      )
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return entries.map((entry) {
      final normalized = _normalizeAdditionalServiceEntry(
        entry.key,
        entry.value,
      );
      return _InvoiceTableLine(
        description: normalized.name,
        unitsText: normalized.quantity.toString(),
        unitPrice: normalized.unitPrice,
        total: normalized.total,
        hideUnitAndRate: true,
      );
    }).toList();
  }

  _AdditionalServiceEntry _normalizeAdditionalServiceEntry(
    String rawName,
    double rawTotal,
  ) {
    var name = rawName.trim();
    var quantity = 1;

    final endQuantityPattern = RegExp(r'^(.*?)[xX]\s*(\d+)$');
    final endQuantityMatch = endQuantityPattern.firstMatch(name);
    if (endQuantityMatch != null) {
      name = (endQuantityMatch.group(1) ?? '').trim();
      quantity = int.tryParse(endQuantityMatch.group(2) ?? '') ?? 1;
    } else {
      final parenthesisPattern = RegExp(r'^(.*?)\((\d+)\s*[xX]\)$');
      final parenthesisMatch = parenthesisPattern.firstMatch(name);
      if (parenthesisMatch != null) {
        name = (parenthesisMatch.group(1) ?? '').trim();
        quantity = int.tryParse(parenthesisMatch.group(2) ?? '') ?? 1;
      }
    }

    if (name.isEmpty) {
      name = rawName.trim().isEmpty ? 'Additional Service' : rawName.trim();
    }
    if (quantity <= 0) quantity = 1;

    final total = rawTotal;
    final unitPrice = total / quantity;

    return _AdditionalServiceEntry(
      name: name,
      quantity: quantity,
      unitPrice: unitPrice,
      total: total,
    );
  }

  String _buildRowFromTemplate(String templateRow, _InvoiceTableLine line) {
    return _replaceCells(templateRow, [
      line.description,
      line.hideUnitAndRate ? '' : line.unitsText,
      line.hideUnitAndRate ? '' : _formatMoney(line.unitPrice),
      _formatMoney(line.total),
    ]);
  }

  String _capitalizedMonth(DateTime date) {
    final month = DateFormat('MMMM', 'en_US').format(date).trim();
    if (month.isEmpty) return '';
    return '${month[0].toUpperCase()}${month.substring(1)}';
  }

  String _replaceFirstEmailText(String xml, String email) {
    return xml.replaceFirstMapped(
      RegExp(r'(<w:t[^>]*>)[^<]*@[^<]*(</w:t>)'),
      (match) => '${match.group(1)}${_escapeXml(email)}${match.group(2)}',
    );
  }

  String _replaceStaticIssuerName(String xml) {
    var updated = xml.replaceFirstMapped(
      RegExp(r'(<w:t[^>]*>)Sonia(</w:t>)'),
      (match) => '${match.group(1)}Teiker${match.group(2)}',
    );

    updated = updated.replaceFirstMapped(
      RegExp(r'(<w:t[^>]*xml:space="preserve">)\s*Pereira(</w:t>)'),
      (match) => '${match.group(1)}${match.group(2)}',
    );

    return updated;
  }

  String _applyEmailToRels(String xml) {
    var updated = xml;
    updated = updated.replaceAll(
      RegExp(r'mailto:[^" ]+'),
      'mailto:info@teiker.ch',
    );
    updated = updated.replaceAll(
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
      'info@teiker.ch',
    );
    return updated;
  }

  String _formatMoney(double value) => '${value.toStringAsFixed(2)} CHF';

  String _sanitizeFilePart(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '');
    if (cleaned.isEmpty) {
      return 'documento';
    }
    return cleaned;
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

class _InvoiceTableLine {
  const _InvoiceTableLine({
    required this.description,
    required this.unitsText,
    required this.unitPrice,
    required this.total,
    this.hideUnitAndRate = false,
  });

  final String description;
  final String unitsText;
  final double unitPrice;
  final double total;
  final bool hideUnitAndRate;
}

class _AdditionalServiceEntry {
  const _AdditionalServiceEntry({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final double total;
}

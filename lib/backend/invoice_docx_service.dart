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

    final tempDir = await getTemporaryDirectory();
    final safeInvoiceNumber = _sanitizeFilePart(invoice.invoiceNumber);
    final safeClientName = _sanitizeFilePart(invoice.clientName);
    final fileName = 'fatura_${safeClientName}_$safeInvoiceNumber.docx';
    final outputPath = p.join(tempDir.path, fileName);
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(encodedArchive, flush: true);
    return outputFile;
  }

  String _applyInvoiceData(String xml, ClientInvoice invoice) {
    var updated = xml;

    updated = _replaceBookmarkField(
      updated,
      bookmarkName: 'invoice_date',
      value: DateFormat('dd/MM/yyyy').format(invoice.invoiceDate),
    );
    updated = _replaceBookmarkField(
      updated,
      bookmarkName: 'invoice_number',
      value: invoice.invoiceNumber,
    );
    updated = _replaceBookmarkField(
      updated,
      bookmarkName: 'client_name',
      value: invoice.clientName,
    );
    updated = _replaceBookmarkField(
      updated,
      bookmarkName: 'client_address',
      value: invoice.clientAddress,
    );
    updated = _replaceBookmarkField(
      updated,
      bookmarkName: 'client_postal_code',
      value: invoice.clientPostalCode,
    );
    updated = _replaceBookmarkField(
      updated,
      bookmarkName: 'client_city',
      value: invoice.clientCity,
    );

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
    return xml;
  }

  bool _isInvoiceTable(String tableXml) {
    return tableXml.contains('<w:t>Description</w:t>') &&
        tableXml.contains('<w:t>Unit</w:t>') &&
        tableXml.contains('Price Per') &&
        tableXml.contains('<w:t>Hour</w:t>') &&
        tableXml.contains('TVA 8.1%');
  }

  String _replaceServiceRowsInTable(String tableXml, ClientInvoice invoice) {
    final rowMatches = _rowPattern.allMatches(tableXml).toList();
    if (rowMatches.isEmpty) {
      return tableXml;
    }

    var serviceRowIndex = -1;
    for (var index = 0; index < rowMatches.length; index++) {
      if (_isServiceTemplateRow(rowMatches[index].group(0)!)) {
        serviceRowIndex = index;
        break;
      }
    }
    if (serviceRowIndex < 0) {
      return tableXml;
    }

    var vatRowIndex = -1;
    for (var index = serviceRowIndex + 1; index < rowMatches.length; index++) {
      if (_isVatRow(rowMatches[index].group(0)!)) {
        vatRowIndex = index;
        break;
      }
    }
    if (vatRowIndex < 0) {
      return tableXml;
    }

    final serviceRowMatch = rowMatches[serviceRowIndex];
    final vatRowMatch = rowMatches[vatRowIndex];
    final templateRow = serviceRowMatch.group(0)!;
    final rows = _buildInvoiceLineRows(templateRow, invoice);

    return tableXml.replaceRange(
      serviceRowMatch.start,
      vatRowMatch.start,
      rows,
    );
  }

  String _replaceVatAndTotalRowsInTable(
    String tableXml,
    ClientInvoice invoice,
  ) {
    var updated = tableXml;

    final vatRows = _rowPattern.allMatches(updated).toList();
    var vatRowIndex = -1;
    for (var index = 0; index < vatRows.length; index++) {
      if (_isVatRow(vatRows[index].group(0)!)) {
        vatRowIndex = index;
        break;
      }
    }
    if (vatRowIndex >= 0) {
      final vatMatch = vatRows[vatRowIndex];
      var vatRow = vatMatch.group(0)!;
      vatRow = _replaceTextNode(
        vatRow,
        oldValue: 'TVA 8.1%',
        newValue: 'TVA ${(invoice.vatRate * 100).toStringAsFixed(1)}%',
      );
      vatRow = _replaceTextNode(
        vatRow,
        oldValue: 'CHF',
        newValue: _formatMoney(invoice.vatAmount),
      );
      updated = updated.replaceRange(vatMatch.start, vatMatch.end, vatRow);
    }

    final totalRows = _rowPattern.allMatches(updated).toList();
    var totalRowIndex = -1;
    if (vatRowIndex >= 0) {
      for (var index = vatRowIndex + 1; index < totalRows.length; index++) {
        if (_isGrandTotalRow(totalRows[index].group(0)!)) {
          totalRowIndex = index;
          break;
        }
      }
    } else {
      for (var index = 0; index < totalRows.length; index++) {
        if (_isGrandTotalRow(totalRows[index].group(0)!)) {
          totalRowIndex = index;
          break;
        }
      }
    }

    if (totalRowIndex >= 0) {
      final totalMatch = totalRows[totalRowIndex];
      var totalRow = totalMatch.group(0)!;
      totalRow = _replaceTextNode(
        totalRow,
        oldValue: 'CHF',
        newValue: _formatMoney(invoice.total),
      );
      updated = updated.replaceRange(
        totalMatch.start,
        totalMatch.end,
        totalRow,
      );
    }

    return updated;
  }

  bool _isServiceTemplateRow(String rowXml) {
    return rowXml.contains('<w:t>Cleaning</w:t>') &&
        rowXml.contains('<w:t>Service</w:t>') &&
        rowXml.contains('<w:t>August</w:t>') &&
        rowXml.contains('<w:t>Hours</w:t>') &&
        rowXml.contains('<w:t>49 CHF</w:t>');
  }

  bool _isVatRow(String rowXml) {
    return rowXml.contains('TVA ');
  }

  bool _isGrandTotalRow(String rowXml) {
    return rowXml.contains('<w:t>Total</w:t>') &&
        rowXml.contains('<w:t>CHF</w:t>') &&
        !rowXml.contains('<w:t>Description</w:t>');
  }

  String _buildInvoiceLineRows(String templateRow, ClientInvoice invoice) {
    final lines = <_InvoiceTableLine>[
      _InvoiceTableLine(
        description:
            'Servicos ${_capitalizedMonth(invoice.invoiceDate)} Teiker',
        unitsText: '${invoice.totalHours.toStringAsFixed(1)}h',
        unitPrice: invoice.hourlyRate,
        total: invoice.subtotal,
      ),
      ..._buildAdditionalServiceLines(invoice),
    ];

    return lines.map((line) => _buildRowFromTemplate(templateRow, line)).join();
  }

  List<_InvoiceTableLine> _buildAdditionalServiceLines(ClientInvoice invoice) {
    final entries = invoice.additionalServices.entries.toList()
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
      name = rawName.trim().isEmpty ? 'Servico adicional' : rawName.trim();
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
    var row = templateRow;
    final descriptionParts = _splitDescription(line.description);

    row = _replaceTextNode(
      row,
      oldValue: 'Cleaning',
      newValue: descriptionParts.$1,
    );
    row = _replaceTextNode(
      row,
      oldValue: 'Service',
      newValue: descriptionParts.$2,
    );
    row = _replaceTextNode(
      row,
      oldValue: 'August',
      newValue: descriptionParts.$3,
    );
    row = _replaceTextNode(row, oldValue: 'Hours', newValue: line.unitsText);
    row = _replaceTextNode(
      row,
      oldValue: '49 CHF',
      newValue: _formatMoney(line.unitPrice),
    );
    row = _replaceTextNode(
      row,
      oldValue: 'CHF',
      newValue: _formatMoney(line.total),
    );

    return row;
  }

  (String, String, String) _splitDescription(String description) {
    final words = description
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();

    if (words.isEmpty) return ('', '', '');
    if (words.length == 1) return (words.first, '', '');
    if (words.length == 2) return (words[0], words[1], '');
    return (words[0], words[1], words.sublist(2).join(' '));
  }

  String _capitalizedMonth(DateTime date) {
    final month = DateFormat('MMMM', 'pt_PT').format(date).trim();
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

      var hasReplacedValue = false;
      final updatedSegment = segment.replaceAllMapped(
        RegExp(r'<w:t[^>]*>.*?</w:t>', dotAll: true),
        (textMatch) {
          if (hasReplacedValue) {
            return '<w:t></w:t>';
          }
          hasReplacedValue = true;
          return '<w:t>${_escapeXml(value)}</w:t>';
        },
      );

      return '$prefix$updatedSegment$suffix';
    });
  }

  String _replaceTextNode(
    String xml, {
    required String oldValue,
    required String newValue,
    int occurrence = 1,
  }) {
    var currentOccurrence = 0;
    final pattern = RegExp(
      '<w:t([^>]*)>${RegExp.escape(oldValue)}</w:t>',
      dotAll: true,
    );

    return xml.replaceAllMapped(pattern, (match) {
      currentOccurrence += 1;
      if (currentOccurrence != occurrence) {
        return match.group(0)!;
      }

      final attrs = match.group(1) ?? '';
      return '<w:t$attrs>${_escapeXml(newValue)}</w:t>';
    });
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
  });

  final String description;
  final String unitsText;
  final double unitPrice;
  final double total;
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

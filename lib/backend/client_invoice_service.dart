import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:teiker_app/backend/invoice_docx_service.dart';
import 'package:teiker_app/models/Clientes.dart';
import 'package:teiker_app/models/client_invoice.dart';
import 'package:teiker_app/work_sessions/domain/fixed_holiday_hours_policy.dart';

enum InvoiceContentFilter { both, hoursOnly, servicesOnly }

class IssuedClientInvoice {
  const IssuedClientInvoice({
    required this.invoice,
    required this.documentFile,
  });

  final ClientInvoice invoice;
  final File documentFile;
}

class ClientInvoiceService {
  ClientInvoiceService({
    FirebaseFirestore? firestore,
    InvoiceDocxService? docxService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _docxService = docxService ?? InvoiceDocxService();

  static const double _defaultVatRate = 0.081;
  static const double _minBillableAmount = 0.0001;

  final FirebaseFirestore _firestore;
  final InvoiceDocxService _docxService;

  CollectionReference<Map<String, dynamic>> _clientInvoicesCollection(
    String clientId,
  ) {
    return _firestore
        .collection('clientes')
        .doc(clientId)
        .collection('invoices');
  }

  Stream<List<ClientInvoice>> watchClientInvoices(String clientId) {
    return _clientInvoicesCollection(clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ClientInvoice.fromMap(id: doc.id, map: doc.data()))
              .toList(),
        );
  }

  Future<void> deleteInvoice({
    required String clientId,
    required String invoiceId,
  }) async {
    final safeClientId = clientId.trim();
    final safeInvoiceId = invoiceId.trim();
    if (safeClientId.isEmpty || safeInvoiceId.isEmpty) {
      throw Exception('Fatura invalida.');
    }

    await _clientInvoicesCollection(safeClientId).doc(safeInvoiceId).delete();
  }

  Future<IssuedClientInvoice> issueInvoice({
    required Clientes cliente,
    required DateTime invoiceDate,
    InvoiceContentFilter contentFilter = InvoiceContentFilter.both,
  }) async {
    final clientId = cliente.uid.trim();
    if (clientId.isEmpty) {
      throw Exception('Cliente invalido.');
    }

    final normalizedDate = DateTime(
      invoiceDate.year,
      invoiceDate.month,
      invoiceDate.day,
    );
    final monthKey = _monthKey(normalizedDate);
    final monthLabel = DateFormat('MMMM yyyy', 'pt_PT').format(normalizedDate);

    final includeHours = contentFilter != InvoiceContentFilter.servicesOnly;
    final includeServices = contentFilter != InvoiceContentFilter.hoursOnly;

    final monthlyHours = includeHours
        ? await _calculateMonthlyHours(
            clientId: clientId,
            referenceDate: normalizedDate,
          )
        : 0.0;
    final additionalServices = includeServices
        ? _sanitizeAdditionalServices(
            _servicePricesForMonth(cliente: cliente, monthKey: monthKey),
          )
        : const <String, double>{};
    final additionalServicesTotal = additionalServices.values.fold<double>(
      0,
      (runningTotal, value) => runningTotal + value,
    );
    final monthlyServiceTotal = includeHours
        ? monthlyHours * cliente.orcamento
        : 0.0;
    final hasBillableHours =
        includeHours &&
        monthlyHours > _minBillableAmount &&
        monthlyServiceTotal > _minBillableAmount;

    if (monthlyServiceTotal <= _minBillableAmount &&
        additionalServicesTotal <= _minBillableAmount) {
      switch (contentFilter) {
        case InvoiceContentFilter.hoursOnly:
          throw Exception('Nao existem horas para faturar no mes selecionado.');
        case InvoiceContentFilter.servicesOnly:
          throw Exception(
            'Nao existem servicos adicionais para faturar no mes selecionado.',
          );
        case InvoiceContentFilter.both:
          throw Exception(
            'Nao existem horas nem servicos para faturar no mes selecionado.',
          );
      }
    }

    final hourlySubtotal = hasBillableHours ? monthlyServiceTotal : 0.0;
    final vatAmount = hourlySubtotal * _defaultVatRate;
    final total = hourlySubtotal + vatAmount + additionalServicesTotal;
    final invoiceNumber = await _nextInvoiceNumber(normalizedDate);
    final now = DateTime.now();
    final documentRef = _clientInvoicesCollection(clientId).doc();
    final addressParts = _splitPostalCodeAndCity(cliente.codigoPostal);
    final explicitCity = cliente.cidadeCliente.trim();

    final invoice = ClientInvoice(
      id: documentRef.id,
      clientId: clientId,
      invoiceNumber: invoiceNumber,
      invoiceDate: normalizedDate,
      periodMonthKey: monthKey,
      periodLabel: monthLabel,
      clientName: cliente.nameCliente.trim(),
      clientAddress: cliente.moradaCliente.trim(),
      clientPostalCode: addressParts.$1,
      clientCity: explicitCity.isNotEmpty ? explicitCity : addressParts.$2,
      totalHours: hasBillableHours ? monthlyHours : 0.0,
      hourlyRate: hasBillableHours ? cliente.orcamento : 0.0,
      additionalServices: additionalServices,
      servicesTotal: additionalServicesTotal,
      subtotal: hourlySubtotal,
      vatRate: _defaultVatRate,
      vatAmount: vatAmount,
      total: total,
      createdAt: now,
    );

    final documentFile = await _docxService.buildInvoiceDocument(invoice);
    await documentRef.set(invoice.toMap());

    return IssuedClientInvoice(invoice: invoice, documentFile: documentFile);
  }

  Future<File> generateInvoiceDocument(ClientInvoice invoice) {
    return _docxService.buildInvoiceDocument(invoice);
  }

  Future<void> shareInvoiceDocument(
    ClientInvoice invoice, {
    File? preGeneratedFile,
    Rect? sharePositionOrigin,
  }) async {
    final documentFile =
        preGeneratedFile ?? await _docxService.buildInvoiceDocument(invoice);
    final shareText = 'Fatura ${invoice.invoiceNumber} - ${invoice.clientName}';
    final shareSubject = 'Fatura ${invoice.invoiceNumber}';
    final xFile = XFile(
      documentFile.path,
      mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      name: p.basename(documentFile.path),
    );

    try {
      await Share.shareXFiles(
        [xFile],
        text: shareText,
        subject: shareSubject,
        sharePositionOrigin: sharePositionOrigin,
      );
      return;
    } on PlatformException {
      // Fallback for some iOS/iPad/macOS share sheet combinations that fail
      // when an XML mime type or name override is provided.
      await Share.shareXFiles(
        [XFile(documentFile.path)],
        text: shareText,
        subject: shareSubject,
        sharePositionOrigin: sharePositionOrigin,
      );
    }
  }

  Future<void> openInvoiceDocumentInWord(
    ClientInvoice invoice, {
    File? preGeneratedFile,
  }) async {
    final documentFile =
        preGeneratedFile ?? await _docxService.buildInvoiceDocument(invoice);

    if (Platform.isMacOS) {
      final wordAttempt = await Process.run('open', [
        '-a',
        'Microsoft Word',
        documentFile.path,
      ]);
      if (wordAttempt.exitCode == 0) return;

      final fallbackAttempt = await Process.run('open', [documentFile.path]);
      if (fallbackAttempt.exitCode == 0) return;

      throw Exception('Nao foi possivel abrir a fatura no Word.');
    }

    if (Platform.isWindows) {
      final normalizedPath = documentFile.path.replaceAll('/', '\\');
      final wordAttempt = await Process.run('cmd', [
        '/c',
        'start',
        '',
        'winword',
        normalizedPath,
      ], runInShell: true);
      if (wordAttempt.exitCode == 0) return;

      final fallbackAttempt = await Process.run('cmd', [
        '/c',
        'start',
        '',
        normalizedPath,
      ], runInShell: true);
      if (fallbackAttempt.exitCode == 0) return;

      throw Exception('Nao foi possivel abrir a fatura no Word.');
    }

    if (Platform.isLinux) {
      final result = await Process.run('xdg-open', [documentFile.path]);
      if (result.exitCode == 0) return;
      throw Exception('Nao foi possivel abrir a fatura no desktop.');
    }

    await shareInvoiceDocument(invoice, preGeneratedFile: documentFile);
  }

  Future<double> _calculateMonthlyHours({
    required String clientId,
    required DateTime referenceDate,
  }) async {
    final monthStart = DateTime(referenceDate.year, referenceDate.month, 1);
    final nextMonth = DateTime(referenceDate.year, referenceDate.month + 1, 1);

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _firestore
          .collection('workSessions')
          .where('clienteId', isEqualTo: clientId)
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
          )
          .where('startTime', isLessThan: Timestamp.fromDate(nextMonth))
          .get();
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') {
        rethrow;
      }
      snapshot = await _firestore
          .collection('workSessions')
          .where('clienteId', isEqualTo: clientId)
          .get();
    }

    var totalHours = 0.0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final start = (data['startTime'] as Timestamp?)?.toDate();
      if (start == null) continue;
      if (start.isBefore(monthStart) || !start.isBefore(nextMonth)) continue;

      final duration = _resolveDurationHours(data);
      if (duration == null) continue;
      totalHours += duration;
    }

    return totalHours;
  }

  double? _resolveDurationHours(Map<String, dynamic> data) {
    final storedDuration = (data['durationHours'] as num?)?.toDouble();
    if (storedDuration != null) return storedDuration;

    final rawStored = (data['rawDurationHours'] as num?)?.toDouble();
    final start = (data['startTime'] as Timestamp?)?.toDate();
    if (rawStored != null && start != null) {
      final storedMultiplier = (data['durationMultiplier'] as num?)?.toDouble();
      if (storedMultiplier != null && storedMultiplier > 0) {
        return rawStored * storedMultiplier;
      }
      return FixedHolidayHoursPolicy.applyToHours(
        workDate: start,
        rawHours: rawStored,
      );
    }

    final end = (data['endTime'] as Timestamp?)?.toDate();
    if (start == null || end == null) return null;

    final rawHours = end.difference(start).inMinutes / 60.0;
    return FixedHolidayHoursPolicy.applyToHours(
      workDate: start,
      rawHours: rawHours,
    );
  }

  Map<String, double> _sanitizeAdditionalServices(Map<String, double> raw) {
    final normalized = <String, double>{};
    raw.forEach((key, value) {
      final serviceName = key.trim();
      if (serviceName.isEmpty) return;
      if (!value.isFinite || value <= _minBillableAmount) return;
      normalized[serviceName] = value;
    });
    return normalized;
  }

  Map<String, double> _servicePricesForMonth({
    required Clientes cliente,
    required String monthKey,
  }) {
    final monthlyServices = cliente.additionalServicePricesByMonth[monthKey];
    if (monthlyServices != null) {
      return Map<String, double>.from(monthlyServices);
    }

    final nowKey = _monthKey(DateTime.now());
    if (monthKey == nowKey &&
        cliente.additionalServicePricesByMonth.isEmpty &&
        cliente.additionalServicePrices.isNotEmpty) {
      // Legacy fallback for old records without monthly separation.
      return Map<String, double>.from(cliente.additionalServicePrices);
    }
    return const <String, double>{};
  }

  Future<String> _nextInvoiceNumber(DateTime invoiceDate) async {
    final counterRef = _firestore.collection('_meta').doc('invoice_counter');
    final sequence = await _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final year = DateFormat('yyyy').format(invoiceDate);
      final countersByYear = Map<String, dynamic>.from(
        (snapshot.data()?['yearCounters'] as Map?) ?? const <String, dynamic>{},
      );
      final current = (countersByYear[year] as num?)?.toInt() ?? 0;
      final next = current + 1;
      countersByYear[year] = next;

      transaction.set(counterRef, {
        'yearCounters': countersByYear,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      return next;
    });

    final year = DateFormat('yyyy').format(invoiceDate);
    return '$year-${sequence.toString().padLeft(3, '0')}';
  }

  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  (String, String) _splitPostalCodeAndCity(String rawValue) {
    final normalized = rawValue.trim();
    if (normalized.isEmpty) {
      return ('', '');
    }

    if (RegExp(r'^\d{4,5}(?:-\d{3,4})?$').hasMatch(normalized)) {
      return (normalized, '');
    }

    final match = RegExp(
      r'^(\d{4,5}(?:-\d{3,4})?)\s+(.+)$',
    ).firstMatch(normalized);
    if (match != null) {
      final postalCode = (match.group(1) ?? '').trim();
      final city = (match.group(2) ?? '').trim();
      if (RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(city)) {
        return (postalCode, city);
      }
    }

    return (normalized, '');
  }
}

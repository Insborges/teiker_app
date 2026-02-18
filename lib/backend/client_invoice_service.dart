import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:teiker_app/backend/invoice_docx_service.dart';
import 'package:teiker_app/models/Clientes.dart';
import 'package:teiker_app/models/client_invoice.dart';

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

    final monthlyHours = await _calculateMonthlyHours(
      clientId: clientId,
      referenceDate: normalizedDate,
    );
    final additionalServices = _servicePricesForMonth(
      cliente: cliente,
      monthKey: monthKey,
    );
    final additionalServicesTotal = additionalServices.values.fold<double>(
      0,
      (runningTotal, value) => runningTotal + value,
    );
    final monthlyServiceTotal = monthlyHours * cliente.orcamento;

    if (monthlyServiceTotal <= 0 && additionalServicesTotal <= 0) {
      throw Exception(
        'Nao existem horas nem servicos para faturar no mes selecionado.',
      );
    }

    final vatAmount = monthlyServiceTotal * _defaultVatRate;
    final total = monthlyServiceTotal + vatAmount + additionalServicesTotal;
    final invoiceNumber = await _nextInvoiceNumber(normalizedDate);
    final now = DateTime.now();
    final documentRef = _clientInvoicesCollection(clientId).doc();
    final addressParts = _splitPostalCodeAndCity(cliente.codigoPostal);

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
      clientCity: addressParts.$2,
      totalHours: monthlyHours,
      hourlyRate: cliente.orcamento,
      additionalServices: additionalServices,
      servicesTotal: additionalServicesTotal,
      subtotal: monthlyServiceTotal,
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
  }) async {
    final documentFile =
        preGeneratedFile ?? await _docxService.buildInvoiceDocument(invoice);

    await Share.shareXFiles(
      [
        XFile(
          documentFile.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ),
      ],
      text: 'Fatura ${invoice.invoiceNumber} - ${invoice.clientName}',
      subject: 'Fatura ${invoice.invoiceNumber}',
    );
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

    final start = (data['startTime'] as Timestamp?)?.toDate();
    final end = (data['endTime'] as Timestamp?)?.toDate();
    if (start == null || end == null) return null;

    return end.difference(start).inMinutes / 60.0;
  }

  Map<String, double> _servicePricesForMonth({
    required Clientes cliente,
    required String monthKey,
  }) {
    final nowKey = _monthKey(DateTime.now());
    final monthlyServices = cliente.additionalServicePricesByMonth[monthKey];
    if (monthlyServices != null) {
      return Map<String, double>.from(monthlyServices);
    }

    if (monthKey == nowKey) {
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

    final match = RegExp(r'^(\d{4,5})\s*[-,]?\s*(.*)$').firstMatch(normalized);
    if (match != null) {
      final postalCode = (match.group(1) ?? '').trim();
      final city = (match.group(2) ?? '').trim();
      return (postalCode, city);
    }

    return (normalized, '');
  }
}

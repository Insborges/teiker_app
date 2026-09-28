import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teiker_app/backend/invoice_docx_service.dart';
import 'package:teiker_app/models/client_invoice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory output;
  late Uint8List template;

  setUp(() async {
    output = await Directory.systemTemp.createTemp('invoice_test_');
    template = await File('Invoice(Fatura)_Teiker.docx').readAsBytes();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => output.path,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'flutter/assets',
          (_) async => ByteData.sublistView(template),
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    await output.delete(recursive: true);
  });

  Future<String> generate(ClientInvoice invoice) async {
    final file = await InvoiceDocxService().buildInvoiceDocument(invoice);
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    return utf8.decode(archive.findFile('word/document.xml')!.content);
  }

  void changeTemplate(String Function(String) change) {
    final archive = ZipDecoder().decodeBytes(template);
    archive.addFile(
      ArchiveFile.string(
        'word/document.xml',
        change(utf8.decode(archive.findFile('word/document.xml')!.content)),
      ),
    );
    template = Uint8List.fromList(ZipEncoder().encode(archive));
  }

  test(
    'real template uses each client price, billing month and totals without QR',
    () async {
      final first = await generate(invoice('Ana & Filhos', 35));
      final second = await generate(invoice('Bruno', 62));
      expect(first, contains('Ana &amp; Filhos'));
      expect(second, contains('Bruno'));
      for (final xml in [first, second]) {
        expect(xml, contains('Services September Teiker'));
        expect(xml, contains('02/10/2026'));
        expect(xml, contains('10.0h'));
        expect(xml, isNot(contains('August')));
        expect(xml, isNot(contains('49 CHF')));
        expect(xml, isNot(contains('qr_code')));
        expect(xml, contains('Vidros &amp; janelas'));
        expect(xml, contains('20.00 CHF'));
      }
      expect(first, contains('35.00 CHF'));
      expect(first, contains('350.00 CHF'));
      expect(first, contains('28.35 CHF'));
      expect(first, contains('398.35 CHF'));
      expect(second, contains('62.00 CHF'));
      expect(second, contains('620.00 CHF'));
      expect(second, contains('50.22 CHF'));
      expect(second, contains('690.22 CHF'));
      expect(second, isNot(contains('398.35 CHF')));
    },
  );

  test(
    'Word run splitting and text attributes do not leave example amounts',
    () async {
      changeTemplate(
        (xml) => xml
            .replaceAll(
              '<w:t>Price Per Hour</w:t>',
              '<w:t>Price Per </w:t></w:r><w:r><w:t>Hour</w:t>',
            )
            .replaceAll(
              '<w:t>Cleaning Service August</w:t>',
              '<w:t>Cleaning</w:t></w:r><w:r><w:t> Service August</w:t>',
            )
            .replaceAll('<w:t>', '<w:t xml:space="preserve">'),
      );
      final xml = await generate(invoice('Ana', 35));
      expect(xml, contains('Services September Teiker'));
      expect(xml, contains('398.35 CHF'));
      expect(xml, isNot(contains('August')));
      expect(xml, isNot(contains('49 CHF')));
    },
  );

  test('services-only invoice has no example hourly row', () async {
    final xml = await generate(invoice('Ana', 35, hours: 0));
    expect(xml, contains('Vidros &amp; janelas'));
    expect(xml, contains('20.00 CHF'));
    expect(xml, contains('0.00 CHF'));
    expect(xml, isNot(contains('Services September')));
    expect(xml, isNot(contains('49 CHF')));
  });

  test(
    'incompatible template fails instead of exporting sample data',
    () async {
      changeTemplate(
        (xml) => xml.replaceAll('Price Per Hour', 'Changed heading'),
      );
      await expectLater(generate(invoice('Ana', 35)), throwsFormatException);
      expect(output.listSync(), isEmpty);
    },
  );
}

ClientInvoice invoice(String name, double rate, {double hours = 10}) =>
    ClientInvoice(
      id: name,
      clientId: name,
      invoiceNumber: '2026-001',
      invoiceDate: DateTime(2026, 10, 2),
      periodMonthKey: '2026-09',
      periodLabel: 'setembro 2026',
      clientName: name,
      clientAddress: 'Rua Exemplo 1',
      clientPostalCode: '3778',
      clientCity: 'Schonried',
      totalHours: hours,
      hourlyRate: rate,
      additionalServices: {'Vidros & janelas': 20},
      servicesTotal: 20,
      subtotal: hours * rate,
      vatRate: 0.081,
      vatAmount: hours * rate * 0.081,
      total: hours * rate * 1.081 + 20,
      createdAt: DateTime(2026, 10, 2),
    );

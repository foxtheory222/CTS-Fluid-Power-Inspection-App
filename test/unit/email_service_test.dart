import 'dart:io';
import 'dart:typed_data';

import 'package:cts_fluid_power_inspection_app/services/email_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Email service stores recent recipients and customer mappings',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'email_service_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = JsonFileRecipientStore(
        documentsDirectoryProvider: () async => tempDir,
      );
      final adapter = FakeEmailShareAdapter();
      final service = EmailService(
        shareAdapter: adapter,
        recipientStore: store,
      );

      await service.rememberRecipient('service@example.com', customer: 'CTS');
      await service.saveCustomerRecipientMapping(
        customer: 'CTS',
        email: 'service@example.com',
      );

      final recent = await service.recentRecipients();
      expect(recent, hasLength(1));
      expect(recent.first.email, 'service@example.com');
      expect(await service.customerRecipient('CTS'), 'service@example.com');
    },
  );

  test(
    'Email service launches share handoff and records the selected recipient',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'email_service_share_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final store = JsonFileRecipientStore(
        documentsDirectoryProvider: () async => tempDir,
      );
      final adapter = FakeEmailShareAdapter();
      final service = EmailService(
        shareAdapter: adapter,
        recipientStore: store,
      );
      final pdfFile = await _writeTempPdf(tempDir);

      final result = await service.handoffPdf(
        request: EmailHandoffRequest(
          pdfFile: pdfFile,
          subject: 'Inspection Report',
          body: 'Attached is the PDF report.',
          recipients: const <String>['tech@example.com'],
          customer: 'CTS',
        ),
      );

      expect(result.launched, isTrue);
      expect(adapter.lastSharedPdf?.path, pdfFile.path);
      expect(result.recipients, contains('tech@example.com'));
      expect(await service.customerRecipient('CTS'), 'tech@example.com');
    },
  );

  test('Email service surfaces share failures', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'email_service_failure_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = JsonFileRecipientStore(
      documentsDirectoryProvider: () async => tempDir,
    );
    final adapter = FakeEmailShareAdapter(shouldThrow: true);
    final service = EmailService(shareAdapter: adapter, recipientStore: store);
    final pdfFile = await _writeTempPdf(tempDir);

    expect(
      () => service.handoffPdf(
        request: EmailHandoffRequest(
          pdfFile: pdfFile,
          subject: 'Inspection Report',
          body: 'Attached is the PDF report.',
          recipients: const <String>['tech@example.com'],
        ),
      ),
      throwsA(isA<EmailServiceException>()),
    );
  });
}

Future<File> _writeTempPdf(Directory directory) async {
  final file = File('${directory.path}${Platform.pathSeparator}report.pdf');
  await file.writeAsBytes(
    Uint8List.fromList(List<int>.generate(48, (index) => index)),
  );
  return file;
}

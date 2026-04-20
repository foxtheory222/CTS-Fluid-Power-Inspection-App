import 'dart:io';
import 'dart:typed_data';

import 'package:cts_fluid_power_inspection_app/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Backup service exports and imports inspection archives', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'backup_service_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final photoFile = await _writePhoto(tempDir, 'photo.jpg');
    final pdfFile = await _writePdf(tempDir, 'report.pdf');
    final service = BackupService(
      documentsDirectoryProvider: () async => tempDir,
    );
    final exportResult = await service.exportInspection(
      data: InspectionBackupData(
        inspectionJson: <String, dynamic>{
          'documentNumber': '20260420-0001',
          'customer': 'CTS',
          'workOrderNumber': 'WO-1001',
        },
        documentNumber: '20260420-0001',
        customer: 'CTS',
        workOrderNumber: 'WO-1001',
        photoFiles: <File>[photoFile],
        generatedPdfFile: pdfFile,
      ),
    );

    expect(await exportResult.archiveFile.exists(), isTrue);
    expect(await exportResult.archiveFile.length(), greaterThan(0));

    final importResult = await service.importInspection(
      archiveFile: exportResult.archiveFile,
      existingDocumentNumbers: const <String>{'20260420-0001'},
    );

    expect(importResult.documentNumberChanged, isTrue);
    expect(
      importResult.inspectionJson['documentNumber'],
      isNot('20260420-0001'),
    );
    expect(importResult.restoredPhotoFiles, isNotEmpty);
    expect(importResult.restoredPdfFile, isNotNull);
  });

  test(
    'Backup service preserves document number when there is no conflict',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'backup_service_no_conflict_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final pdfFile = await _writePdf(tempDir, 'report.pdf');
      final service = BackupService(
        documentsDirectoryProvider: () async => tempDir,
      );
      final exportResult = await service.exportInspection(
        data: InspectionBackupData(
          inspectionJson: <String, dynamic>{
            'documentNumber': '20260420-0002',
            'customer': 'CTS',
            'workOrderNumber': 'WO-1002',
          },
          documentNumber: '20260420-0002',
          customer: 'CTS',
          workOrderNumber: 'WO-1002',
          generatedPdfFile: pdfFile,
        ),
      );

      final importResult = await service.importInspection(
        archiveFile: exportResult.archiveFile,
        existingDocumentNumbers: const <String>{'20260420-9999'},
      );

      expect(importResult.documentNumber, '20260420-0002');
      expect(importResult.documentNumberChanged, isFalse);
    },
  );
}

Future<File> _writePhoto(Directory directory, String fileName) async {
  final image = img.Image(width: 60, height: 40);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, 200, 40 + x, 40 + y, 255);
    }
  }
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(
    Uint8List.fromList(img.encodeJpg(image, quality: 90)),
  );
  return file;
}

Future<File> _writePdf(Directory directory, String fileName) async {
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(
    Uint8List.fromList(List<int>.generate(72, (index) => (index * 3) % 255)),
  );
  return file;
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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
    final signatureFile = await _writePhoto(tempDir, 'signature.png');
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
        signatureFiles: <File>[signatureFile],
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
    expect(importResult.restoredSignatureFiles, hasLength(1));
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

  test(
    'Backup service skips archive paths outside the restore folder',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'backup_service_unsafe_path_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final inspectionBytes = utf8.encode(
        jsonEncode(<String, dynamic>{
          'documentNumber': '20260420-0003',
          'customer': 'CTS',
          'workOrderNumber': 'WO-1003',
        }),
      );
      final unsafeBytes = utf8.encode('must not escape');
      final unsupportedBytes = utf8.encode('must not be restored');
      final archive = Archive()
        ..addFile(
          ArchiveFile(
            'inspection.json',
            inspectionBytes.length,
            inspectionBytes,
          ),
        )
        ..addFile(ArchiveFile('../escape.txt', unsafeBytes.length, unsafeBytes))
        ..addFile(
          ArchiveFile(
            'notes/extra.txt',
            unsupportedBytes.length,
            unsupportedBytes,
          ),
        );
      final archiveFile = File(
        p.join(tempDir.path, 'unsafe.ctsinspection.zip'),
      );
      await archiveFile.writeAsBytes(ZipEncoder().encode(archive), flush: true);
      final service = BackupService(
        documentsDirectoryProvider: () async => tempDir,
      );

      final result = await service.importInspection(archiveFile: archiveFile);

      expect(result.documentNumber, '20260420-0003');
      expect(result.warnings, contains(contains('Unsafe archive entry')));
      expect(result.warnings, contains(contains('Unsupported archive entry')));
      expect(await File(p.join(tempDir.path, 'escape.txt')).exists(), isFalse);
    },
  );

  test(
    'Backup service reports malformed ZIP data as an archive error',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'backup_service_malformed_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final archiveFile = File(p.join(tempDir.path, 'malformed.zip'));
      await archiveFile.writeAsBytes(<int>[1, 2, 3, 4], flush: true);
      final service = BackupService(
        documentsDirectoryProvider: () async => tempDir,
      );

      await expectLater(
        service.importInspection(archiveFile: archiveFile),
        throwsA(
          isA<BackupServiceException>().having(
            (error) => error.code,
            'code',
            BackupServiceErrorCode.archive,
          ),
        ),
      );
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

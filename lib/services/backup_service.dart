import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class BackupServiceException implements Exception {
  BackupServiceException(this.message, {required this.code});

  final String message;
  final BackupServiceErrorCode code;

  @override
  String toString() => 'BackupServiceException($code): $message';
}

enum BackupServiceErrorCode { io, archive, json }

@immutable
class InspectionBackupData {
  const InspectionBackupData({
    required this.inspectionJson,
    required this.documentNumber,
    required this.customer,
    required this.workOrderNumber,
    this.photoFiles = const <File>[],
    this.generatedPdfFile,
  });

  final Map<String, dynamic> inspectionJson;
  final String documentNumber;
  final String customer;
  final String workOrderNumber;
  final List<File> photoFiles;
  final File? generatedPdfFile;
}

@immutable
class BackupExportResult {
  const BackupExportResult({
    required this.archiveFile,
    required this.warnings,
    required this.exportedFileCount,
  });

  final File archiveFile;
  final List<String> warnings;
  final int exportedFileCount;
}

@immutable
class BackupImportResult {
  const BackupImportResult({
    required this.inspectionJson,
    required this.restoredPhotoFiles,
    required this.restoredPdfFile,
    required this.documentNumber,
    required this.documentNumberChanged,
    required this.warnings,
  });

  final Map<String, dynamic> inspectionJson;
  final List<File> restoredPhotoFiles;
  final File? restoredPdfFile;
  final String documentNumber;
  final bool documentNumberChanged;
  final List<String> warnings;
}

typedef BackupDirectoryProvider = Future<Directory> Function();
typedef DocumentNumberConflictResolver =
    String Function(String originalDocumentNumber);

class BackupService {
  BackupService({
    BackupDirectoryProvider? documentsDirectoryProvider,
    String exportFolderName = 'exports',
    String importFolderName = 'imports',
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _exportFolderName = exportFolderName,
       _importFolderName = importFolderName;

  final BackupDirectoryProvider _documentsDirectoryProvider;
  final String _exportFolderName;
  final String _importFolderName;
  final Uuid _uuid = const Uuid();

  Future<BackupExportResult> exportInspection({
    required InspectionBackupData data,
    String? archiveFileName,
  }) async {
    final rootDirectory = await _buildExportDirectory();
    final fileName =
        archiveFileName ??
        '${_safeFileStem('CTS_Fluid_Power_Inspection_Report_${data.documentNumber}_${data.customer}_${data.workOrderNumber}')}.ctsinspection.zip';
    final archiveFile = File(p.join(rootDirectory.path, fileName));
    final archive = Archive();
    final warnings = <String>[];
    var exportedFileCount = 0;

    _addJsonEntry(archive, 'inspection.json', data.inspectionJson);
    exportedFileCount++;

    for (final photo in data.photoFiles) {
      if (!await photo.exists()) {
        warnings.add('Missing photo file skipped during export: ${photo.path}');
        continue;
      }
      final bytes = await photo.readAsBytes();
      archive.addFile(
        ArchiveFile(
          p.posix.join('photos', p.basename(photo.path)),
          bytes.length,
          bytes,
        ),
      );
      exportedFileCount++;
    }

    if (data.generatedPdfFile case final File pdfFile) {
      if (await pdfFile.exists()) {
        final bytes = await pdfFile.readAsBytes();
        archive.addFile(
          ArchiveFile(
            p.posix.join('generated_pdf', p.basename(pdfFile.path)),
            bytes.length,
            bytes,
          ),
        );
        exportedFileCount++;
      } else {
        warnings.add(
          'Generated PDF file skipped because it does not exist: ${pdfFile.path}',
        );
      }
    }

    final manifest = <String, dynamic>{
      'id': _uuid.v4(),
      'documentNumber': data.documentNumber,
      'customer': data.customer,
      'workOrderNumber': data.workOrderNumber,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'warnings': warnings,
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );
    exportedFileCount++;

    final encoded = ZipEncoder().encode(archive);
    await archiveFile.writeAsBytes(encoded, flush: true);
    return BackupExportResult(
      archiveFile: archiveFile,
      warnings: warnings,
      exportedFileCount: exportedFileCount,
    );
  }

  Future<BackupImportResult> importInspection({
    required File archiveFile,
    Set<String> existingDocumentNumbers = const <String>{},
    DocumentNumberConflictResolver? conflictResolver,
  }) async {
    if (!await archiveFile.exists()) {
      throw BackupServiceException(
        'Archive file does not exist: ${archiveFile.path}',
        code: BackupServiceErrorCode.io,
      );
    }

    final archiveBytes = await archiveFile.readAsBytes();
    final decoded = ZipDecoder().decodeBytes(archiveBytes, verify: true);
    final importRoot = await _buildImportDirectory();
    final restoreFolder = Directory(
      p.join(
        importRoot.path,
        _safeFileStem(
          'import_${DateTime.now().toUtc().millisecondsSinceEpoch}_${_uuid.v4()}',
        ),
      ),
    );
    await restoreFolder.create(recursive: true);

    Map<String, dynamic>? inspectionJson;
    final restoredPhotos = <File>[];
    File? restoredPdf;
    final warnings = <String>[];

    for (final file in decoded) {
      if (!file.isFile) {
        continue;
      }

      final outputPath = p.join(
        restoreFolder.path,
        file.name.replaceAll('/', Platform.pathSeparator),
      );
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(file.content as List<int>, flush: true);

      if (file.name == 'inspection.json') {
        inspectionJson = _decodeInspectionJson(outputFile);
      } else if (file.name.startsWith('photos/')) {
        restoredPhotos.add(outputFile);
      } else if (file.name.startsWith('generated_pdf/')) {
        restoredPdf = outputFile;
      }
    }

    if (inspectionJson == null) {
      throw BackupServiceException(
        'Archive did not contain inspection.json.',
        code: BackupServiceErrorCode.json,
      );
    }

    final originalDocumentNumber =
        inspectionJson['documentNumber']?.toString().trim() ?? '';
    if (originalDocumentNumber.isEmpty) {
      throw BackupServiceException(
        'Imported inspection is missing a document number.',
        code: BackupServiceErrorCode.json,
      );
    }

    var documentNumber = originalDocumentNumber;
    var documentNumberChanged = false;
    if (existingDocumentNumbers.contains(originalDocumentNumber)) {
      documentNumber =
          conflictResolver?.call(originalDocumentNumber) ??
          _generateImportedDocumentNumber(originalDocumentNumber);
      inspectionJson['documentNumber'] = documentNumber;
      documentNumberChanged = true;
      warnings.add(
        'Document number conflict resolved by importing as $documentNumber.',
      );
    }

    return BackupImportResult(
      inspectionJson: inspectionJson,
      restoredPhotoFiles: restoredPhotos,
      restoredPdfFile: restoredPdf,
      documentNumber: documentNumber,
      documentNumberChanged: documentNumberChanged,
      warnings: warnings,
    );
  }

  Future<Directory> _buildExportDirectory() async {
    final documents = await _documentsDirectoryProvider();
    final directory = Directory(p.join(documents.path, _exportFolderName));
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> _buildImportDirectory() async {
    final documents = await _documentsDirectoryProvider();
    final directory = Directory(p.join(documents.path, _importFolderName));
    await directory.create(recursive: true);
    return directory;
  }

  void _addJsonEntry(Archive archive, String name, Map<String, dynamic> json) {
    final bytes = utf8.encode(jsonEncode(json));
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  Map<String, dynamic> _decodeInspectionJson(File file) {
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      // Fall through to error below.
    }
    throw BackupServiceException(
      'inspection.json was not valid JSON.',
      code: BackupServiceErrorCode.json,
    );
  }

  String _generateImportedDocumentNumber(String originalDocumentNumber) {
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    return '${_safeFileStem(originalDocumentNumber)}_imported_$stamp';
  }

  String _safeFileStem(String input) {
    final cleaned = input
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'inspection' : cleaned;
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:cts_fluid_power_inspection_app/core/constants.dart';
import 'package:cts_fluid_power_inspection_app/data/models/inspection_enums.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;

import 'spec_models.dart';

class SpecDocumentNumberGenerator {
  final Map<String, int> _dailyCounters = <String, int>{};

  String next(DateTime timestamp) {
    final key = DateFormat('yyyyMMdd').format(timestamp.toUtc());
    final nextValue = (_dailyCounters[key] ?? 0) + 1;
    _dailyCounters[key] = nextValue;
    return '$key-${nextValue.toString().padLeft(4, '0')}';
  }
}

class SpecInspectionService {
  SpecInspectionService({Directory? rootDirectory})
    : rootDirectory =
          rootDirectory ?? Directory.systemTemp.createTempSync('cts_spec_') {
    photosDirectory.createSync(recursive: true);
    pdfDirectory.createSync(recursive: true);
    exportDirectory.createSync(recursive: true);
  }

  final Directory rootDirectory;
  final SpecDocumentNumberGenerator documentNumbers =
      SpecDocumentNumberGenerator();
  final List<SpecInspection> _inspections = <SpecInspection>[];
  int _inspectionCounter = 0;
  int _photoCounter = 0;
  int _actionCounter = 0;
  int _hoseCounter = 0;
  final Map<String, int> _recipientUsage = <String, int>{};
  final Map<String, String> _recipientCustomers = <String, String>{};

  Directory get photosDirectory =>
      Directory(p.join(rootDirectory.path, 'photos'));
  Directory get pdfDirectory =>
      Directory(p.join(rootDirectory.path, 'generated_pdf'));
  Directory get exportDirectory =>
      Directory(p.join(rootDirectory.path, 'exports'));

  List<SpecInspection> get inspections =>
      List<SpecInspection>.unmodifiable(_inspections);

  SpecInspection createInspection({
    DateTime? now,
    String customer = '',
    String workOrderNumber = '',
    String customerReference = '',
    String assetName = '',
    String siteLocation = '',
    String technicianName = '',
    String servicingShop = '',
  }) {
    final current = (now ?? DateTime.now().toUtc()).toUtc();
    final inspection = SpecInspection(
      id: 'inspection-${++_inspectionCounter}',
      documentNumber: documentNumbers.next(current),
      status: InspectionStatus.draft,
      customer: customer,
      workOrderNumber: workOrderNumber,
      customerReference: customerReference,
      assetName: assetName,
      siteLocation: siteLocation,
      technicianName: technicianName,
      servicingShop: servicingShop,
      inspectionDateTime: current,
      createdAt: current,
      updatedAt: current,
    );
    _inspections.add(inspection);
    return inspection;
  }

  SpecInspection saveInspection(
    SpecInspection inspection, {
    bool editedAfterEmail = false,
  }) {
    final validation = validateCompletion(inspection);
    final preserveEmailedStatus =
        inspection.emailedAt != null && !editedAfterEmail;
    if (editedAfterEmail) {
      inspection.emailedAt = null;
    }
    inspection.updatedAt = DateTime.now().toUtc();
    if (validation.isComplete &&
        inspection.technicianName.trim().isNotEmpty &&
        inspection.signatureFilePath != null) {
      inspection.status = InspectionStatus.complete;
    } else if (inspection.hasProgress) {
      inspection.status = InspectionStatus.inProgress;
    } else {
      inspection.status = InspectionStatus.draft;
    }
    if (preserveEmailedStatus) {
      inspection.status = InspectionStatus.emailed;
    }
    return inspection;
  }

  SpecResponse upsertResponse({
    required SpecInspection inspection,
    required String sectionKey,
    required String itemKey,
    required String itemLabel,
    required InspectionFieldType fieldType,
    required String value,
    required bool isRequired,
    ConditionRating? conditionRating,
    String? comment,
  }) {
    final response = SpecResponse(
      sectionKey: sectionKey,
      itemKey: itemKey,
      itemLabel: itemLabel,
      fieldType: fieldType,
      value: value,
      isRequired: isRequired,
      conditionRating: conditionRating,
      comment: comment,
    );
    inspection.responses.removeWhere(
      (SpecResponse existing) =>
          existing.sectionKey == sectionKey && existing.itemKey == itemKey,
    );
    inspection.responses.add(response);
    syncAutoActionItems(inspection);
    saveInspection(inspection);
    return response;
  }

  SpecActionItem addManualActionItem({
    required SpecInspection inspection,
    required String sourceSectionKey,
    required String sourceItemKey,
    required ConditionRating? conditionRating,
    required String title,
    required String description,
    String? partsRequired,
  }) {
    final item = SpecActionItem(
      id: 'action-${++_actionCounter}',
      sourceSectionKey: sourceSectionKey,
      sourceItemKey: sourceItemKey,
      conditionRating: conditionRating,
      title: title,
      description: description,
      isAutoGenerated: false,
      partsRequired: partsRequired,
    );
    inspection.actionItems.add(item);
    saveInspection(inspection);
    return item;
  }

  SpecHoseEntry addHoseEntry({
    required SpecInspection inspection,
    required String hoseNameLocation,
    required FailureType? failureType,
    required String hoseSize,
    required String hoseLength,
    required String hoseType,
    required String fittingEndA,
    required String fittingEndB,
    required int quantity,
    required String replacementPartNumbers,
    required String partsNeeded,
    required String notes,
  }) {
    final entry = SpecHoseEntry(
      id: 'hose-${++_hoseCounter}',
      hoseNameLocation: hoseNameLocation,
      failureType: failureType,
      hoseSize: hoseSize,
      hoseLength: hoseLength,
      hoseType: hoseType,
      fittingEndA: fittingEndA,
      fittingEndB: fittingEndB,
      quantity: quantity,
      replacementPartNumbers: replacementPartNumbers,
      partsNeeded: partsNeeded,
      notes: notes,
    );
    inspection.hoseEntries.add(entry);
    if (failureType != null && failureType != FailureType.other) {
      inspection.actionItems.add(
        SpecActionItem(
          id: 'action-${++_actionCounter}',
          sourceSectionKey: InspectionSectionKeys.hoseConnectionInspection,
          sourceItemKey: entry.id,
          conditionRating: ConditionRating.unsatisfactory,
          title: 'Replace hose at $hoseNameLocation',
          description: partsNeeded,
          isAutoGenerated: true,
          partsRequired: replacementPartNumbers,
        ),
      );
    }
    saveInspection(inspection);
    return entry;
  }

  Future<SpecPhoto> addPhoto({
    required SpecInspection inspection,
    required String sectionKey,
    required String itemKey,
    required String caption,
    Uint8List? bytes,
    DateTime? capturedAt,
  }) async {
    final count = inspection.photos
        .where(
          (SpecPhoto photo) =>
              photo.sectionKey == sectionKey && photo.itemKey == itemKey,
        )
        .length;
    if (count >= AppConstants.maxPhotosPerInspectionItem) {
      throw StateError('Max photos per item exceeded');
    }
    final current = (capturedAt ?? DateTime.now().toUtc()).toUtc();
    final filePath = p.join(
      photosDirectory.path,
      '${inspection.documentNumber}_${sectionKey}_${itemKey}_${++_photoCounter}.jpg',
    );
    final file = File(filePath);
    await file.parent.create(recursive: true);
    file.writeAsBytesSync(
      bytes ?? Uint8List.fromList(List<int>.generate(64, (int i) => i)),
      flush: true,
    );
    final photo = SpecPhoto(
      id: 'photo-$_photoCounter',
      sectionKey: sectionKey,
      itemKey: itemKey,
      filePath: filePath,
      caption: caption,
      sortOrder: count,
      capturedAt: current,
    );
    inspection.photos.add(photo);
    saveInspection(inspection);
    return photo;
  }

  void deletePhoto(SpecInspection inspection, String photoId) {
    inspection.photos.removeWhere((SpecPhoto photo) => photo.id == photoId);
    saveInspection(inspection);
  }

  void reorderPhotos(
    SpecInspection inspection, {
    required String sectionKey,
    required String itemKey,
    required List<String> orderedPhotoIds,
  }) {
    final matches = inspection.photos
        .where(
          (SpecPhoto photo) =>
              photo.sectionKey == sectionKey && photo.itemKey == itemKey,
        )
        .toList(growable: false);
    final byId = <String, SpecPhoto>{
      for (final photo in matches) photo.id: photo,
    };
    final reordered = <SpecPhoto>[
      for (final id in orderedPhotoIds)
        if (byId.containsKey(id)) byId[id]!,
    ];
    for (var i = 0; i < reordered.length; i++) {
      reordered[i] = SpecPhoto(
        id: reordered[i].id,
        sectionKey: reordered[i].sectionKey,
        itemKey: reordered[i].itemKey,
        filePath: reordered[i].filePath,
        caption: reordered[i].caption,
        sortOrder: i,
        capturedAt: reordered[i].capturedAt,
      );
    }
    inspection.photos.removeWhere(
      (SpecPhoto photo) =>
          photo.sectionKey == sectionKey && photo.itemKey == itemKey,
    );
    inspection.photos.addAll(reordered);
    saveInspection(inspection);
  }

  SpecValidationResult validateCompletion(SpecInspection inspection) {
    final issues = <SpecValidationIssue>[];
    void required(String key, String value, String message) {
      if (value.trim().isEmpty) {
        issues.add(SpecValidationIssue(fieldKey: key, message: message));
      }
    }

    required(
      'customer',
      inspection.customer,
      'Customer / Site Name is required.',
    );
    required(
      'workOrderNumber',
      inspection.workOrderNumber,
      'Work order number is required.',
    );
    required(
      'assetName',
      inspection.assetName,
      'Asset / equipment name is required.',
    );
    required(
      'customerReference',
      inspection.customerReference,
      'Customer reference / PO / job number is required.',
    );
    required(
      'siteLocation',
      inspection.siteLocation,
      'Location / site is required.',
    );
    required(
      'technicianName',
      inspection.technicianName,
      'Technician name is required.',
    );
    required(
      'servicingShop',
      inspection.servicingShop,
      'Servicing shop is required.',
    );

    for (final response in inspection.responses.where(
      (SpecResponse response) => response.isRequired,
    )) {
      final photos = inspection.photos.where(
        (SpecPhoto photo) =>
            photo.sectionKey == response.sectionKey &&
            photo.itemKey == response.itemKey,
      );
      final actions = inspection.actionItems.where(
        (SpecActionItem item) =>
            item.sourceSectionKey == response.sectionKey &&
            item.sourceItemKey == response.itemKey,
      );
      if (response.isFlagged) {
        if ((response.comment ?? '').trim().isEmpty) {
          issues.add(
            SpecValidationIssue(
              fieldKey: '${response.sectionKey}.${response.itemKey}.comment',
              message: '${response.itemLabel} requires a comment.',
            ),
          );
        }
        if (photos.isEmpty) {
          issues.add(
            SpecValidationIssue(
              fieldKey: '${response.sectionKey}.${response.itemKey}.photos',
              message: '${response.itemLabel} requires at least one photo.',
            ),
          );
        }
        if (actions.isEmpty) {
          issues.add(
            SpecValidationIssue(
              fieldKey: '${response.sectionKey}.${response.itemKey}.actionItem',
              message: '${response.itemLabel} requires a linked action item.',
            ),
          );
        }
        if (response.conditionRating == ConditionRating.criticalOutOfService &&
            !inspection.criticalAcknowledged) {
          issues.add(
            SpecValidationIssue(
              fieldKey:
                  '${response.sectionKey}.${response.itemKey}.criticalAck',
              message:
                  'Critical / Out of Service condition requires LOTO acknowledgement.',
            ),
          );
        }
      }
    }

    if (inspection.signatureFilePath == null) {
      issues.add(
        const SpecValidationIssue(
          fieldKey: 'signature',
          message: 'Drawn signature is required.',
        ),
      );
    }

    return SpecValidationResult(issues);
  }

  SpecInspection completeInspection(SpecInspection inspection) {
    final validation = validateCompletion(inspection);
    if (!validation.isComplete) {
      throw StateError(
        validation.issues
            .map((SpecValidationIssue issue) => issue.message)
            .join(' | '),
      );
    }
    inspection.completedAt ??= DateTime.now().toUtc();
    inspection.status = InspectionStatus.complete;
    saveInspection(inspection);
    return inspection;
  }

  SpecInspection markEmailed(
    SpecInspection inspection, {
    required bool confirmed,
    String recipient = '',
    String customer = '',
  }) {
    if (!confirmed) {
      return inspection;
    }
    if (recipient.trim().isNotEmpty) {
      _recipientUsage.update(
        recipient.trim(),
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
      if (customer.trim().isNotEmpty) {
        _recipientCustomers[recipient.trim()] = customer.trim();
      }
    }
    inspection.emailedAt = DateTime.now().toUtc();
    inspection.status = InspectionStatus.emailed;
    saveInspection(inspection);
    return inspection;
  }

  Map<String, int> recentRecipientUsage() =>
      Map<String, int>.unmodifiable(_recipientUsage);

  Map<String, String> recentRecipientCustomers() =>
      Map<String, String>.unmodifiable(_recipientCustomers);

  List<SpecInspection> search(
    String query, {
    InspectionSearchScope scope = InspectionSearchScope.all,
    DateTime? from,
    DateTime? to,
  }) {
    final needle = query.trim().toLowerCase();
    return _inspections
        .where((SpecInspection inspection) {
          final scopeMatch = switch (scope) {
            InspectionSearchScope.all => true,
            InspectionSearchScope.draft =>
              inspection.status == InspectionStatus.draft,
            InspectionSearchScope.inProgress =>
              inspection.status == InspectionStatus.inProgress,
            InspectionSearchScope.complete =>
              inspection.status == InspectionStatus.complete,
            InspectionSearchScope.emailed =>
              inspection.status == InspectionStatus.emailed,
          };
          final dateMatch =
              (from == null || !inspection.inspectionDateTime.isBefore(from)) &&
              (to == null || !inspection.inspectionDateTime.isAfter(to));
          if (!scopeMatch || !dateMatch) {
            return false;
          }
          if (needle.isEmpty) {
            return true;
          }
          final haystack = <String>[
            inspection.documentNumber,
            inspection.customer,
            inspection.workOrderNumber,
            inspection.customerReference,
            inspection.assetName,
            inspection.siteLocation,
            inspection.technicianName,
            inspection.status.label,
          ].join(' ').toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);
  }

  SpecInspection duplicateInspection(SpecInspection inspection) {
    final now = DateTime.now().toUtc();
    final copy = SpecInspection(
      id: 'inspection-${++_inspectionCounter}',
      documentNumber: documentNumbers.next(now),
      status: InspectionStatus.draft,
      customer: inspection.customer,
      workOrderNumber: inspection.workOrderNumber,
      customerReference: inspection.customerReference,
      assetName: inspection.assetName,
      siteLocation: inspection.siteLocation,
      technicianName: inspection.technicianName,
      servicingShop: inspection.servicingShop,
      inspectionDateTime: now,
      createdAt: now,
      updatedAt: now,
    );
    _inspections.add(copy);
    return copy;
  }

  SpecInspection editAfterEmail(
    SpecInspection inspection,
    void Function(SpecInspection draft) edit,
  ) {
    final wasEmailed = inspection.emailedAt != null;
    edit(inspection);
    return saveInspection(inspection, editedAfterEmail: wasEmailed);
  }

  Future<File> generatePdf(SpecInspection inspection) async {
    final regular = pw.Font.ttf(
      await _loadFontAsset('assets/fonts/PublicSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await _loadFontAsset('assets/fonts/PublicSans-Bold.ttf'),
    );
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: regular,
        boldItalic: bold,
        fontFallback: <pw.Font>[regular],
      ),
    );
    final flaggedCount = inspection.responses
        .where((SpecResponse r) => r.isFlagged)
        .length;
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => <pw.Widget>[
          pw.Text(AppConstants.reportTitle),
          pw.Text('Document number: ${inspection.documentNumber}'),
          pw.Text('Customer: ${inspection.customer}'),
          pw.Text('Work order: ${inspection.workOrderNumber}'),
          pw.Text('Asset: ${inspection.assetName}'),
          pw.Text('Technician: ${inspection.technicianName}'),
          pw.Text('Status: ${inspection.status.label}'),
          pw.Text('Flagged items: $flaggedCount'),
          pw.Text('Action items: ${inspection.actionItems.length}'),
          pw.Text('Photo count: ${inspection.photos.length}'),
          if (inspection.criticalAcknowledged)
            pw.Text('LOTO acknowledgement required.'),
          pw.Text('Private & confidential'),
        ],
      ),
    );
    final bytes = await pdf.save();
    final file = File(
      p.join(pdfDirectory.path, '${inspection.documentNumber}.pdf'),
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    inspection.generatedPdfPath = file.path;
    return file;
  }

  Future<ByteData> _loadFontAsset(String path) async {
    try {
      return await rootBundle.load(path);
    } catch (_) {
      final bytes = await File(path).readAsBytes();
      return ByteData.sublistView(Uint8List.fromList(bytes));
    }
  }

  Future<File> exportInspection(SpecInspection inspection) async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'inspection.json',
          encodeSpecJson(inspection.toJson()),
        ),
      );
    for (final photo in inspection.photos) {
      final file = File(photo.filePath);
      if (await file.exists()) {
        archive.addFile(
          ArchiveFile(
            'photos/${p.basename(photo.filePath)}',
            await file.length(),
            await file.readAsBytes(),
          ),
        );
      }
    }
    if (inspection.generatedPdfPath != null) {
      final pdfFile = File(inspection.generatedPdfPath!);
      if (await pdfFile.exists()) {
        archive.addFile(
          ArchiveFile(
            'generated_pdf/${p.basename(pdfFile.path)}',
            await pdfFile.length(),
            await pdfFile.readAsBytes(),
          ),
        );
      }
    }
    final output = File(
      p.join(
        exportDirectory.path,
        '${inspection.documentNumber}.ctsinspection.zip',
      ),
    );
    final encoded = ZipEncoder().encode(archive);
    await output.parent.create(recursive: true);
    await output.writeAsBytes(encoded, flush: true);
    return output;
  }

  Future<SpecInspection> importInspection(
    File archiveFile, {
    bool duplicateOnConflict = true,
  }) async {
    final archive = ZipDecoder().decodeBytes(await archiveFile.readAsBytes());
    final inspectionEntry = archive.findFile('inspection.json');
    if (inspectionEntry == null) {
      throw StateError('Missing inspection.json');
    }
    final imported = SpecInspection.fromJson(
      decodeSpecJson(utf8.decode(inspectionEntry.content as List<int>)),
    );
    final conflict = _inspections.any(
      (SpecInspection existing) =>
          existing.documentNumber == imported.documentNumber,
    );
    final importDir = Directory(
      p.join(rootDirectory.path, 'imports', imported.documentNumber),
    );
    await importDir.create(recursive: true);
    final restoredPhotos = <SpecPhoto>[];
    for (final photo in imported.photos) {
      final source = archive.findFile('photos/${p.basename(photo.filePath)}');
      final restoredPath = p.join(
        importDir.path,
        'photos',
        p.basename(photo.filePath),
      );
      if (source != null) {
        final restoredFile = File(restoredPath);
        await restoredFile.parent.create(recursive: true);
        await restoredFile.writeAsBytes(
          source.content as List<int>,
          flush: true,
        );
        restoredPhotos.add(
          SpecPhoto(
            id: photo.id,
            sectionKey: photo.sectionKey,
            itemKey: photo.itemKey,
            filePath: restoredPath,
            caption: photo.caption,
            sortOrder: photo.sortOrder,
            capturedAt: photo.capturedAt,
          ),
        );
      } else {
        restoredPhotos.add(photo);
      }
    }
    String? restoredPdfPath = imported.generatedPdfPath;
    if (restoredPdfPath != null) {
      final entry = archive.findFile(
        'generated_pdf/${p.basename(restoredPdfPath)}',
      );
      if (entry != null) {
        restoredPdfPath = p.join(
          importDir.path,
          'generated_pdf',
          p.basename(restoredPdfPath),
        );
        final restoredFile = File(restoredPdfPath);
        await restoredFile.parent.create(recursive: true);
        await restoredFile.writeAsBytes(
          entry.content as List<int>,
          flush: true,
        );
      }
    }
    final resolved = conflict && duplicateOnConflict
        ? SpecInspection(
            id: 'inspection-${++_inspectionCounter}',
            documentNumber: documentNumbers.next(DateTime.now().toUtc()),
            status: imported.status,
            customer: imported.customer,
            workOrderNumber: imported.workOrderNumber,
            customerReference: imported.customerReference,
            assetName: imported.assetName,
            siteLocation: imported.siteLocation,
            technicianName: imported.technicianName,
            servicingShop: imported.servicingShop,
            inspectionDateTime: imported.inspectionDateTime,
            createdAt: imported.createdAt,
            updatedAt: imported.updatedAt,
            completedAt: imported.completedAt,
            emailedAt: imported.emailedAt,
            finalTechComments: imported.finalTechComments,
            signatureFilePath: imported.signatureFilePath,
            generatedPdfPath: restoredPdfPath,
            criticalAcknowledged: imported.criticalAcknowledged,
            responses: imported.responses,
            photos: restoredPhotos,
            actionItems: imported.actionItems,
            hoseEntries: imported.hoseEntries,
          )
        : SpecInspection(
            id: imported.id,
            documentNumber: imported.documentNumber,
            status: imported.status,
            customer: imported.customer,
            workOrderNumber: imported.workOrderNumber,
            customerReference: imported.customerReference,
            assetName: imported.assetName,
            siteLocation: imported.siteLocation,
            technicianName: imported.technicianName,
            servicingShop: imported.servicingShop,
            inspectionDateTime: imported.inspectionDateTime,
            createdAt: imported.createdAt,
            updatedAt: imported.updatedAt,
            completedAt: imported.completedAt,
            emailedAt: imported.emailedAt,
            finalTechComments: imported.finalTechComments,
            signatureFilePath: imported.signatureFilePath,
            generatedPdfPath: restoredPdfPath,
            criticalAcknowledged: imported.criticalAcknowledged,
            responses: imported.responses,
            photos: restoredPhotos,
            actionItems: imported.actionItems,
            hoseEntries: imported.hoseEntries,
          );
    _inspections.add(resolved);
    return resolved;
  }

  void syncAutoActionItems(SpecInspection inspection) {
    final desired = <String>{};
    for (final response in inspection.responses.where(
      (SpecResponse response) => response.isFlagged,
    )) {
      final key = '${response.sectionKey}:${response.itemKey}';
      desired.add(key);
      final existingIndex = inspection.actionItems.indexWhere(
        (SpecActionItem item) =>
            item.isAutoGenerated &&
            item.sourceSectionKey == response.sectionKey &&
            item.sourceItemKey == response.itemKey,
      );
      if (existingIndex == -1) {
        inspection.actionItems.add(
          SpecActionItem(
            id: 'action-${++_actionCounter}',
            sourceSectionKey: response.sectionKey,
            sourceItemKey: response.itemKey,
            conditionRating: response.conditionRating,
            title: '${response.itemLabel} requires attention',
            description:
                response.comment ?? 'Flagged condition requires follow-up.',
            isAutoGenerated: true,
          ),
        );
      } else {
        inspection.actionItems[existingIndex] = SpecActionItem(
          id: inspection.actionItems[existingIndex].id,
          sourceSectionKey: response.sectionKey,
          sourceItemKey: response.itemKey,
          conditionRating: response.conditionRating,
          title: '${response.itemLabel} requires attention',
          description:
              response.comment ?? 'Flagged condition requires follow-up.',
          isAutoGenerated: true,
          partsRequired: inspection.actionItems[existingIndex].partsRequired,
        );
      }
    }
    inspection.actionItems.removeWhere(
      (SpecActionItem item) =>
          item.isAutoGenerated &&
          !desired.contains('${item.sourceSectionKey}:${item.sourceItemKey}') &&
          !inspection.hoseEntries.any(
            (SpecHoseEntry hose) => hose.id == item.sourceItemKey,
          ),
    );
  }
}

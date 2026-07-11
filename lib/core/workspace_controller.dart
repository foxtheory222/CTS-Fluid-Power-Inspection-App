import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'constants.dart';
import 'file_utils.dart';
import 'theme.dart';
import 'validators.dart';
import '../data/models/inspection_enums.dart';
import '../data/models/inspection_models.dart';
import '../data/repositories/inspection_repository.dart';
import '../features/pdf_report/pdf_report_models.dart';
import '../services/backup_service.dart';
import '../services/email_service.dart';
import '../services/pdf_service.dart';
import 'workspace_models.dart';

class AppWorkspaceController extends ChangeNotifier {
  AppWorkspaceController({
    InspectionRepository? repository,
    PdfService? pdfService,
    EmailService? emailService,
    BackupService? backupService,
    bool seedDemoData = true,
  }) : _repository = repository,
       _pdfService = pdfService ?? PdfService(),
       _emailService = emailService ?? EmailService(),
       _backupService = backupService ?? BackupService(),
       _inspections = seedDemoData ? _seedInspections() : <InspectionSummary>[];

  final InspectionRepository? _repository;
  final PdfService _pdfService;
  final EmailService _emailService;
  final BackupService _backupService;
  final List<InspectionSummary> _inspections;
  String _searchQuery = '';
  InspectionStatus? _statusFilter;
  bool _isLoading = false;
  String? _lastError;

  String get searchQuery => _searchQuery;
  InspectionStatus? get statusFilter => _statusFilter;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  List<InspectionSummary> get inspections => List.unmodifiable(_inspections);

  List<InspectionSummary> get filteredInspections {
    final query = _searchQuery.trim().toLowerCase();
    return _inspections
        .where((inspection) {
          final matchesQuery =
              query.isEmpty || inspection.searchableText.contains(query);
          final matchesStatus =
              _statusFilter == null || inspection.status == _statusFilter;
          return matchesQuery && matchesStatus;
        })
        .toList(growable: false);
  }

  List<DashboardMetric> get dashboardMetrics => [
    DashboardMetric(
      label: 'Draft',
      value: _inspections
          .where((item) => item.status == InspectionStatus.draft)
          .length
          .toString(),
      icon: Icons.description_outlined,
      color: CtsPalette.slate,
      subtitle: 'Ready to continue',
    ),
    DashboardMetric(
      label: 'In Progress',
      value: _inspections
          .where((item) => item.status == InspectionStatus.inProgress)
          .length
          .toString(),
      icon: Icons.play_circle_outline,
      color: CtsPalette.orange,
      subtitle: 'Actively being filled out',
    ),
    DashboardMetric(
      label: 'Complete',
      value: _inspections
          .where((item) => item.status == InspectionStatus.complete)
          .length
          .toString(),
      icon: Icons.verified_outlined,
      color: CtsPalette.success,
      subtitle: 'Validated and signed',
    ),
    DashboardMetric(
      label: 'Emailed',
      value: _inspections
          .where((item) => item.status == InspectionStatus.emailed)
          .length
          .toString(),
      icon: Icons.mark_email_read_outlined,
      color: CtsPalette.info,
      subtitle: 'Handed off to the customer',
    ),
    DashboardMetric(
      label: 'Critical',
      value: _inspections
          .where((item) => item.criticalCount > 0)
          .length
          .toString(),
      icon: Icons.warning_amber_rounded,
      color: CtsPalette.danger,
      subtitle: 'LOTO attention required',
    ),
    DashboardMetric(
      label: 'Photos',
      value: _inspections
          .fold<int>(0, (sum, item) => sum + item.photoCount)
          .toString(),
      icon: Icons.photo_library_outlined,
      color: CtsPalette.orangeSoft,
      subtitle: 'Stored locally on device',
    ),
  ];

  InspectionSummary? inspectionById(String id) {
    for (final inspection in _inspections) {
      if (inspection.id == id) {
        return inspection;
      }
    }
    return null;
  }

  Future<InspectionRecord?> inspectionRecordById(String id) async {
    final repository = _repository;
    if (repository != null) {
      return repository.getInspection(id);
    }
    final summary = inspectionById(id);
    return summary == null ? null : _recordFromSummary(summary);
  }

  Future<void> loadPersistedInspections() async {
    final repository = _repository;
    if (repository == null || _isLoading) {
      return;
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final records = await repository.allInspections();
      _inspections
        ..clear()
        ..addAll(records.map(_summaryFromRecord));
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<InspectionSummary> saveFormDraft(
    InspectionFormDraft draft, {
    bool complete = false,
  }) async {
    final repository = _repository;
    if (repository == null) {
      return _saveInMemoryDraft(draft, complete: complete);
    }

    final InspectionRecord? existingRecord = draft.inspectionId == null
        ? null
        : await repository.getInspection(draft.inspectionId!);
    if (draft.inspectionId != null && existingRecord == null) {
      throw StateError('Inspection not found: ${draft.inspectionId}');
    }
    final InspectionRecord record =
        existingRecord ?? await repository.createInspection();

    _applyDraftToRecord(record, draft);
    if (draft.technicianSignaturePngBytes != null) {
      record.signatureFilePath = await _writeSignatureBytes(
        record.id,
        AppConstants.signatureFileName,
        draft.technicianSignaturePngBytes!,
      );
    } else if (!draft.keepExistingTechnicianSignature) {
      record.signatureFilePath = null;
    }
    if (draft.customerSignaturePngBytes != null) {
      record.customerSignatureFilePath = await _writeSignatureBytes(
        record.id,
        AppConstants.customerSignatureFileName,
        draft.customerSignaturePngBytes!,
      );
    } else if (!draft.keepExistingCustomerSignature) {
      record.customerSignatureFilePath = null;
    }
    if (existingRecord != null) {
      record.generatedPdfPath = null;
      record.emailedAt = null;
      if (!complete) {
        record.completedAt = null;
      }
    }
    if (complete) {
      record.completedAt = DateTime.now();
    }

    final saved = await repository.saveInspection(record);
    final summary = _summaryFromRecord(saved);
    _upsertSummary(summary);
    return summary;
  }

  Future<List<String>> completionIssueMessages(String inspectionId) async {
    final repository = _repository;
    if (repository == null) {
      return const <String>[];
    }
    final record = await repository.getInspection(inspectionId);
    if (record == null) {
      throw StateError('Inspection not found: $inspectionId');
    }
    return InspectionValidator.validateForCompletion(
      record,
    ).issues.map((issue) => issue.message).toList(growable: false);
  }

  Future<InspectionSummary> duplicatePersistedInspection(
    InspectionSummary source,
  ) async {
    final repository = _repository;
    if (repository == null) {
      return duplicateInspection(source);
    }

    final sourceRecord = await repository.getInspection(source.id);
    final duplicate = await repository.duplicateInspection(
      sourceRecord ?? _recordFromSummary(source),
    );
    final summary = _summaryFromRecord(duplicate);
    _inspections.insert(0, summary);
    notifyListeners();
    return summary;
  }

  Future<File> generatePdf(String inspectionId) async {
    final repository = _repository;
    if (repository == null) {
      throw StateError('Persistent repository is not available.');
    }
    final record = await repository.getInspection(inspectionId);
    if (record == null) {
      throw StateError('Inspection not found.');
    }
    _requireCompletedRecord(record, action: 'generate a final PDF');

    final outputDirectory = await FileUtils.inspectionReportsDirectory(
      record.id,
    );
    final pdfFile = await _pdfService.generateInspectionReportFile(
      _reportDataFromRecord(record),
      outputDirectory: outputDirectory,
    );
    record.generatedPdfPath = pdfFile.path;
    final saved = await repository.saveInspection(record);
    _upsertSummary(_summaryFromRecord(saved));
    return pdfFile;
  }

  Future<List<RecentEmailRecipient>> emailRecipientSuggestions(
    String customer,
  ) {
    return _emailService.recipientSuggestions(customer: customer);
  }

  Future<void> emailInspectionPdf(
    String inspectionId, {
    List<String> recipients = const <String>[],
  }) async {
    final repository = _repository;
    if (repository == null) {
      throw StateError('Persistent repository is not available.');
    }
    var record = await repository.getInspection(inspectionId);
    if (record == null) {
      throw StateError('Inspection not found.');
    }
    _requireCompletedRecord(record, action: 'share the report');

    File pdfFile;
    if ((record.generatedPdfPath ?? '').trim().isNotEmpty &&
        await File(record.generatedPdfPath!).exists()) {
      pdfFile = File(record.generatedPdfPath!);
    } else {
      pdfFile = await generatePdf(inspectionId);
      record = await repository.getInspection(inspectionId) ?? record;
    }

    await _emailService.handoffPdf(
      request: EmailHandoffRequest(
        pdfFile: pdfFile,
        subject: 'CTS Fluid Power Inspection ${record.documentNumber}',
        body:
            'Attached is the CTS Fluid Power inspection report for '
            '${record.customer}.',
        recipients: recipients,
        customer: record.customer,
      ),
    );
  }

  Future<void> confirmInspectionEmailed(String inspectionId) async {
    final repository = _repository;
    if (repository == null) {
      throw StateError('Persistent repository is not available.');
    }
    final record = await repository.getInspection(inspectionId);
    if (record == null) {
      throw StateError('Inspection not found.');
    }
    _requireCompletedRecord(record, action: 'mark the report as emailed');
    final emailed = await repository.markEmailed(record);
    _upsertSummary(_summaryFromRecord(emailed));
  }

  Future<BackupExportResult> exportInspection(String inspectionId) async {
    final repository = _repository;
    if (repository == null) {
      throw StateError('Persistent repository is not available.');
    }
    final record = await repository.getInspection(inspectionId);
    if (record == null) {
      throw StateError('Inspection not found.');
    }

    final generatedPdfPath = record.generatedPdfPath?.trim();
    return _backupService.exportInspection(
      data: InspectionBackupData(
        inspectionJson: record.toJson(),
        documentNumber: record.documentNumber,
        customer: record.customer,
        workOrderNumber: record.workOrderNumber,
        photoFiles: record.photos
            .map((photo) => File(photo.filePath))
            .toList(growable: false),
        signatureFiles: <File>[
          if ((record.signatureFilePath ?? '').trim().isNotEmpty)
            File(record.signatureFilePath!),
          if ((record.customerSignatureFilePath ?? '').trim().isNotEmpty)
            File(record.customerSignatureFilePath!),
        ],
        generatedPdfFile: generatedPdfPath == null || generatedPdfPath.isEmpty
            ? null
            : File(generatedPdfPath),
      ),
    );
  }

  Future<InspectionSummary> importInspectionArchive(File archiveFile) async {
    final repository = _repository;
    if (repository == null) {
      throw StateError('Persistent repository is not available.');
    }
    final existing = await repository.allInspections();
    final result = await _backupService.importInspection(
      archiveFile: archiveFile,
      existingDocumentNumbers: existing
          .map((record) => record.documentNumber)
          .toSet(),
    );
    final payload = _rekeyImportedPayload(
      result.inspectionJson,
      newInspectionId: const Uuid().v4(),
      documentNumber: result.documentNumber,
      restoredPhotos: result.restoredPhotoFiles,
      restoredSignatures: result.restoredSignatureFiles,
      restoredPdf: result.restoredPdfFile,
    );
    final imported = InspectionRecord.fromJson(payload);
    final saved = await repository.saveInspection(imported);
    final summary = _summaryFromRecord(saved);
    _upsertSummary(summary);
    return summary;
  }

  Map<String, dynamic> _rekeyImportedPayload(
    Map<String, dynamic> source, {
    required String newInspectionId,
    required String documentNumber,
    required List<File> restoredPhotos,
    required List<File> restoredSignatures,
    required File? restoredPdf,
  }) {
    final payload = Map<String, dynamic>.from(source)
      ..['id'] = newInspectionId
      ..['documentNumber'] = documentNumber
      ..['generatedPdfPath'] = restoredPdf?.path;
    final photoByName = <String, File>{
      for (final file in restoredPhotos) p.basename(file.path): file,
    };
    final signatureByName = <String, File>{
      for (final file in restoredSignatures) p.basename(file.path): file,
    };
    String? restoredPath(String? original, Map<String, File> files) {
      if (original == null || original.trim().isEmpty) {
        return null;
      }
      return files[p.basename(original)]?.path;
    }

    payload['signatureFilePath'] = restoredPath(
      source['signatureFilePath'] as String?,
      signatureByName,
    );
    payload['customerSignatureFilePath'] = restoredPath(
      source['customerSignatureFilePath'] as String?,
      signatureByName,
    );

    final idMap = <String, String>{};
    for (final collectionName in const <String>[
      'sections',
      'responses',
      'photos',
      'actionItems',
      'hoseEntries',
      'componentEntries',
      'filterEntries',
      'requiredItems',
    ]) {
      final items = (source[collectionName] as List<dynamic>? ?? <dynamic>[]);
      final remappedItems = <Map<String, dynamic>>[];
      for (var index = 0; index < items.length; index++) {
        final item = Map<String, dynamic>.from(
          items[index] as Map<String, dynamic>,
        );
        final oldId = item['id'] as String?;
        final newId = '${newInspectionId}_${collectionName}_$index';
        if (oldId != null) {
          idMap[oldId] = newId;
        }
        item['id'] = newId;
        item['inspectionId'] = newInspectionId;
        if (collectionName == 'photos') {
          final path = restoredPath(item['filePath'] as String?, photoByName);
          if (path == null) {
            continue;
          }
          item['filePath'] = path;
        }
        remappedItems.add(item);
      }
      payload[collectionName] = remappedItems;
    }

    for (final collectionName in const <String>['photos', 'actionItems']) {
      for (final item
          in payload[collectionName] as List<Map<String, dynamic>>) {
        final sourceItemKey = item['sourceItemKey'] ?? item['itemKey'];
        if (sourceItemKey is! String || !sourceItemKey.contains(':')) {
          continue;
        }
        final parts = sourceItemKey.split(':');
        final replacement = idMap[parts.last];
        if (replacement == null) {
          continue;
        }
        final remapped = '${parts.first}:$replacement';
        if (item.containsKey('sourceItemKey')) {
          item['sourceItemKey'] = remapped;
        }
        if (item.containsKey('itemKey')) {
          item['itemKey'] = remapped;
        }
      }
    }
    return payload;
  }

  Future<void> removeInspectionPhoto(
    String inspectionId,
    String filePath,
  ) async {
    final repository = _repository;
    if (repository == null) {
      return;
    }
    final record = await repository.getInspection(inspectionId);
    if (record == null) {
      throw StateError('Inspection not found.');
    }
    final removed = record.photos.where((photo) => photo.filePath == filePath);
    if (removed.isEmpty) {
      return;
    }
    record.photos.removeWhere((photo) => photo.filePath == filePath);
    await repository.saveInspection(record);
    final file = File(filePath.replaceFirst('file://', ''));
    if (await file.exists()) {
      await file.delete();
    }
    _upsertSummary(_summaryFromRecord(record));
  }

  void _requireCompletedRecord(
    InspectionRecord record, {
    required String action,
  }) {
    final validation = InspectionValidator.validateForCompletion(record);
    if (!validation.isValid || record.completedAt == null) {
      throw StateError(
        'Complete the inspection before you $action. '
        '${validation.issues.length} completion issue(s) remain.',
      );
    }
  }

  List<InspectionSummary> get recentInspections {
    final copy = List<InspectionSummary>.of(_inspections);
    copy.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
    return copy.take(6).toList(growable: false);
  }

  List<InspectionActionItemView> get openActionItems =>
      _inspections.expand((item) => item.actionItems).toList(growable: false);

  void setSearchQuery(String value) {
    if (value == _searchQuery) {
      return;
    }
    _searchQuery = value;
    notifyListeners();
  }

  void setStatusFilter(InspectionStatus? status) {
    if (status == _statusFilter) {
      return;
    }
    _statusFilter = status;
    notifyListeners();
  }

  InspectionSummary createInspection() {
    final now = DateTime.now();
    final documentNumber = _nextDocumentNumberForDate(now);
    final inspection = InspectionSummary(
      id: _makeId(documentNumber),
      documentNumber: documentNumber,
      customer: '',
      workOrderNumber: '',
      customerReference: '',
      assetName: '',
      siteLocation: '',
      technicianName: '',
      servicingShop: '',
      inspectionDateTime: now,
      createdAt: now,
      status: InspectionStatus.draft,
      sections: _defaultSections(),
      actionItems: [],
      photos: [],
      flaggedCount: 0,
      atRiskCount: 0,
      unsatisfactoryCount: 0,
      criticalCount: 0,
      photoCount: 0,
      lastUpdatedAt: now,
    );
    _inspections.insert(0, inspection);
    notifyListeners();
    return inspection;
  }

  InspectionSummary duplicateInspection(InspectionSummary source) {
    final now = DateTime.now();
    final documentNumber = _nextDocumentNumberForDate(now);
    final clone = source.copyWith(
      id: _makeId(documentNumber),
      documentNumber: documentNumber,
      status: InspectionStatus.draft,
      createdAt: now,
      inspectionDateTime: now,
      completedAt: null,
      emailedAt: null,
      finalTechComments: null,
      criticalAcknowledged: false,
      generatedPdfPath: null,
      clearCompletedAt: true,
      clearEmailedAt: true,
      clearFinalTechComments: true,
      clearGeneratedPdfPath: true,
      sections: _defaultSections(),
      actionItems: [],
      photos: [],
      flaggedCount: 0,
      atRiskCount: 0,
      unsatisfactoryCount: 0,
      criticalCount: 0,
      photoCount: 0,
      lastUpdatedAt: now,
    );
    _inspections.insert(0, clone);
    notifyListeners();
    return clone;
  }

  void replaceInspection(InspectionSummary updated) {
    final index = _inspections.indexWhere((item) => item.id == updated.id);
    if (index != -1) {
      _inspections[index] = updated;
      notifyListeners();
    }
  }

  InspectionSummary _saveInMemoryDraft(
    InspectionFormDraft draft, {
    required bool complete,
  }) {
    final now = DateTime.now();
    final existing = draft.inspectionId == null
        ? null
        : inspectionById(draft.inspectionId!);
    if (draft.inspectionId != null && existing == null) {
      throw StateError('Inspection not found: ${draft.inspectionId}');
    }
    final summary = (existing ?? createInspection()).copyWith(
      customer: draft.customer,
      workOrderNumber: draft.workOrderNumber,
      customerReference: draft.customerReference,
      assetName: draft.assetName,
      siteLocation: draft.siteLocation,
      technicianName: draft.technicianName,
      servicingShop: draft.servicingShop,
      finalTechComments: draft.finalTechComments,
      criticalAcknowledged: draft.criticalAcknowledged,
      status: InspectionStatus.inProgress,
      completedAt: existing?.completedAt,
      lastUpdatedAt: now,
    );
    _upsertSummary(summary);
    return summary;
  }

  void _upsertSummary(InspectionSummary summary) {
    final index = _inspections.indexWhere((item) => item.id == summary.id);
    if (index == -1) {
      _inspections.insert(0, summary);
    } else {
      _inspections[index] = summary;
    }
    _inspections.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
    notifyListeners();
  }

  void _applyDraftToRecord(InspectionRecord record, InspectionFormDraft draft) {
    record
      ..customer = draft.customer.trim()
      ..workOrderNumber = draft.workOrderNumber.trim()
      ..customerReference = draft.customerReference.trim()
      ..assetName = draft.assetName.trim()
      ..hpuAssetIdName = draft.assetName.trim()
      ..siteLocation = draft.siteLocation.trim()
      ..technicianName = draft.technicianName.trim()
      ..servicingShop = draft.servicingShop.trim()
      ..finalTechComments = draft.finalTechComments.trim()
      ..criticalAcknowledged = draft.criticalAcknowledged;

    for (final component in record.componentEntries) {
      final draftValue = draft.componentPartNumbers[component.componentType];
      if (draftValue != null) {
        component.modelPartNumber = draftValue.trim().isEmpty
            ? null
            : draftValue.trim();
      }
    }
    if (draft.componentPartNumbers.isEmpty &&
        record.componentEntries.isNotEmpty &&
        draft.componentPartNumber != null) {
      final draftValue = draft.componentPartNumber!.trim();
      record.componentEntries.first.modelPartNumber = draftValue.isEmpty
          ? null
          : draftValue;
    }

    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.fluidLevel,
      itemLabel: 'Fluid Level',
      fieldType: InspectionFieldType.dropdown,
      value: draft.fluidLevel?.value,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.fluidClarity,
      itemLabel: 'Fluid Clarity',
      fieldType: InspectionFieldType.dropdown,
      value: draft.fluidClarity?.value,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.tankIntegrity,
      itemLabel: 'Tank Integrity',
      fieldType: InspectionFieldType.conditionRating,
      value: draft.tankIntegrity?.value,
      conditionRating: draft.tankIntegrity,
      comment: draft.tankNotes,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.fluidTankService,
      itemKey: InspectionItemKeys.tankCleanoutPerformed,
      itemLabel: 'Tank Cleanout Performed',
      fieldType: InspectionFieldType.yesNoNa,
      value: draft.tankCleanoutPerformed?.value,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.hoseConnectionInspection,
      itemKey: InspectionItemKeys.overallHoseCondition,
      itemLabel: 'Overall Hose Condition',
      fieldType: InspectionFieldType.conditionRating,
      value: draft.hoseCondition?.value,
      conditionRating: draft.hoseCondition,
      comment: [
        draft.hoseNameLocation,
        draft.hosePartsRequired,
      ].where((value) => (value ?? '').trim().isNotEmpty).join(' | '),
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.breatherPartNumber,
      itemLabel: 'Breather Part Number',
      fieldType: InspectionFieldType.text,
      value: draft.breatherPartNumber,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.breatherReplaced,
      itemLabel: 'Breather Replaced',
      fieldType: InspectionFieldType.dropdown,
      value: draft.breatherReplaced?.value,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.pressureFilterPartNumber,
      itemLabel: 'Pressure Filter PN',
      fieldType: InspectionFieldType.text,
      value: draft.pressureFilterPartNumber,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.pressureFilterReplaced,
      itemLabel: 'Pressure Filter Replaced',
      fieldType: InspectionFieldType.dropdown,
      value: draft.pressureFilterReplaced?.value,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.returnFilterPartNumber,
      itemLabel: 'Return Filter PN',
      fieldType: InspectionFieldType.text,
      value: draft.returnFilterPartNumber,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.filtrationBreatherService,
      itemKey: InspectionItemKeys.returnFilterReplaced,
      itemLabel: 'Return Filter Replaced',
      fieldType: InspectionFieldType.dropdown,
      value: draft.returnFilterReplaced?.value,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.equipmentRunning,
      itemLabel: 'Equipment Running',
      fieldType: InspectionFieldType.yesNoNa,
      value: draft.equipmentRunning?.value,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.pumpCompensatorSetting,
      itemLabel: 'Pump Compensator Setting Observed',
      fieldType: InspectionFieldType.number,
      value: draft.pumpCompensatorSetting,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.changePumpCompensator,
      itemLabel: 'Change Pump Compensator Setting',
      fieldType: InspectionFieldType.yesNoNa,
      value: draft.changePumpCompensator?.value,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.systemReliefSetting,
      itemLabel: 'System Relief Setting Observed',
      fieldType: InspectionFieldType.number,
      value: draft.systemReliefSetting,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.changeSystemRelief,
      itemLabel: 'Change System Relief Setting',
      fieldType: InspectionFieldType.yesNoNa,
      value: draft.changeSystemRelief?.value,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.operatingTemperature,
      itemLabel: 'Operating Temperature',
      fieldType: InspectionFieldType.number,
      value: draft.operatingTemperature,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.operatingTemperatureUnit,
      itemLabel: 'Operating Temperature Unit',
      fieldType: InspectionFieldType.dropdown,
      value: draft.operatingTemperatureUnit?.symbol,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.accumulatorPreCharge,
      itemLabel: 'Accumulator Pre-charge',
      fieldType: InspectionFieldType.number,
      value: draft.accumulatorPreCharge,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.chargeAccumulator,
      itemLabel: 'Charge Accumulator',
      fieldType: InspectionFieldType.yesNoNa,
      value: draft.chargeAccumulator?.value,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.operationalDataSystemTest,
      itemKey: InspectionItemKeys.operationalNotes,
      itemLabel: 'Operational Notes',
      fieldType: InspectionFieldType.multilineText,
      value: draft.operationalNotes,
    );
    _upsertResponse(
      record,
      sectionKey: InspectionSectionKeys.followUpRepairsQuoting,
      itemKey: InspectionItemKeys.additionalPartsRepairs,
      itemLabel: 'Are additional parts/repairs required?',
      fieldType: InspectionFieldType.yesNoNa,
      value: draft.additionalPartsRepairs?.value,
      comment: draft.finalTechComments,
    );

    _syncAdditionalRepairsAction(record, draft);
    _mergeDraftPhotos(record, draft.photos);
  }

  void _syncAdditionalRepairsAction(
    InspectionRecord record,
    InspectionFormDraft draft,
  ) {
    const sourceItemKey = InspectionItemKeys.additionalPartsRepairs;
    final existingIndex = record.actionItems.indexWhere(
      (item) => !item.isAutoGenerated && item.sourceItemKey == sourceItemKey,
    );
    final description = draft.finalTechComments.trim();
    if (draft.additionalPartsRepairs != YesNoNa.yes || description.isEmpty) {
      if (existingIndex != -1) {
        record.actionItems.removeAt(existingIndex);
      }
      return;
    }

    final now = DateTime.now();
    final existing = existingIndex == -1
        ? null
        : record.actionItems[existingIndex];
    final action = ActionItem(
      id: existing?.id ?? '${record.id}_additional_repairs',
      inspectionId: record.id,
      sourceSectionKey: InspectionSectionKeys.followUpRepairsQuoting,
      sourceItemKey: sourceItemKey,
      title: 'Additional parts / repairs',
      description: description,
      isAutoGenerated: false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    if (existingIndex == -1) {
      record.actionItems.add(action);
    } else {
      record.actionItems[existingIndex] = action;
    }
  }

  void _mergeDraftPhotos(
    InspectionRecord record,
    List<InspectionPhotoView> photos,
  ) {
    if (photos.isEmpty) {
      return;
    }
    final now = DateTime.now();
    for (final draftPhoto in photos) {
      if (!_isLocalPhotoPath(draftPhoto.assetPath)) {
        continue;
      }
      final sectionKey = _sectionKeyForTitle(draftPhoto.sectionTitle);
      final itemKey = draftPhoto.itemLabel;
      final alreadySaved = record.photos.any(
        (photo) =>
            photo.sectionKey == sectionKey &&
            photo.itemKey == itemKey &&
            photo.filePath == draftPhoto.assetPath &&
            (photo.caption ?? '') == draftPhoto.caption,
      );
      if (alreadySaved) {
        continue;
      }
      record.photos.add(
        InspectionPhoto(
          id: '${record.id}_${sectionKey}_${itemKey}_${record.photos.length + 1}',
          inspectionId: record.id,
          sectionKey: sectionKey,
          itemKey: itemKey,
          filePath: draftPhoto.assetPath,
          caption: draftPhoto.caption,
          sortOrder: record.photos.length,
          capturedAt: draftPhoto.capturedAt,
          createdAt: now,
        ),
      );
    }
  }

  bool _isLocalPhotoPath(String path) {
    return path.startsWith('/') || path.startsWith('file://');
  }

  String _sectionKeyForTitle(String title) {
    for (final descriptor in InspectionSectionKeys.ordered) {
      if (descriptor.title == title) {
        return descriptor.key;
      }
    }
    return InspectionSectionKeys.jobAssetIdentification;
  }

  void _upsertResponse(
    InspectionRecord record, {
    required String sectionKey,
    required String itemKey,
    required String itemLabel,
    required InspectionFieldType fieldType,
    String? value,
    ConditionRating? conditionRating,
    String? comment,
  }) {
    final existingIndex = record.responses.indexWhere(
      (response) =>
          response.sectionKey == sectionKey && response.itemKey == itemKey,
    );
    final hasValue =
        (value ?? '').trim().isNotEmpty ||
        conditionRating != null ||
        (comment ?? '').trim().isNotEmpty;
    if (!hasValue) {
      if (existingIndex != -1) {
        record.responses.removeAt(existingIndex);
      }
      return;
    }

    final now = DateTime.now();
    final response = InspectionResponse(
      id: existingIndex == -1
          ? '${record.id}_$itemKey'
          : record.responses[existingIndex].id,
      inspectionId: record.id,
      sectionKey: sectionKey,
      itemKey: itemKey,
      itemLabel: itemLabel,
      fieldType: fieldType,
      value: value,
      conditionRating: conditionRating,
      isFlagged: conditionRating?.isFlagged ?? false,
      comment: (comment ?? '').trim().isEmpty ? null : comment!.trim(),
      createdAt: existingIndex == -1
          ? now
          : record.responses[existingIndex].createdAt,
      updatedAt: now,
    );
    if (existingIndex == -1) {
      record.responses.add(response);
    } else {
      record.responses[existingIndex] = response;
    }
  }

  Future<String> _writeSignatureBytes(
    String inspectionId,
    String fileName,
    Uint8List bytes,
  ) async {
    final directory = await FileUtils.inspectionDirectory(inspectionId);
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _nextDocumentNumberForDate(DateTime date) {
    final dayStamp = DateFormat('yyyyMMdd').format(date);
    final matches = _inspections
        .where((item) => item.documentNumber.startsWith('$dayStamp-'))
        .length;
    final sequence = matches + 1;
    return '$dayStamp-${sequence.toString().padLeft(4, '0')}';
  }

  String _makeId(String documentNumber) {
    return 'inspection_${documentNumber.replaceAll('-', '_')}';
  }

  InspectionSummary _summaryFromRecord(InspectionRecord record) {
    final sections = List<InspectionSectionProgress>.of(record.sections)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return InspectionSummary(
      id: record.id,
      documentNumber: record.documentNumber,
      customer: record.customer,
      workOrderNumber: record.workOrderNumber,
      customerReference: record.customerReference,
      assetName: record.assetName,
      siteLocation: record.siteLocation,
      technicianName: record.technicianName,
      servicingShop: record.servicingShop,
      inspectionDateTime: record.inspectionDateTime,
      createdAt: record.createdAt,
      status: record.status,
      sections: sections
          .map((section) {
            final sectionPhotos = record.photos
                .where((photo) => photo.sectionKey == section.sectionKey)
                .length;
            final flagged = record.responses
                .where(
                  (response) =>
                      response.sectionKey == section.sectionKey &&
                      (response.isFlagged ||
                          (response.conditionRating?.isFlagged ?? false)),
                )
                .length;
            return InspectionSectionView(
              key: section.sectionKey,
              title: section.title,
              completionState: section.completionState,
              summary: _sectionSummary(section.completionState, flagged),
              photoCount: sectionPhotos,
              flaggedCount: flagged,
              criticalWarning: record.responses.any(
                (response) =>
                    response.sectionKey == section.sectionKey &&
                    response.conditionRating ==
                        ConditionRating.criticalOutOfService,
              ),
            );
          })
          .toList(growable: false),
      actionItems: record.actionItems.map(_actionViewFromRecord).toList(),
      photos: record.photos.map(_photoViewFromRecord).toList(),
      flaggedCount: record.flaggedItemCount,
      atRiskCount: record.atRiskCount,
      unsatisfactoryCount: record.unsatisfactoryCount,
      criticalCount: record.criticalCount,
      photoCount: record.photoCount,
      lastUpdatedAt: record.updatedAt,
      completedAt: record.completedAt,
      emailedAt: record.emailedAt,
      finalTechComments: record.finalTechComments,
      criticalAcknowledged: record.criticalAcknowledged,
      generatedPdfPath: record.generatedPdfPath,
    );
  }

  String _sectionSummary(SectionCompletionState state, int flaggedCount) {
    if (flaggedCount > 0) {
      return '$flaggedCount flagged item${flaggedCount == 1 ? '' : 's'} recorded.';
    }
    return switch (state) {
      SectionCompletionState.complete => 'Section complete.',
      SectionCompletionState.inProgress => 'Section in progress.',
      SectionCompletionState.blocked => 'Section needs attention.',
      SectionCompletionState.notStarted => 'No saved entries yet.',
    };
  }

  InspectionActionItemView _actionViewFromRecord(ActionItem action) {
    return InspectionActionItemView(
      title: action.title,
      description: action.description,
      conditionRating: action.conditionRating ?? ConditionRating.monitorAtRisk,
      sourceSection: action.sourceSectionKey == null
          ? 'Inspection'
          : InspectionSectionKeys.titleFor(action.sourceSectionKey!),
      sourceItem: action.sourceItemKey ?? 'Follow-up',
      partsRequired: action.partsRequired,
      isAutoGenerated: action.isAutoGenerated,
    );
  }

  InspectionPhotoView _photoViewFromRecord(InspectionPhoto photo) {
    return InspectionPhotoView(
      assetPath: photo.filePath,
      caption: photo.caption ?? 'Inspection photo',
      sectionTitle: InspectionSectionKeys.titleFor(photo.sectionKey),
      itemLabel: photo.itemKey,
      capturedAt: photo.capturedAt,
    );
  }

  InspectionRecord _recordFromSummary(InspectionSummary summary) {
    return InspectionRecord(
      id: summary.id,
      documentNumber: summary.documentNumber,
      status: summary.status,
      customer: summary.customer,
      workOrderNumber: summary.workOrderNumber,
      customerReference: summary.customerReference,
      assetName: summary.assetName,
      hpuAssetIdName: summary.assetName,
      siteLocation: summary.siteLocation,
      technicianName: summary.technicianName,
      servicingShop: summary.servicingShop,
      inspectionDateTime: summary.inspectionDateTime,
      createdAt: summary.createdAt,
      updatedAt: summary.lastUpdatedAt,
      completedAt: summary.completedAt,
      emailedAt: summary.emailedAt,
      finalTechComments: summary.finalTechComments ?? '',
      criticalAcknowledged: summary.criticalAcknowledged,
      generatedPdfPath: summary.generatedPdfPath,
    );
  }

  InspectionReportData _reportDataFromRecord(InspectionRecord record) {
    final sections = InspectionSectionKeys.ordered
        .map((descriptor) {
          final responses = record.responses
              .where((response) => response.sectionKey == descriptor.key)
              .map((response) {
                return InspectionReportItem(
                  label: response.itemLabel,
                  value:
                      response.value ?? response.conditionRating?.label ?? '',
                  conditionRating: _reportRating(response.conditionRating),
                  comment: response.comment,
                  photos: _reportPhotosForItem(record, response.itemKey),
                );
              })
              .toList(growable: true);

          if (descriptor.key == InspectionSectionKeys.componentTracking) {
            responses.addAll(
              record.componentEntries.map(
                (entry) => InspectionReportItem(
                  label: entry.componentType,
                  value: entry.modelPartNumber ?? '',
                  conditionRating: _reportRating(entry.conditionRating),
                  comment: entry.notes,
                ),
              ),
            );
          }
          if (descriptor.key ==
              InspectionSectionKeys.hoseConnectionInspection) {
            responses.addAll(
              record.hoseEntries.map(
                (entry) => InspectionReportItem(
                  label: entry.hoseNameLocation ?? 'Hose entry',
                  value: entry.failureType?.label ?? '',
                  comment: entry.notes ?? entry.partsNeeded,
                  tags: [
                    if ((entry.replacementPartNumbers ?? '').trim().isNotEmpty)
                      entry.replacementPartNumbers!,
                  ],
                ),
              ),
            );
          }
          if (descriptor.key ==
              InspectionSectionKeys.filtrationBreatherService) {
            responses.addAll(
              record.filterEntries.map(
                (entry) => InspectionReportItem(
                  label: entry.filterName ?? 'Filter entry',
                  value: entry.partNumber ?? '',
                  conditionRating: _reportRating(entry.conditionRating),
                  comment: entry.notes,
                ),
              ),
            );
          }

          return InspectionReportSection(
            key: descriptor.key,
            title: descriptor.title,
            items: responses,
          );
        })
        .toList(growable: false);

    return InspectionReportData(
      documentNumber: record.documentNumber,
      customer: record.customer,
      workOrderNumber: record.workOrderNumber,
      customerReference: record.customerReference,
      assetName: record.assetName,
      siteLocation: record.siteLocation,
      technicianName: record.technicianName,
      servicingShop: record.servicingShop,
      inspectionDateTime: record.inspectionDateTime,
      createdAt: record.createdAt,
      completedAt: record.completedAt,
      emailedAt: record.emailedAt,
      status: _reportStatus(record.status),
      sections: sections,
      finalTechComments: record.finalTechComments,
      criticalAcknowledged: record.criticalAcknowledged,
      signature: (record.signatureFilePath ?? '').trim().isEmpty
          ? null
          : InspectionReportSignature(
              filePath: record.signatureFilePath,
              signerName: record.technicianName,
              signedAt: record.completedAt ?? record.updatedAt,
            ),
      customerSignature: (record.customerSignatureFilePath ?? '').trim().isEmpty
          ? null
          : InspectionReportSignature(
              filePath: record.customerSignatureFilePath,
              signerName: record.customer,
              signedAt: record.completedAt ?? record.updatedAt,
            ),
      actionItems: record.actionItems
          .map(
            (action) => InspectionReportActionItem(
              title: action.title,
              description: action.description,
              sourceSection: action.sourceSectionKey == null
                  ? null
                  : InspectionSectionKeys.titleFor(action.sourceSectionKey!),
              sourceItem: action.sourceItemKey,
              partsRequired: action.partsRequired,
              isAutoGenerated: action.isAutoGenerated,
              conditionRating: _reportRating(action.conditionRating),
            ),
          )
          .toList(growable: false),
      branding: const InspectionReportBranding(
        companyName: 'CTS Fluid Power',
        logoAssetPath: AppConstants.placeholderLogoAsset,
      ),
    );
  }

  List<InspectionReportPhoto> _reportPhotosForItem(
    InspectionRecord record,
    String itemKey,
  ) {
    return record
        .photosForItem(itemKey)
        .map(
          (photo) => InspectionReportPhoto(
            filePath: photo.filePath,
            caption: photo.caption ?? 'Inspection photo',
            sectionTitle: InspectionSectionKeys.titleFor(photo.sectionKey),
            itemLabel: photo.itemKey,
            capturedAt: photo.capturedAt,
            sortOrder: photo.sortOrder,
          ),
        )
        .toList(growable: false);
  }

  InspectionReportStatus _reportStatus(InspectionStatus status) {
    return switch (status) {
      InspectionStatus.draft => InspectionReportStatus.draft,
      InspectionStatus.inProgress => InspectionReportStatus.inProgress,
      InspectionStatus.complete => InspectionReportStatus.complete,
      InspectionStatus.emailed => InspectionReportStatus.emailed,
    };
  }

  ReportConditionRating? _reportRating(ConditionRating? rating) {
    return switch (rating) {
      ConditionRating.satisfactory => ReportConditionRating.satisfactory,
      ConditionRating.monitorAtRisk => ReportConditionRating.monitor,
      ConditionRating.unsatisfactory => ReportConditionRating.unsatisfactory,
      ConditionRating.criticalOutOfService => ReportConditionRating.critical,
      null => null,
    };
  }

  static List<InspectionSummary> _seedInspections() {
    final today = DateTime(2026, 4, 20, 8, 30);
    final yesterday = today.subtract(const Duration(days: 1));
    final inspection1 = InspectionSummary(
      id: 'inspection_20260420_0001',
      documentNumber: '20260420-0001',
      customer: 'Moraine Quarry',
      workOrderNumber: 'WO-48912',
      customerReference: 'PO-55412',
      assetName: 'HPU-12 Main Press',
      siteLocation: 'East Pit Service Bay',
      technicianName: 'R. Ellis',
      servicingShop: 'CTS Edmonton Service',
      inspectionDateTime: today,
      createdAt: today,
      status: InspectionStatus.complete,
      sections: _defaultSections(
        atRisk: 1,
        unsat: 1,
        critical: 0,
        photoCount: 5,
      ),
      actionItems: [
        InspectionActionItemView(
          title: 'Replace return hose at manifold',
          description:
              'Cracking near the fitting on hose H-12 was flagged during the inspection.',
          conditionRating: ConditionRating.unsatisfactory,
          sourceSection: 'Hose & Connection Inspection',
          sourceItem: 'Hose replacement entry',
          partsRequired: 'Hose assembly, two JIC fittings, crimp sleeves',
        ),
      ],
      photos: [
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_1.jpg',
          caption: 'As-found unit overview',
          sectionTitle: 'Job & Asset Identification',
          itemLabel: 'HPU wide shot',
          capturedAt: DateTime(2026, 4, 20, 8, 45),
        ),
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_2.jpg',
          caption: 'Tank nameplate close-up',
          sectionTitle: 'Component Tracking',
          itemLabel: 'Main Pump',
          capturedAt: DateTime(2026, 4, 20, 9, 10),
        ),
      ],
      flaggedCount: 2,
      atRiskCount: 1,
      unsatisfactoryCount: 1,
      criticalCount: 0,
      photoCount: 5,
      lastUpdatedAt: today.add(const Duration(minutes: 32)),
      completedAt: today.add(const Duration(hours: 1, minutes: 14)),
      finalTechComments:
          'Unit operating within service limits after hose replacement planning.',
      generatedPdfPath:
          '/storage/emulated/0/Download/CTS_Fluid_Power_Inspection_Report_20260420-0001.pdf',
    );

    final inspection2 = InspectionSummary(
      id: 'inspection_20260420_0002',
      documentNumber: '20260420-0002',
      customer: 'North Basin Processing',
      workOrderNumber: 'WO-48921',
      customerReference: 'JOB-7745',
      assetName: 'Transfer Pump Skid 04',
      siteLocation: 'North Tank Farm',
      technicianName: 'K. Morgan',
      servicingShop: 'CTS Calgary Service',
      inspectionDateTime: today.add(const Duration(hours: 2)),
      createdAt: today.add(const Duration(hours: 2)),
      status: InspectionStatus.emailed,
      sections: _defaultSections(
        atRisk: 2,
        unsat: 1,
        critical: 1,
        photoCount: 7,
      ),
      actionItems: [
        InspectionActionItemView(
          title: 'Lockout/Tagout before restart',
          description:
              'Critical tank integrity issue requires isolation until corrective work is complete.',
          conditionRating: ConditionRating.criticalOutOfService,
          sourceSection: 'Fluid & Tank Service',
          sourceItem: 'Tank integrity',
          partsRequired: 'Tank repair kit, lockout hardware',
        ),
        InspectionActionItemView(
          title: 'Replace breather element',
          description:
              'Breather housing contamination noted; element replacement recommended.',
          conditionRating: ConditionRating.monitorAtRisk,
          sourceSection: 'Filtration & Breather Service',
          sourceItem: 'Breather replaced?',
          partsRequired: 'Breather element 12-7781',
        ),
      ],
      photos: [
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_1.jpg',
          caption: 'Critical tank corrosion',
          sectionTitle: 'Fluid & Tank Service',
          itemLabel: 'Tank integrity',
          capturedAt: DateTime(2026, 4, 20, 10, 12),
        ),
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_2.jpg',
          caption: 'Gauges under load',
          sectionTitle: 'Operational Data / System Test',
          itemLabel: 'System test',
          capturedAt: DateTime(2026, 4, 20, 10, 18),
        ),
      ],
      flaggedCount: 3,
      atRiskCount: 2,
      unsatisfactoryCount: 1,
      criticalCount: 1,
      photoCount: 7,
      lastUpdatedAt: today.add(const Duration(hours: 2, minutes: 55)),
      completedAt: today.add(const Duration(hours: 3, minutes: 10)),
      emailedAt: today.add(const Duration(hours: 3, minutes: 42)),
      criticalAcknowledged: true,
      generatedPdfPath:
          '/storage/emulated/0/Download/CTS_Fluid_Power_Inspection_Report_20260420-0002.pdf',
    );

    final inspection3 = InspectionSummary(
      id: 'inspection_20260419_0001',
      documentNumber: '20260419-0001',
      customer: 'Prairie Rail Services',
      workOrderNumber: 'WO-48888',
      customerReference: 'PR-1182',
      assetName: 'Hydraulic Lift Cart 2',
      siteLocation: 'Maintenance Yard',
      technicianName: 'T. Singh',
      servicingShop: 'CTS Red Deer Service',
      inspectionDateTime: yesterday,
      createdAt: yesterday,
      status: InspectionStatus.inProgress,
      sections: _defaultSections(
        atRisk: 0,
        unsat: 0,
        critical: 0,
        photoCount: 2,
      ),
      actionItems: [],
      photos: [
        InspectionPhotoView(
          assetPath: 'assets/demo/sample_photo_1.jpg',
          caption: 'Asset identification photo',
          sectionTitle: 'Job & Asset Identification',
          itemLabel: 'HPU wide shot',
          capturedAt: DateTime(2026, 4, 19, 15, 01),
        ),
      ],
      flaggedCount: 0,
      atRiskCount: 0,
      unsatisfactoryCount: 0,
      criticalCount: 0,
      photoCount: 2,
      lastUpdatedAt: yesterday.add(const Duration(hours: 1, minutes: 45)),
    );

    return [inspection2, inspection1, inspection3];
  }

  static List<InspectionSectionView> _defaultSections({
    int atRisk = 0,
    int unsat = 0,
    int critical = 0,
    int photoCount = 0,
  }) {
    return [
      InspectionSectionView(
        key: InspectionSectionKeys.jobAssetIdentification,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .jobAssetIdentification]!,
        completionState: SectionCompletionState.complete,
        summary: 'Header complete and photos captured.',
        photoCount: photoCount > 0 ? 2 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.componentTracking,
        title:
            inspectionSectionTitles[InspectionSectionKeys.componentTracking]!,
        completionState: SectionCompletionState.complete,
        summary: 'Nameplates and component notes captured.',
        photoCount: photoCount > 1 ? 2 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.fluidTankService,
        title: inspectionSectionTitles[InspectionSectionKeys.fluidTankService]!,
        completionState: critical > 0
            ? SectionCompletionState.blocked
            : atRisk > 0 || unsat > 0
            ? SectionCompletionState.inProgress
            : SectionCompletionState.complete,
        summary: critical > 0
            ? 'Critical tank warning acknowledged.'
            : atRisk > 0 || unsat > 0
            ? 'Flagged fluid service items need follow-up.'
            : 'Fluid condition is within tolerance.',
        photoCount: photoCount > 2 ? 1 : 0,
        flaggedCount: atRisk + unsat + critical,
        criticalWarning: critical > 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.hoseConnectionInspection,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .hoseConnectionInspection]!,
        completionState: atRisk > 0 || unsat > 0
            ? SectionCompletionState.inProgress
            : SectionCompletionState.complete,
        summary: 'Hose replacement entries and fitting notes documented.',
        photoCount: photoCount > 3 ? 1 : 0,
        flaggedCount: atRisk > 0 ? 1 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.filtrationBreatherService,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .filtrationBreatherService]!,
        completionState: atRisk > 0
            ? SectionCompletionState.inProgress
            : SectionCompletionState.complete,
        summary: 'Filter replacement statuses captured.',
        photoCount: photoCount > 4 ? 1 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.operationalDataSystemTest,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .operationalDataSystemTest]!,
        completionState: SectionCompletionState.complete,
        summary: 'System test readings stored.',
        photoCount: photoCount > 5 ? 1 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.followUpRepairsQuoting,
        title:
            inspectionSectionTitles[InspectionSectionKeys
                .followUpRepairsQuoting]!,
        completionState: atRisk > 0
            ? SectionCompletionState.inProgress
            : SectionCompletionState.complete,
        summary: 'Quoted parts and follow-up actions are tracked.',
        photoCount: photoCount > 6 ? 1 : 0,
      ),
      InspectionSectionView(
        key: InspectionSectionKeys.reviewCompletion,
        title: inspectionSectionTitles[InspectionSectionKeys.reviewCompletion]!,
        completionState: atRisk > 0 || unsat > 0 || critical > 0
            ? SectionCompletionState.blocked
            : SectionCompletionState.complete,
        summary: 'Ready for signoff when validation is clear.',
        photoCount: 0,
        flaggedCount: atRisk + unsat + critical,
        criticalWarning: critical > 0,
      ),
    ];
  }
}

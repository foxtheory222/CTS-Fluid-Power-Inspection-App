import 'dart:io';

import 'package:flutter/material.dart';

import '../data/models/inspection_enums.dart';
import '../data/models/inspection_models.dart';
import '../data/repositories/inspection_repository.dart';
import '../features/pdf_report/inspection_report_mapper.dart';
import '../services/email_service.dart';
import '../services/pdf_service.dart';
import '../services/photo_service.dart';
import 'constants.dart';
import 'file_utils.dart';
import 'theme.dart';
import 'validators.dart';
import 'workspace_models.dart';

class AppWorkspaceController extends ChangeNotifier {
  AppWorkspaceController({
    required InspectionRepository repository,
    required PdfService pdfService,
    required PhotoService photoService,
    required EmailService emailService,
  }) : _repository = repository,
       _pdfService = pdfService,
       _photoService = photoService,
       _emailService = emailService {
    refresh();
  }

  final InspectionRepository _repository;
  final PdfService _pdfService;
  final PhotoService _photoService;
  final EmailService _emailService;

  final List<InspectionRecord> _records = <InspectionRecord>[];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  InspectionStatus? _statusFilter;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  InspectionStatus? get statusFilter => _statusFilter;
  PhotoService get photoService => _photoService;

  List<InspectionRecord> get inspectionRecords => List.unmodifiable(_records);

  List<InspectionSummary> get inspections =>
      _records.map(_toSummary).toList(growable: false);

  List<InspectionSummary> get filteredInspections {
    final String query = _searchQuery.trim().toLowerCase();
    return inspections
        .where((InspectionSummary inspection) {
          final bool matchesQuery =
              query.isEmpty || inspection.searchableText.contains(query);
          final bool matchesStatus =
              _statusFilter == null || inspection.status == _statusFilter;
          return matchesQuery && matchesStatus;
        })
        .toList(growable: false);
  }

  List<DashboardMetric> get dashboardMetrics {
    final List<InspectionRecord> source = _records;
    final int photoTotal = source.fold<int>(
      0,
      (int sum, InspectionRecord item) => sum + item.photoCount,
    );
    return <DashboardMetric>[
      DashboardMetric(
        label: 'Draft',
        value: source
            .where(
              (InspectionRecord item) => item.status == InspectionStatus.draft,
            )
            .length
            .toString(),
        icon: Icons.description_outlined,
        color: CtsPalette.slate,
        subtitle: 'Saved locally and ready to continue',
      ),
      DashboardMetric(
        label: 'Complete',
        value: source
            .where(
              (InspectionRecord item) =>
                  item.status == InspectionStatus.complete,
            )
            .length
            .toString(),
        icon: Icons.verified_outlined,
        color: CtsPalette.success,
        subtitle: 'Validated and signed',
      ),
      DashboardMetric(
        label: 'Emailed',
        value: source
            .where(
              (InspectionRecord item) =>
                  item.status == InspectionStatus.emailed,
            )
            .length
            .toString(),
        icon: Icons.mark_email_read_outlined,
        color: CtsPalette.info,
        subtitle: 'Shared from the tablet',
      ),
      DashboardMetric(
        label: 'Critical',
        value: source
            .where((InspectionRecord item) => item.hasCriticalItems)
            .length
            .toString(),
        icon: Icons.warning_amber_rounded,
        color: CtsPalette.danger,
        subtitle: 'Requires LOTO acknowledgement',
      ),
      DashboardMetric(
        label: 'Photos',
        value: photoTotal.toString(),
        icon: Icons.photo_library_outlined,
        color: CtsPalette.secondaryBlue,
        subtitle: 'Stored on this device',
      ),
    ];
  }

  InspectionSummary? inspectionById(String id) {
    final InspectionRecord? record = recordById(id);
    if (record == null) {
      return null;
    }
    return _toSummary(record);
  }

  InspectionRecord? recordById(String id) {
    for (final InspectionRecord record in _records) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  List<InspectionSummary> get recentInspections {
    final List<InspectionRecord> copy = List<InspectionRecord>.of(_records)
      ..sort(
        (InspectionRecord a, InspectionRecord b) =>
            b.updatedAt.compareTo(a.updatedAt),
      );
    return copy.take(6).map(_toSummary).toList(growable: false);
  }

  List<InspectionActionItemView> get openActionItems =>
      _records.expand(_actionItemViewsForRecord).toList(growable: false);

  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final List<InspectionRecord> records = await _repository.allInspections();
      _records
        ..clear()
        ..addAll(records);
      _sortRecords();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<InspectionRecord?> loadInspectionRecord(String id) async {
    final InspectionRecord? local = recordById(id);
    if (local != null) {
      return local.clone();
    }
    final InspectionRecord? loaded = await _repository.getInspection(id);
    if (loaded != null) {
      _upsertRecord(loaded, notify: true);
      return loaded.clone();
    }
    return null;
  }

  Future<InspectionRecord> createInspection() async {
    final InspectionRecord created = await _repository.createInspection();
    _upsertRecord(created, notify: true);
    return created.clone();
  }

  Future<InspectionRecord> duplicateInspection(InspectionSummary source) {
    return duplicateInspectionById(source.id);
  }

  Future<InspectionRecord> duplicateInspectionById(String id) async {
    final InspectionRecord source =
        await loadInspectionRecord(id) ??
        (throw StateError('Inspection not found: $id'));
    final InspectionRecord duplicate = await _repository.duplicateInspection(
      source,
    );
    _upsertRecord(duplicate, notify: true);
    return duplicate.clone();
  }

  Future<InspectionRecord> saveInspection(InspectionRecord inspection) async {
    final InspectionRecord saved = await _repository.saveInspection(
      inspection.clone(),
    );
    _upsertRecord(saved, notify: true);
    return saved.clone();
  }

  Future<File> generatePdf(InspectionRecord inspection) async {
    final Directory outputDirectory =
        await FileUtils.inspectionReportsDirectory(inspection.id);
    final File file = await _pdfService.generateInspectionReportFile(
      InspectionReportMapper.fromInspection(inspection),
      outputDirectory: outputDirectory,
    );
    final InspectionRecord updated = inspection.clone();
    updated.generatedPdfPath = file.path;
    await saveInspection(updated);
    return file;
  }

  Future<EmailHandoffResult> sharePdf(InspectionRecord inspection) async {
    File pdfFile;
    if ((inspection.generatedPdfPath ?? '').trim().isEmpty) {
      pdfFile = await generatePdf(inspection);
    } else {
      pdfFile = File(inspection.generatedPdfPath!);
      if (!await pdfFile.exists()) {
        pdfFile = await generatePdf(inspection);
      }
    }

    return _emailService.handoffPdf(
      request: EmailHandoffRequest(
        pdfFile: pdfFile,
        subject: '${AppConstants.reportTitle} ${inspection.documentNumber}'
            .trim(),
        body:
            'Attached is the ${AppConstants.reportTitle} for ${inspection.customer}.',
        customer: inspection.customer,
      ),
    );
  }

  Future<InspectionRecord> markEmailed(InspectionRecord inspection) async {
    final InspectionRecord saved = await _repository.markEmailed(
      inspection.clone(),
    );
    _upsertRecord(saved, notify: true);
    return saved.clone();
  }

  Future<void> deleteInspectionById(String id) async {
    final InspectionRecord? local = recordById(id);
    final InspectionRecord? loaded =
        local ?? await _repository.getInspection(id);
    await _repository.deleteInspection(id);
    _records.removeWhere((InspectionRecord record) => record.id == id);
    if (loaded != null) {
      await _deleteInspectionFiles(loaded);
    }
    notifyListeners();
  }

  ValidationResult validate(InspectionRecord inspection) {
    return InspectionValidator.validateForCompletion(inspection);
  }

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

  void _upsertRecord(InspectionRecord record, {required bool notify}) {
    final int index = _records.indexWhere(
      (InspectionRecord existing) => existing.id == record.id,
    );
    if (index == -1) {
      _records.add(record);
    } else {
      _records[index] = record;
    }
    _sortRecords();
    if (notify) {
      notifyListeners();
    }
  }

  void _sortRecords() {
    _records.sort(
      (InspectionRecord a, InspectionRecord b) =>
          b.updatedAt.compareTo(a.updatedAt),
    );
  }

  InspectionSummary _toSummary(InspectionRecord record) {
    final List<InspectionPhotoView> photos = record.photos
        .map(
          (InspectionPhoto photo) => InspectionPhotoView(
            filePath: photo.filePath,
            caption: (photo.caption ?? '').trim().isEmpty
                ? _labelForItem(record, photo.itemKey)
                : photo.caption!,
            sectionTitle: InspectionSectionKeys.titleFor(photo.sectionKey),
            itemLabel: _labelForItem(record, photo.itemKey),
            capturedAt: photo.capturedAt,
          ),
        )
        .toList(growable: false);

    final List<InspectionSectionView> sections = record.sections
        .map(
          (InspectionSectionProgress section) => InspectionSectionView(
            key: section.sectionKey,
            title: section.title,
            completionState: section.completionState,
            summary: _sectionSummary(record, section.sectionKey),
            photoCount: record.photos
                .where(
                  (InspectionPhoto photo) =>
                      photo.sectionKey == section.sectionKey,
                )
                .length,
            flaggedCount: _flaggedCountForSection(record, section.sectionKey),
            criticalWarning:
                _criticalCountForSection(record, section.sectionKey) > 0,
          ),
        )
        .toList(growable: false);

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
      sections: sections,
      actionItems: _actionItemViewsForRecord(record),
      photos: photos,
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

  List<InspectionActionItemView> _actionItemViewsForRecord(
    InspectionRecord record,
  ) {
    return record.actionItems
        .map(
          (ActionItem item) => InspectionActionItemView(
            title: item.title,
            description: item.description,
            conditionRating:
                item.conditionRating ?? ConditionRating.monitorAtRisk,
            sourceSection: item.sourceSectionKey == null
                ? 'Manual action'
                : InspectionSectionKeys.titleFor(item.sourceSectionKey!),
            sourceItem: _labelForItem(record, item.sourceItemKey ?? ''),
            partsRequired: item.partsRequired,
            isAutoGenerated: item.isAutoGenerated,
          ),
        )
        .toList(growable: false);
  }

  String _sectionSummary(InspectionRecord record, String sectionKey) {
    final int photoCount = record.photos
        .where((InspectionPhoto photo) => photo.sectionKey == sectionKey)
        .length;
    final int flaggedCount = _flaggedCountForSection(record, sectionKey);
    final int criticalCount = _criticalCountForSection(record, sectionKey);
    if (criticalCount > 0) {
      return '$criticalCount critical item${criticalCount == 1 ? '' : 's'} need immediate attention.';
    }
    if (flaggedCount > 0) {
      return '$flaggedCount flagged item${flaggedCount == 1 ? '' : 's'} recorded in this section.';
    }
    if (photoCount > 0) {
      return '$photoCount photo${photoCount == 1 ? '' : 's'} attached.';
    }
    if (sectionKey == InspectionSectionKeys.reviewCompletion) {
      final int issueCount = validate(record).issues.length;
      return issueCount == 0
          ? 'Ready for completion.'
          : '$issueCount completion issue${issueCount == 1 ? '' : 's'} remaining.';
    }
    return 'No issues recorded yet.';
  }

  int _flaggedCountForSection(InspectionRecord record, String sectionKey) {
    final int responseFlags = record.responses.where((
      InspectionResponse response,
    ) {
      return response.sectionKey == sectionKey &&
          (response.isFlagged ||
              (response.conditionRating?.isFlagged ?? false));
    }).length;
    final int hoseFlags =
        sectionKey == InspectionSectionKeys.hoseConnectionInspection
        ? record.hoseEntries.where((HoseEntry entry) => entry.hasFailure).length
        : 0;
    final int filterFlags =
        sectionKey == InspectionSectionKeys.filtrationBreatherService
        ? record.filterEntries.where((FilterEntry entry) {
            return entry.replacedStatus == FilterReplacementStatus.no ||
                (entry.conditionRating?.isFlagged ?? false);
          }).length
        : 0;
    return responseFlags + hoseFlags + filterFlags;
  }

  int _criticalCountForSection(InspectionRecord record, String sectionKey) {
    return record.responses.where((InspectionResponse response) {
      return response.sectionKey == sectionKey &&
          response.conditionRating == ConditionRating.criticalOutOfService;
    }).length;
  }

  String _labelForItem(InspectionRecord record, String itemKey) {
    if (itemKey.isEmpty) {
      return 'Inspection item';
    }
    if (itemKey.startsWith('hose:')) {
      final String hoseId = itemKey.substring('hose:'.length);
      final HoseEntry? entry = record.hoseEntries.cast<HoseEntry?>().firstWhere(
        (HoseEntry? hose) => hose?.id == hoseId,
        orElse: () => null,
      );
      if (entry == null) {
        return 'Hose entry';
      }
      return (entry.hoseNameLocation ?? '').trim().isEmpty
          ? 'Hose entry'
          : entry.hoseNameLocation!;
    }
    if (itemKey.startsWith('filter:')) {
      final String filterId = itemKey.substring('filter:'.length);
      final FilterEntry? entry = record.filterEntries
          .cast<FilterEntry?>()
          .firstWhere(
            (FilterEntry? filter) => filter?.id == filterId,
            orElse: () => null,
          );
      if (entry == null) {
        return 'Filter entry';
      }
      return (entry.filterName ?? '').trim().isEmpty
          ? 'Filter entry'
          : entry.filterName!;
    }
    if (itemKey.startsWith('component:')) {
      final String componentId = itemKey.substring('component:'.length);
      final ComponentEntry? entry = record.componentEntries
          .cast<ComponentEntry?>()
          .firstWhere(
            (ComponentEntry? component) => component?.id == componentId,
            orElse: () => null,
          );
      if (entry == null) {
        return 'Component photo';
      }
      return entry.componentType;
    }
    if (itemKey.startsWith('required_item:')) {
      final String requiredId = itemKey.substring('required_item:'.length);
      final RequiredItemEntry? entry = record.requiredItems
          .cast<RequiredItemEntry?>()
          .firstWhere(
            (RequiredItemEntry? item) => item?.id == requiredId,
            orElse: () => null,
          );
      if (entry == null) {
        return 'Required item';
      }
      return (entry.itemName ?? '').trim().isEmpty
          ? 'Required item'
          : entry.itemName!;
    }
    final InspectionResponse? response = record.responses
        .cast<InspectionResponse?>()
        .firstWhere(
          (InspectionResponse? item) => item?.itemKey == itemKey,
          orElse: () => null,
        );
    return response?.itemLabel ?? itemKey.replaceAll('_', ' ');
  }

  Future<void> _deleteInspectionFiles(InspectionRecord inspection) async {
    final Directory inspectionDirectory = await FileUtils.inspectionDirectory(
      inspection.id,
    );
    if (await inspectionDirectory.exists()) {
      await inspectionDirectory.delete(recursive: true);
    }

    final Set<String> looseFiles = <String>{
      if ((inspection.generatedPdfPath ?? '').trim().isNotEmpty)
        inspection.generatedPdfPath!,
      if ((inspection.signatureFilePath ?? '').trim().isNotEmpty)
        inspection.signatureFilePath!,
    };

    for (final String path in looseFiles) {
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}

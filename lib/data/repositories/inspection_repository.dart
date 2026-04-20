import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../services/document_number_service.dart';
import '../database/app_database.dart';
import '../models/inspection_enums.dart';
import '../models/inspection_models.dart';

class InspectionRepository {
  InspectionRepository({
    required AppDatabase database,
    required DocumentNumberService documentNumberService,
    Uuid? uuid,
  }) : _database = database,
       _documentNumberService = documentNumberService,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final DocumentNumberService _documentNumberService;
  final Uuid _uuid;

  Future<InspectionRecord> createInspection({
    DateTime? createdAt,
    InspectionRecord? duplicateSource,
  }) async {
    final Database db = await _database.open();
    final DateTime now = createdAt ?? DateTime.now();
    final String inspectionId = _uuid.v4();
    final String documentNumber = await _documentNumberService
        .nextDocumentNumber(db, now);

    final InspectionRecord record = InspectionRecord(
      id: inspectionId,
      documentNumber: documentNumber,
      status: InspectionStatus.draft,
      customer: duplicateSource?.customer ?? '',
      workOrderNumber: duplicateSource?.workOrderNumber ?? '',
      customerReference: duplicateSource?.customerReference ?? '',
      assetName: duplicateSource?.assetName ?? '',
      hpuAssetIdName: duplicateSource?.hpuAssetIdName ?? '',
      siteLocation: duplicateSource?.siteLocation ?? '',
      technicianName: duplicateSource?.technicianName ?? '',
      servicingShop: duplicateSource?.servicingShop ?? '',
      inspectionDateTime: now,
      createdAt: now,
      updatedAt: now,
      sections: _defaultSections(inspectionId),
      componentEntries: _defaultComponents(inspectionId),
      filterEntries: <FilterEntry>[],
      responses: <InspectionResponse>[],
      photos: <InspectionPhoto>[],
      actionItems: <ActionItem>[],
      hoseEntries: <HoseEntry>[],
      requiredItems: <RequiredItemEntry>[],
    );

    _refreshSectionStates(record);
    record.status = InspectionValidator.deriveStatus(record);
    await saveInspection(record);
    return record;
  }

  Future<InspectionRecord> duplicateInspection(
    InspectionRecord source, {
    DateTime? createdAt,
  }) {
    return createInspection(createdAt: createdAt, duplicateSource: source);
  }

  Future<InspectionRecord> saveInspection(InspectionRecord inspection) async {
    final Database db = await _database.open();
    final InspectionRecord? existing = await getInspection(inspection.id);
    final DateTime now = DateTime.now();
    inspection.updatedAt = now;
    final bool editedAfterEmail =
        existing?.emailedAt != null &&
        inspection.emailedAt == existing!.emailedAt;
    if (editedAfterEmail) {
      inspection.emailedAt = null;
    }
    _syncAutoActionItems(inspection);
    _refreshSectionStates(inspection);
    final ValidationResult validation =
        InspectionValidator.validateForCompletion(inspection);
    if (inspection.emailedAt == null &&
        validation.isValid &&
        (inspection.signatureFilePath ?? '').trim().isNotEmpty) {
      inspection.completedAt ??= now;
    } else if (inspection.emailedAt == null) {
      inspection.completedAt = null;
    }
    inspection.status = InspectionValidator.deriveStatus(inspection);

    await db.insert('inspections', <String, Object?>{
      'id': inspection.id,
      'document_number': inspection.documentNumber,
      'status': inspection.status.value,
      'customer': inspection.customer,
      'work_order_number': inspection.workOrderNumber,
      'asset_name': inspection.assetName,
      'technician_name': inspection.technicianName,
      'customer_reference': inspection.customerReference,
      'site_location': inspection.siteLocation,
      'servicing_shop': inspection.servicingShop,
      'inspection_date_time': inspection.inspectionDateTime.toIso8601String(),
      'created_at': inspection.createdAt.toIso8601String(),
      'updated_at': inspection.updatedAt.toIso8601String(),
      'completed_at': inspection.completedAt?.toIso8601String(),
      'emailed_at': inspection.emailedAt?.toIso8601String(),
      'generated_pdf_path': inspection.generatedPdfPath,
      'has_critical': inspection.hasCriticalItems ? 1 : 0,
      'flagged_count': inspection.flaggedItemCount,
      'photo_count': inspection.photoCount,
      'payload_json': inspection.toEncodedJson(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return inspection;
  }

  Future<InspectionRecord?> getInspectionByDocumentNumber(
    String documentNumber,
  ) async {
    final Database db = await _database.open();
    final List<Map<String, Object?>> rows = await db.query(
      'inspections',
      where: 'document_number = ?',
      whereArgs: <Object?>[documentNumber],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _rowToInspection(rows.first);
  }

  Future<InspectionRecord> markEmailed(InspectionRecord inspection) async {
    inspection.emailedAt = DateTime.now();
    inspection.completedAt ??= inspection.emailedAt;
    inspection.status = InspectionStatus.emailed;
    return saveInspection(inspection);
  }

  Future<InspectionRecord?> getInspection(String inspectionId) async {
    final Database db = await _database.open();
    final List<Map<String, Object?>> rows = await db.query(
      'inspections',
      where: 'id = ?',
      whereArgs: <Object?>[inspectionId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _rowToInspection(rows.first);
  }

  Future<List<InspectionRecord>> search(InspectionSearchQuery query) async {
    final Database db = await _database.open();
    final StringBuffer whereBuffer = StringBuffer('1 = 1');
    final List<Object?> args = <Object?>[];

    if (query.term.trim().isNotEmpty) {
      final String like = '%${query.term.trim().toLowerCase()}%';
      whereBuffer.write(
        ' AND (LOWER(work_order_number) LIKE ? OR LOWER(customer) LIKE ? OR '
        'LOWER(asset_name) LIKE ? OR LOWER(document_number) LIKE ? OR '
        'LOWER(technician_name) LIKE ?)',
      );
      args.addAll(<Object?>[like, like, like, like, like]);
    }

    if (query.status != null) {
      whereBuffer.write(' AND status = ?');
      args.add(query.status!.value);
    }

    if (query.startDate != null) {
      whereBuffer.write(' AND inspection_date_time >= ?');
      args.add(query.startDate!.toIso8601String());
    }

    if (query.endDate != null) {
      whereBuffer.write(' AND inspection_date_time <= ?');
      args.add(query.endDate!.toIso8601String());
    }

    final List<Map<String, Object?>> rows = await db.query(
      'inspections',
      where: whereBuffer.toString(),
      whereArgs: args,
      orderBy: 'updated_at DESC',
    );

    return rows.map(_rowToInspection).toList(growable: false);
  }

  Future<List<InspectionRecord>> allInspections() async {
    return search(const InspectionSearchQuery());
  }

  Future<DashboardSummary> dashboardSummary() async {
    final List<InspectionRecord> inspections = await allInspections();
    return DashboardSummary(
      draftCount: inspections
          .where(
            (InspectionRecord item) => item.status == InspectionStatus.draft,
          )
          .length,
      inProgressCount: inspections
          .where(
            (InspectionRecord item) =>
                item.status == InspectionStatus.inProgress,
          )
          .length,
      completeCount: inspections
          .where(
            (InspectionRecord item) => item.status == InspectionStatus.complete,
          )
          .length,
      emailedCount: inspections
          .where(
            (InspectionRecord item) => item.status == InspectionStatus.emailed,
          )
          .length,
      criticalCount: inspections
          .where((InspectionRecord item) => item.hasCriticalItems)
          .length,
      recentInspections: inspections
          .take(AppConstants.recentInspectionLimit)
          .toList(growable: false),
    );
  }

  Future<List<EmailRecipientEntry>> recentRecipients({String? customer}) async {
    final Database db = await _database.open();
    final List<Map<String, Object?>> rows = await db.query(
      'email_recipients',
      where: customer == null ? null : 'customer = ?',
      whereArgs: customer == null ? null : <Object?>[customer],
      orderBy: 'is_customer_default DESC, last_used_at DESC, usage_count DESC',
      limit: AppConstants.recentRecipientLimit,
    );
    return rows
        .map(
          (Map<String, Object?> row) =>
              EmailRecipientEntry.fromJson(<String, dynamic>{
                'id': row['id'],
                'email': row['email'],
                'customer': row['customer'],
                'lastUsedAt': row['last_used_at'],
                'usageCount': row['usage_count'],
                'isCustomerDefault':
                    (row['is_customer_default'] as num).toInt() == 1,
              }),
        )
        .toList(growable: false);
  }

  Future<void> rememberRecipient(
    String email, {
    String? customer,
    bool saveForCustomer = false,
  }) async {
    final Database db = await _database.open();
    final List<Map<String, Object?>> existing = await db.query(
      'email_recipients',
      where: 'email = ? AND COALESCE(customer, \'\') = COALESCE(?, \'\')',
      whereArgs: <Object?>[email, customer],
      limit: 1,
    );

    final DateTime now = DateTime.now();
    if (existing.isEmpty) {
      await db.insert('email_recipients', <String, Object?>{
        'id': _uuid.v4(),
        'email': email,
        'customer': customer,
        'last_used_at': now.toIso8601String(),
        'usage_count': 1,
        'is_customer_default': saveForCustomer ? 1 : 0,
      });
      return;
    }

    final Map<String, Object?> row = existing.first;
    await db.update(
      'email_recipients',
      <String, Object?>{
        'last_used_at': now.toIso8601String(),
        'usage_count': ((row['usage_count'] as num).toInt() + 1),
        'is_customer_default': saveForCustomer
            ? 1
            : (row['is_customer_default'] as num).toInt(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[row['id']],
    );
  }

  Future<bool> documentNumberExists(String documentNumber) async {
    final Database db = await _database.open();
    final List<Map<String, Object?>> rows = await db.query(
      'inspections',
      columns: <String>['id'],
      where: 'document_number = ?',
      whereArgs: <Object?>[documentNumber],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> replaceAllForTests() async {
    final Database db = await _database.open();
    await db.delete('inspections');
    await db.delete('document_sequences');
    await db.delete('email_recipients');
  }

  List<InspectionSectionProgress> _defaultSections(String inspectionId) {
    return InspectionSectionKeys.ordered
        .map(
          (SectionDescriptor descriptor) => InspectionSectionProgress(
            id: '${inspectionId}_${descriptor.key}',
            inspectionId: inspectionId,
            sectionKey: descriptor.key,
            title: descriptor.title,
            sortOrder: descriptor.sortOrder,
            completionState: SectionCompletionState.notStarted,
          ),
        )
        .toList(growable: true);
  }

  List<ComponentEntry> _defaultComponents(String inspectionId) {
    final List<String> componentTypes = <String>[
      'Main Pump',
      'Main Motor',
      'Cooler',
      'Accumulator',
    ];

    return componentTypes
        .map(
          (String type) => ComponentEntry(
            id: _uuid.v4(),
            inspectionId: inspectionId,
            componentType: type,
          ),
        )
        .toList(growable: true);
  }

  void _refreshSectionStates(InspectionRecord inspection) {
    final ValidationResult result = InspectionValidator.validateForCompletion(
      inspection,
    );
    for (final InspectionSectionProgress section in inspection.sections) {
      final bool hasErrors = result.issues.any(
        (ValidationIssue issue) => issue.sectionKey == section.sectionKey,
      );
      final bool hasContent = _sectionHasContent(
        inspection,
        section.sectionKey,
      );
      if (hasErrors && hasContent) {
        section.completionState = SectionCompletionState.blocked;
      } else if (hasErrors) {
        section.completionState = SectionCompletionState.notStarted;
      } else if (hasContent) {
        section.completionState = SectionCompletionState.complete;
      } else {
        section.completionState = SectionCompletionState.notStarted;
      }
    }
  }

  bool _sectionHasContent(InspectionRecord inspection, String sectionKey) {
    if (sectionKey == InspectionSectionKeys.jobAssetIdentification) {
      return inspection.customer.trim().isNotEmpty ||
          inspection.workOrderNumber.trim().isNotEmpty ||
          inspection.assetName.trim().isNotEmpty ||
          inspection.siteLocation.trim().isNotEmpty;
    }
    if (inspection.responses.any(
      (InspectionResponse response) => response.sectionKey == sectionKey,
    )) {
      return true;
    }
    if (inspection.photos.any(
      (InspectionPhoto photo) => photo.sectionKey == sectionKey,
    )) {
      return true;
    }
    if (sectionKey == InspectionSectionKeys.componentTracking) {
      return inspection.componentEntries.any((ComponentEntry entry) {
        return (entry.modelPartNumber ?? '').trim().isNotEmpty ||
            (entry.serialNumber ?? '').trim().isNotEmpty ||
            (entry.notes ?? '').trim().isNotEmpty;
      });
    }
    if (sectionKey == InspectionSectionKeys.hoseConnectionInspection) {
      return inspection.hoseEntries.any((HoseEntry entry) {
        return (entry.hoseNameLocation ?? '').trim().isNotEmpty ||
            entry.failureType != null;
      });
    }
    if (sectionKey == InspectionSectionKeys.filtrationBreatherService) {
      return inspection.filterEntries.any((FilterEntry entry) {
        return (entry.filterName ?? '').trim().isNotEmpty ||
            (entry.partNumber ?? '').trim().isNotEmpty;
      });
    }
    if (sectionKey == InspectionSectionKeys.followUpRepairsQuoting) {
      return inspection.actionItems.isNotEmpty ||
          inspection.requiredItems.isNotEmpty ||
          inspection.finalTechComments.trim().isNotEmpty;
    }
    if (sectionKey == InspectionSectionKeys.reviewCompletion) {
      return inspection.signatureFilePath != null ||
          inspection.completedAt != null;
    }
    return false;
  }

  void _syncAutoActionItems(InspectionRecord inspection) {
    final List<ActionItem> manualItems = inspection.actionItems
        .where((ActionItem item) => !item.isAutoGenerated)
        .toList(growable: true);
    final List<ActionItem> existingAutoItems = inspection.actionItems
        .where((ActionItem item) => item.isAutoGenerated)
        .toList(growable: false);
    final List<ActionItem> refreshedAutoItems = <ActionItem>[];

    for (final InspectionResponse response in inspection.responses) {
      final bool flagged =
          response.isFlagged || (response.conditionRating?.isFlagged ?? false);
      if (!flagged) {
        continue;
      }

      final ActionItem? existing = existingAutoItems
          .cast<ActionItem?>()
          .firstWhere(
            (ActionItem? item) =>
                item?.sourceSectionKey == response.sectionKey &&
                item?.sourceItemKey == response.itemKey,
            orElse: () => null,
          );

      refreshedAutoItems.add(
        ActionItem(
          id: existing?.id ?? _uuid.v4(),
          inspectionId: inspection.id,
          sourceSectionKey: response.sectionKey,
          sourceItemKey: response.itemKey,
          conditionRating: response.conditionRating,
          title: response.itemLabel,
          description:
              existing?.description ??
              _defaultActionDescriptionForResponse(response),
          partsRequired: existing?.partsRequired,
          isAutoGenerated: true,
          createdAt: existing?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    for (final HoseEntry hoseEntry in inspection.hoseEntries) {
      if (!hoseEntry.hasFailure) {
        continue;
      }
      final String sourceItemKey = 'hose:${hoseEntry.id}';
      final ActionItem? existing = existingAutoItems
          .cast<ActionItem?>()
          .firstWhere(
            (ActionItem? item) => item?.sourceItemKey == sourceItemKey,
            orElse: () => null,
          );

      refreshedAutoItems.add(
        ActionItem(
          id: existing?.id ?? _uuid.v4(),
          inspectionId: inspection.id,
          sourceSectionKey: InspectionSectionKeys.hoseConnectionInspection,
          sourceItemKey: sourceItemKey,
          conditionRating: ConditionRating.unsatisfactory,
          title: hoseEntry.hoseNameLocation?.trim().isEmpty ?? true
              ? 'Hose replacement required'
              : hoseEntry.hoseNameLocation!,
          description:
              existing?.description ??
              'Identify the hose, failure type, and parts needed to build the replacement.',
          partsRequired: existing?.partsRequired ?? hoseEntry.partsNeeded,
          isAutoGenerated: true,
          createdAt: existing?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    for (final FilterEntry filterEntry in inspection.filterEntries) {
      if (filterEntry.replacedStatus != FilterReplacementStatus.no &&
          !(filterEntry.conditionRating?.isFlagged ?? false)) {
        continue;
      }
      final String sourceItemKey = 'filter:${filterEntry.id}';
      final ActionItem? existing = existingAutoItems
          .cast<ActionItem?>()
          .firstWhere(
            (ActionItem? item) => item?.sourceItemKey == sourceItemKey,
            orElse: () => null,
          );

      refreshedAutoItems.add(
        ActionItem(
          id: existing?.id ?? _uuid.v4(),
          inspectionId: inspection.id,
          sourceSectionKey: InspectionSectionKeys.filtrationBreatherService,
          sourceItemKey: sourceItemKey,
          conditionRating: filterEntry.conditionRating,
          title: filterEntry.filterName?.trim().isEmpty ?? true
              ? 'Filter replacement required'
              : filterEntry.filterName!,
          description:
              existing?.description ??
              'Filter replacement or correction required.',
          partsRequired: existing?.partsRequired ?? filterEntry.partNumber,
          isAutoGenerated: true,
          createdAt: existing?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    inspection.actionItems = <ActionItem>[
      ...manualItems,
      ...refreshedAutoItems,
    ];
  }

  String _defaultActionDescriptionForResponse(InspectionResponse response) {
    final String base = response.comment?.trim().isNotEmpty ?? false
        ? response.comment!.trim()
        : 'Review and correct ${response.itemLabel.toLowerCase()}.';
    if (response.conditionRating == ConditionRating.criticalOutOfService) {
      return '$base ${AppConstants.lotOWarning}';
    }
    return base;
  }

  InspectionRecord _rowToInspection(Map<String, Object?> row) {
    final InspectionRecord inspection = InspectionRecord.fromEncodedJson(
      row['payload_json'] as String,
    );
    inspection.generatedPdfPath = row['generated_pdf_path'] as String?;
    inspection.status = InspectionStatusX.fromValue(row['status'] as String);
    return inspection;
  }
}

import 'dart:io';

import 'package:cts_fluid_power_inspection_app/data/database/app_database.dart';
import 'package:cts_fluid_power_inspection_app/data/models/inspection_enums.dart';
import 'package:cts_fluid_power_inspection_app/data/models/inspection_models.dart';
import 'package:cts_fluid_power_inspection_app/core/constants.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

class TestAppDatabase extends AppDatabase {
  TestAppDatabase(this.directory);

  final Directory directory;
  Database? _database;

  @override
  Future<Database> open() async {
    if (_database != null) {
      return _database!;
    }

    final dbPath =
        '${directory.path}${Platform.pathSeparator}${AppConstants.databaseName}';
    _database = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE inspections(
              id TEXT PRIMARY KEY,
              document_number TEXT NOT NULL UNIQUE,
              status TEXT NOT NULL,
              customer TEXT NOT NULL,
              work_order_number TEXT NOT NULL,
              asset_name TEXT NOT NULL,
              technician_name TEXT NOT NULL,
              customer_reference TEXT NOT NULL,
              site_location TEXT NOT NULL,
              servicing_shop TEXT NOT NULL,
              inspection_date_time TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              completed_at TEXT,
              emailed_at TEXT,
              generated_pdf_path TEXT,
              has_critical INTEGER NOT NULL DEFAULT 0,
              flagged_count INTEGER NOT NULL DEFAULT 0,
              photo_count INTEGER NOT NULL DEFAULT 0,
              payload_json TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE document_sequences(
              date_key TEXT PRIMARY KEY,
              last_sequence INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE email_recipients(
              id TEXT PRIMARY KEY,
              email TEXT NOT NULL,
              customer TEXT,
              last_used_at TEXT NOT NULL,
              usage_count INTEGER NOT NULL DEFAULT 0,
              is_customer_default INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      ),
    );
    return _database!;
  }

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}

InspectionRecord buildInspection({
  required String id,
  required String documentNumber,
  required InspectionStatus status,
  String customer = 'Acme Manufacturing',
  String workOrderNumber = 'WO-1001',
  String customerReference = 'PO-1001',
  String assetName = 'HPU-1',
  String hpuAssetIdName = 'HPU-1',
  String siteLocation = 'Plant 1',
  String technicianName = 'Jordan Lee',
  String servicingShop = 'CTS North Shop',
  DateTime? inspectionDateTime,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? completedAt,
  DateTime? emailedAt,
  String finalTechComments = '',
  String? signatureFilePath,
  bool criticalAcknowledged = false,
  String? generatedPdfPath,
  List<InspectionResponse>? responses,
  List<InspectionPhoto>? photos,
  List<ActionItem>? actionItems,
  List<HoseEntry>? hoseEntries,
  List<ComponentEntry>? componentEntries,
  List<FilterEntry>? filterEntries,
}) {
  final now = createdAt ?? DateTime.utc(2026, 4, 20, 12, 0);
  return InspectionRecord(
    id: id,
    documentNumber: documentNumber,
    status: status,
    customer: customer,
    workOrderNumber: workOrderNumber,
    customerReference: customerReference,
    assetName: assetName,
    hpuAssetIdName: hpuAssetIdName,
    siteLocation: siteLocation,
    technicianName: technicianName,
    servicingShop: servicingShop,
    inspectionDateTime: inspectionDateTime ?? now,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    completedAt: completedAt,
    emailedAt: emailedAt,
    finalTechComments: finalTechComments,
    signatureFilePath: signatureFilePath,
    criticalAcknowledged: criticalAcknowledged,
    generatedPdfPath: generatedPdfPath,
    sections: InspectionSectionKeys.ordered
        .map(
          (descriptor) => InspectionSectionProgress(
            id: '${id}_${descriptor.key}',
            inspectionId: id,
            sectionKey: descriptor.key,
            title: descriptor.title,
            sortOrder: descriptor.sortOrder,
            completionState: SectionCompletionState.inProgress,
          ),
        )
        .toList(growable: false),
    responses: responses ?? <InspectionResponse>[],
    photos: photos ?? <InspectionPhoto>[],
    actionItems: actionItems ?? <ActionItem>[],
    hoseEntries: hoseEntries ?? <HoseEntry>[],
    componentEntries: componentEntries ?? <ComponentEntry>[],
    filterEntries: filterEntries ?? <FilterEntry>[],
    requiredItems: const <RequiredItemEntry>[],
  );
}

void fillRequiredResponses(
  InspectionRecord inspection, {
  bool critical = false,
}) {
  final now = DateTime.utc(2026, 4, 20, 12, 0);
  inspection.responses = <InspectionResponse>[
    _response(
      inspection,
      InspectionSectionKeys.fluidTankService,
      InspectionItemKeys.fluidLevel,
      'Fluid Level',
      value: 'Within Tolerance',
      conditionRating: ConditionRating.satisfactory,
      isFlagged: false,
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.fluidTankService,
      InspectionItemKeys.fluidClarity,
      'Fluid Clarity',
      value: 'Clear',
      conditionRating: ConditionRating.satisfactory,
      isFlagged: false,
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.fluidTankService,
      InspectionItemKeys.tankIntegrity,
      'Tank Integrity',
      value: critical
          ? ConditionRating.criticalOutOfService.value
          : ConditionRating.satisfactory.value,
      conditionRating: critical
          ? ConditionRating.criticalOutOfService
          : ConditionRating.satisfactory,
      isFlagged: critical,
      comment: critical ? 'Severe damage.' : null,
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.fluidTankService,
      InspectionItemKeys.tankCleanoutPerformed,
      'Tank Cleanout Performed',
      value: 'Yes',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.hoseConnectionInspection,
      InspectionItemKeys.overallHoseCondition,
      'Overall Hose Condition',
      value: ConditionRating.satisfactory.value,
      conditionRating: ConditionRating.satisfactory,
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.filtrationBreatherService,
      InspectionItemKeys.breatherPartNumber,
      'Breather Part Number',
      value: 'BR-100',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.filtrationBreatherService,
      InspectionItemKeys.breatherReplaced,
      'Breather Replaced',
      value: 'Yes',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.filtrationBreatherService,
      InspectionItemKeys.pressureFilterPartNumber,
      'Pressure Filter PN',
      value: 'PF-200',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.filtrationBreatherService,
      InspectionItemKeys.pressureFilterReplaced,
      'Pressure Filter Replaced',
      value: 'Yes',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.filtrationBreatherService,
      InspectionItemKeys.returnFilterPartNumber,
      'Return Filter PN',
      value: 'RF-300',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.filtrationBreatherService,
      InspectionItemKeys.returnFilterReplaced,
      'Return Filter Replaced',
      value: 'Yes',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.equipmentRunning,
      'Equipment Running',
      value: 'Yes',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.pumpCompensatorSetting,
      'Pump Compensator Setting Observed',
      value: '2800',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.changePumpCompensator,
      'Change Pump Compensator Setting',
      value: 'No',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.systemReliefSetting,
      'System Relief Setting Observed',
      value: '3000',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.changeSystemRelief,
      'Change System Relief Setting',
      value: 'No',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.operatingTemperature,
      'Operating Temperature',
      value: '55',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.operatingTemperatureUnit,
      'Operating Temperature Unit',
      value: '°C',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.accumulatorPreCharge,
      'Accumulator Pre-charge',
      value: '900',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.operationalDataSystemTest,
      InspectionItemKeys.chargeAccumulator,
      'Charge Accumulator',
      value: 'No',
      now: now,
    ),
    _response(
      inspection,
      InspectionSectionKeys.followUpRepairsQuoting,
      InspectionItemKeys.additionalPartsRepairs,
      'Additional Parts / Repairs',
      value: 'No',
      now: now,
    ),
  ];

  if (critical) {
    inspection.criticalAcknowledged = false;
  }
}

InspectionResponse _response(
  InspectionRecord inspection,
  String sectionKey,
  String itemKey,
  String itemLabel, {
  required String value,
  ConditionRating? conditionRating,
  bool isFlagged = false,
  String? comment,
  required DateTime now,
}) {
  return InspectionResponse(
    id: const Uuid().v4(),
    inspectionId: inspection.id,
    sectionKey: sectionKey,
    itemKey: itemKey,
    itemLabel: itemLabel,
    fieldType: InspectionFieldType.dropdown,
    value: value,
    conditionRating: conditionRating,
    isFlagged: isFlagged,
    comment: comment,
    createdAt: now,
    updatedAt: now,
  );
}

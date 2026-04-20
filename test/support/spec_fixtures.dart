import 'dart:io';

import 'package:cts_fluid_power_inspection_app/core/constants.dart';
import 'package:cts_fluid_power_inspection_app/data/models/inspection_enums.dart';
import 'package:cts_fluid_power_inspection_app/features/pdf_report/pdf_report_models.dart';
import 'package:path/path.dart' as p;

import 'spec_models.dart';
import 'spec_service.dart';

Future<SpecInspectionService> createService() async {
  final root = await Directory.systemTemp.createTemp('cts_spec_test_');
  return SpecInspectionService(rootDirectory: root);
}

Future<SpecInspection> seedCleanPass(SpecInspectionService service) async {
  final inspection = service.createInspection(
    now: DateTime.utc(2026, 4, 18, 15, 30),
    customer: 'Acme Manufacturing',
    workOrderNumber: 'WO-48152',
    customerReference: 'PO-1188',
    assetName: 'HPU-07',
    siteLocation: 'Edmonton Service Yard',
    technicianName: 'Jordan Lee',
    servicingShop: 'CTS North Shop',
  );
  service.upsertResponse(
    inspection: inspection,
    sectionKey: InspectionSectionKeys.fluidTankService,
    itemKey: InspectionItemKeys.fluidLevel,
    itemLabel: 'Fluid Level',
    fieldType: InspectionFieldType.dropdown,
    value: FluidLevelOption.withinTolerance.value,
    isRequired: true,
    conditionRating: ConditionRating.satisfactory,
  );
  service.upsertResponse(
    inspection: inspection,
    sectionKey: InspectionSectionKeys.fluidTankService,
    itemKey: InspectionItemKeys.fluidClarity,
    itemLabel: 'Fluid Clarity',
    fieldType: InspectionFieldType.dropdown,
    value: FluidClarityOption.clear.value,
    isRequired: true,
    conditionRating: ConditionRating.satisfactory,
  );
  inspection.signatureFilePath = '/tmp/signature.png';
  service.saveInspection(inspection);
  return inspection;
}

Future<SpecInspection> seedAtRisk(SpecInspectionService service) async {
  final inspection = service.createInspection(
    now: DateTime.utc(2026, 4, 18, 16, 0),
    customer: 'Acme Manufacturing',
    workOrderNumber: 'WO-48153',
    customerReference: 'PO-1189',
    assetName: 'HPU-08',
    siteLocation: 'Main Plant',
    technicianName: 'Jordan Lee',
    servicingShop: 'CTS North Shop',
  );
  service.upsertResponse(
    inspection: inspection,
    sectionKey: InspectionSectionKeys.hoseConnectionInspection,
    itemKey: InspectionItemKeys.overallHoseCondition,
    itemLabel: 'Overall Hose Condition',
    fieldType: InspectionFieldType.conditionRating,
    value: ConditionRating.monitorAtRisk.value,
    isRequired: true,
    conditionRating: ConditionRating.monitorAtRisk,
    comment: 'Minor abrasion observed.',
  );
  await service.addPhoto(
    inspection: inspection,
    sectionKey: InspectionSectionKeys.hoseConnectionInspection,
    itemKey: InspectionItemKeys.overallHoseCondition,
    caption: 'Abrasion on hose bundle',
  );
  service.addManualActionItem(
    inspection: inspection,
    sourceSectionKey: InspectionSectionKeys.hoseConnectionInspection,
    sourceItemKey: InspectionItemKeys.overallHoseCondition,
    conditionRating: ConditionRating.monitorAtRisk,
    title: 'Overall Hose Condition requires attention',
    description: 'Minor abrasion observed.',
  );
  inspection.signatureFilePath = '/tmp/signature.png';
  service.saveInspection(inspection);
  return inspection;
}

Future<SpecInspection> seedUnsatisfactory(SpecInspectionService service) async {
  final inspection = service.createInspection(
    now: DateTime.utc(2026, 4, 18, 16, 30),
    customer: 'Acme Manufacturing',
    workOrderNumber: 'WO-48154',
    customerReference: 'PO-1190',
    assetName: 'HPU-09',
    siteLocation: 'Main Plant',
    technicianName: 'Jordan Lee',
    servicingShop: 'CTS North Shop',
  );
  service.upsertResponse(
    inspection: inspection,
    sectionKey: InspectionSectionKeys.fluidTankService,
    itemKey: InspectionItemKeys.tankIntegrity,
    itemLabel: 'Tank Integrity',
    fieldType: InspectionFieldType.conditionRating,
    value: ConditionRating.unsatisfactory.value,
    isRequired: true,
    conditionRating: ConditionRating.unsatisfactory,
    comment: 'Visible seepage at seam.',
  );
  await service.addPhoto(
    inspection: inspection,
    sectionKey: InspectionSectionKeys.fluidTankService,
    itemKey: InspectionItemKeys.tankIntegrity,
    caption: 'Tank seam seepage',
  );
  service.addManualActionItem(
    inspection: inspection,
    sourceSectionKey: InspectionSectionKeys.fluidTankService,
    sourceItemKey: InspectionItemKeys.tankIntegrity,
    conditionRating: ConditionRating.unsatisfactory,
    title: 'Tank Integrity requires attention',
    description: 'Visible seepage at seam.',
    partsRequired: 'Seal kit',
  );
  inspection.signatureFilePath = '/tmp/signature.png';
  service.saveInspection(inspection);
  return inspection;
}

Future<SpecInspection> seedCritical(SpecInspectionService service) async {
  final inspection = service.createInspection(
    now: DateTime.utc(2026, 4, 18, 17, 0),
    customer: 'Acme Manufacturing',
    workOrderNumber: 'WO-48155',
    customerReference: 'PO-1191',
    assetName: 'HPU-10',
    siteLocation: 'Main Plant',
    technicianName: 'Jordan Lee',
    servicingShop: 'CTS North Shop',
  );
  service.upsertResponse(
    inspection: inspection,
    sectionKey: InspectionSectionKeys.operationalDataSystemTest,
    itemKey: InspectionItemKeys.equipmentRunning,
    itemLabel: 'Equipment Running',
    fieldType: InspectionFieldType.yesNoNa,
    value: YesNoNa.no.value,
    isRequired: true,
    conditionRating: ConditionRating.criticalOutOfService,
    comment: 'System would not hold pressure.',
  );
  await service.addPhoto(
    inspection: inspection,
    sectionKey: InspectionSectionKeys.operationalDataSystemTest,
    itemKey: InspectionItemKeys.equipmentRunning,
    caption: 'Gauge needle drop',
  );
  service.addManualActionItem(
    inspection: inspection,
    sourceSectionKey: InspectionSectionKeys.operationalDataSystemTest,
    sourceItemKey: InspectionItemKeys.equipmentRunning,
    conditionRating: ConditionRating.criticalOutOfService,
    title: 'Equipment Running requires immediate shutdown',
    description: 'System would not hold pressure.',
    partsRequired: 'Seal kit, accumulator charge',
  );
  inspection.criticalAcknowledged = true;
  inspection.finalTechComments = 'LOTO applied before leaving site.';
  inspection.signatureFilePath = '/tmp/signature.png';
  service.saveInspection(inspection);
  return inspection;
}

Future<SpecInspection> seedManyPhotos(SpecInspectionService service) async {
  final inspection = service.createInspection(
    now: DateTime.utc(2026, 4, 18, 17, 15),
    customer: 'Acme Manufacturing',
    workOrderNumber: 'WO-48156',
    customerReference: 'PO-1192',
    assetName: 'HPU-11',
    siteLocation: 'Main Plant',
    technicianName: 'Jordan Lee',
    servicingShop: 'CTS North Shop',
  );
  service.upsertResponse(
    inspection: inspection,
    sectionKey: InspectionSectionKeys.jobAssetIdentification,
    itemKey: InspectionItemKeys.overviewPhotos,
    itemLabel: 'HPU Wide Shot',
    fieldType: InspectionFieldType.photo,
    value: 'photos',
    isRequired: true,
    conditionRating: ConditionRating.satisfactory,
  );
  for (var i = 0; i < 10; i++) {
    await service.addPhoto(
      inspection: inspection,
      sectionKey: InspectionSectionKeys.jobAssetIdentification,
      itemKey: InspectionItemKeys.overviewPhotos,
      caption: 'Photo ${i + 1}',
    );
  }
  inspection.signatureFilePath = '/tmp/signature.png';
  service.saveInspection(inspection);
  return inspection;
}

Future<SpecInspection> seedHoseReplacement(
  SpecInspectionService service,
) async {
  final inspection = service.createInspection(
    now: DateTime.utc(2026, 4, 18, 17, 25),
    customer: 'Acme Manufacturing',
    workOrderNumber: 'WO-48157',
    customerReference: 'PO-1193',
    assetName: 'HPU-12',
    siteLocation: 'Main Plant',
    technicianName: 'Jordan Lee',
    servicingShop: 'CTS North Shop',
  );
  service.addHoseEntry(
    inspection: inspection,
    hoseNameLocation: 'Return line near manifold',
    failureType: FailureType.leak,
    hoseSize: '3/8 in',
    hoseLength: '42 in',
    hoseType: '2-wire hydraulic hose',
    fittingEndA: 'JIC 37',
    fittingEndB: 'ORFS',
    quantity: 1,
    replacementPartNumbers: 'H-334, F-221',
    partsNeeded: 'Hose, fittings, clamps',
    notes: 'Leak at swivel fitting.',
  );
  return inspection;
}

Future<SpecInspection> seedExportImport(SpecInspectionService service) async {
  final inspection = service.createInspection(
    now: DateTime.utc(2026, 4, 18, 17, 40),
    customer: 'Acme Manufacturing',
    workOrderNumber: 'WO-48158',
    customerReference: 'PO-1194',
    assetName: 'HPU-13',
    siteLocation: 'Main Plant',
    technicianName: 'Jordan Lee',
    servicingShop: 'CTS North Shop',
  );
  service.upsertResponse(
    inspection: inspection,
    sectionKey: InspectionSectionKeys.filtrationBreatherService,
    itemKey: InspectionItemKeys.breatherReplaced,
    itemLabel: 'Breather Replaced?',
    fieldType: InspectionFieldType.yesNoNa,
    value: YesNoNa.yes.value,
    isRequired: true,
    conditionRating: ConditionRating.satisfactory,
  );
  await service.addPhoto(
    inspection: inspection,
    sectionKey: InspectionSectionKeys.filtrationBreatherService,
    itemKey: InspectionItemKeys.breatherPartNumber,
    caption: 'Breather tag',
  );
  inspection.signatureFilePath = '/tmp/signature.png';
  service.saveInspection(inspection);
  await service.generatePdf(inspection);
  return inspection;
}

InspectionReportData toReportData(SpecInspection inspection) {
  InspectionReportStatus status = switch (inspection.status) {
    InspectionStatus.draft => InspectionReportStatus.draft,
    InspectionStatus.inProgress => InspectionReportStatus.inProgress,
    InspectionStatus.complete => InspectionReportStatus.complete,
    InspectionStatus.emailed => InspectionReportStatus.emailed,
  };
  InspectionReportPhoto toPhoto(SpecPhoto photo) {
    return InspectionReportPhoto(
      filePath: photo.filePath,
      caption: photo.caption,
      sectionTitle: photo.sectionKey,
      itemLabel: photo.itemKey,
      capturedAt: photo.capturedAt,
      sortOrder: photo.sortOrder,
    );
  }

  InspectionReportActionItem toAction(SpecActionItem action) {
    return InspectionReportActionItem(
      title: action.title,
      description: action.description,
      sourceSection: action.sourceSectionKey,
      sourceItem: action.sourceItemKey,
      partsRequired: action.partsRequired,
      isAutoGenerated: action.isAutoGenerated,
      conditionRating: action.conditionRating == null
          ? null
          : switch (action.conditionRating!) {
              ConditionRating.satisfactory =>
                ReportConditionRating.satisfactory,
              ConditionRating.monitorAtRisk => ReportConditionRating.monitor,
              ConditionRating.unsatisfactory =>
                ReportConditionRating.unsatisfactory,
              ConditionRating.criticalOutOfService =>
                ReportConditionRating.critical,
            },
    );
  }

  InspectionReportItem toItem(SpecResponse response) {
    return InspectionReportItem(
      label: response.itemLabel,
      value: response.value,
      conditionRating: response.conditionRating == null
          ? null
          : switch (response.conditionRating!) {
              ConditionRating.satisfactory =>
                ReportConditionRating.satisfactory,
              ConditionRating.monitorAtRisk => ReportConditionRating.monitor,
              ConditionRating.unsatisfactory =>
                ReportConditionRating.unsatisfactory,
              ConditionRating.criticalOutOfService =>
                ReportConditionRating.critical,
            },
      comment: response.comment,
      photos: inspection.photos
          .where(
            (SpecPhoto photo) =>
                photo.sectionKey == response.sectionKey &&
                photo.itemKey == response.itemKey,
          )
          .map(toPhoto)
          .toList(growable: false),
    );
  }

  final sections = <InspectionReportSection>[
    InspectionReportSection(
      key: InspectionSectionKeys.jobAssetIdentification,
      title: 'Job & Asset Identification',
      items: inspection.responses
          .where(
            (SpecResponse response) =>
                response.sectionKey ==
                InspectionSectionKeys.jobAssetIdentification,
          )
          .map(toItem)
          .toList(growable: false),
    ),
    InspectionReportSection(
      key: InspectionSectionKeys.hoseConnectionInspection,
      title: 'Hose & Connection Inspection',
      items: inspection.responses
          .where(
            (SpecResponse response) =>
                response.sectionKey ==
                InspectionSectionKeys.hoseConnectionInspection,
          )
          .map(toItem)
          .toList(growable: false),
    ),
    InspectionReportSection(
      key: InspectionSectionKeys.fluidTankService,
      title: 'Fluid & Tank Service',
      items: inspection.responses
          .where(
            (SpecResponse response) =>
                response.sectionKey == InspectionSectionKeys.fluidTankService,
          )
          .map(toItem)
          .toList(growable: false),
    ),
    InspectionReportSection(
      key: InspectionSectionKeys.filtrationBreatherService,
      title: 'Filtration & Breather Service',
      items: inspection.responses
          .where(
            (SpecResponse response) =>
                response.sectionKey ==
                InspectionSectionKeys.filtrationBreatherService,
          )
          .map(toItem)
          .toList(growable: false),
    ),
    InspectionReportSection(
      key: InspectionSectionKeys.operationalDataSystemTest,
      title: 'Operational Data / System Test',
      items: inspection.responses
          .where(
            (SpecResponse response) =>
                response.sectionKey ==
                InspectionSectionKeys.operationalDataSystemTest,
          )
          .map(toItem)
          .toList(growable: false),
    ),
  ];

  return InspectionReportData(
    documentNumber: inspection.documentNumber,
    customer: inspection.customer,
    workOrderNumber: inspection.workOrderNumber,
    customerReference: inspection.customerReference,
    assetName: inspection.assetName,
    siteLocation: inspection.siteLocation,
    technicianName: inspection.technicianName,
    servicingShop: inspection.servicingShop,
    inspectionDateTime: inspection.inspectionDateTime,
    createdAt: inspection.createdAt,
    completedAt: inspection.completedAt,
    emailedAt: inspection.emailedAt,
    status: status,
    finalTechComments: inspection.finalTechComments,
    criticalAcknowledged: inspection.criticalAcknowledged,
    signature: inspection.signatureFilePath == null
        ? null
        : InspectionReportSignature(
            filePath: inspection.signatureFilePath,
            signerName: inspection.technicianName,
            signedAt: inspection.completedAt ?? inspection.updatedAt,
          ),
    sections: sections,
    actionItems: inspection.actionItems.map(toAction).toList(growable: false),
  );
}

String bundlePathFor(SpecInspection inspection) {
  return p.join(
    Directory.systemTemp.path,
    '${inspection.documentNumber}.ctsinspection.zip',
  );
}

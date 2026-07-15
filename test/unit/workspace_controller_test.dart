import 'dart:convert';
import 'dart:io';
import 'package:cts_fluid_power_inspection_app/core/constants.dart';
import 'package:cts_fluid_power_inspection_app/core/validators.dart';
import 'package:cts_fluid_power_inspection_app/core/workspace_models.dart';
import 'package:cts_fluid_power_inspection_app/data/models/inspection_enums.dart';
import 'package:cts_fluid_power_inspection_app/data/models/inspection_models.dart';
import 'package:cts_fluid_power_inspection_app/data/repositories/inspection_repository.dart';
import 'package:cts_fluid_power_inspection_app/features/pdf_report/pdf_report_models.dart';
import 'package:cts_fluid_power_inspection_app/services/document_number_service.dart';
import 'package:cts_fluid_power_inspection_app/services/email_service.dart';
import 'package:cts_fluid_power_inspection_app/services/pdf_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cts_fluid_power_inspection_app/core/workspace_controller.dart';

import '../support/persistence_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('document numbers increment and search filters records', () {
    final controller = AppWorkspaceController();

    final created = controller.createInspection();
    expect(created.documentNumber, matches(RegExp(r'^\d{8}-\d{4}$')));

    final duplicate = controller.duplicateInspection(
      controller.inspections.first,
    );
    expect(duplicate.documentNumber, isNot(equals(created.documentNumber)));
    expect(duplicate.sections.length, 8);

    controller.setSearchQuery('North Basin');
    expect(controller.filteredInspections.length, 1);
    expect(
      controller.filteredInspections.first.customer,
      'North Basin Processing',
    );
  });

  group('repository-backed workspace', () {
    late Directory tempDir;
    late TestAppDatabase database;
    late InspectionRepository repository;

    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      tempDir = await Directory.systemTemp.createTemp('workspace_controller_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'getApplicationDocumentsDirectory') {
                return tempDir.path;
              }
              return null;
            },
          );
      database = TestAppDatabase(tempDir);
      repository = InspectionRepository(
        database: database,
        documentNumberService: DocumentNumberService(),
      );
    });

    tearDown(() async {
      await database.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saves form drafts to SQLite and reloads them', () async {
      final controller = AppWorkspaceController(
        repository: repository,
        seedDemoData: false,
      );

      final saved = await controller.saveFormDraft(
        InspectionFormDraft(
          customer: 'Production Customer',
          workOrderNumber: 'WO-FP-003',
          customerReference: 'PO-FP-003',
          assetName: 'HPU Production Unit',
          siteLocation: 'Mine service bay',
          technicianName: 'CTS Tech',
          servicingShop: 'CTS Edmonton',
          finalTechComments: 'Saved through production workspace.',
          tankIntegrity: ConditionRating.satisfactory,
          hoseCondition: ConditionRating.satisfactory,
          equipmentRunning: YesNoNa.yes,
          additionalPartsRepairs: YesNoNa.no,
        ),
      );

      final reloaded = AppWorkspaceController(
        repository: repository,
        seedDemoData: false,
      );
      await reloaded.loadPersistedInspections();

      expect(saved.documentNumber, matches(RegExp(r'^\d{8}-\d{4}$')));
      expect(reloaded.inspections, hasLength(1));
      expect(reloaded.inspections.single.customer, 'Production Customer');
      expect(reloaded.inspections.single.workOrderNumber, 'WO-FP-003');
    });

    test(
      'completion save does not fabricate unanswered required responses',
      () async {
        final controller = AppWorkspaceController(
          repository: repository,
          seedDemoData: false,
        );

        final saved = await controller.saveFormDraft(
          InspectionFormDraft(
            customer: 'Production Customer',
            workOrderNumber: 'WO-FP-004',
            customerReference: 'PO-FP-004',
            assetName: 'HPU Production Unit',
            siteLocation: 'Mine service bay',
            technicianName: 'CTS Tech',
            servicingShop: 'CTS Edmonton',
            finalTechComments: 'Ready for review without hidden defaults.',
            tankIntegrity: ConditionRating.satisfactory,
            hoseCondition: ConditionRating.satisfactory,
            equipmentRunning: YesNoNa.yes,
            additionalPartsRepairs: YesNoNa.no,
          ),
          complete: true,
        );

        final record = await repository.getInspection(saved.id);

        expect(record, isNotNull);
        expect(saved.status, isNot(InspectionStatus.complete));
        expect(record!.completedAt, isNull);
        expect(
          record.responseByKey(
            InspectionSectionKeys.fluidTankService,
            InspectionItemKeys.tankIntegrity,
          ),
          isNotNull,
        );
        expect(
          record.responseByKey(
            InspectionSectionKeys.fluidTankService,
            InspectionItemKeys.fluidLevel,
          ),
          isNull,
        );
        expect(
          record.responseByKey(
            InspectionSectionKeys.filtrationBreatherService,
            InspectionItemKeys.breatherPartNumber,
          ),
          isNull,
        );
        expect(
          InspectionValidator.validateForCompletion(
            record,
          ).issues.map((issue) => issue.message),
          contains('Fluid Level must be answered.'),
        );
      },
    );

    test(
      'in-memory completion request does not fabricate complete status',
      () async {
        final controller = AppWorkspaceController(seedDemoData: false);

        final saved = await controller.saveFormDraft(
          InspectionFormDraft(
            customer: 'Production Customer',
            workOrderNumber: 'WO-FP-MEM',
            customerReference: 'PO-FP-MEM',
            assetName: 'HPU Memory Unit',
            siteLocation: 'Mine service bay',
            technicianName: 'CTS Tech',
            servicingShop: 'CTS Edmonton',
            finalTechComments: 'Incomplete local draft.',
          ),
          complete: true,
        );

        expect(saved.status, isNot(InspectionStatus.complete));
        expect(saved.completedAt, isNull);
      },
    );

    test(
      'stale edit id is rejected instead of creating a new record',
      () async {
        final controller = AppWorkspaceController(
          repository: repository,
          seedDemoData: false,
        );

        await expectLater(
          controller.saveFormDraft(
            const InspectionFormDraft(
              inspectionId: 'missing-inspection-id',
              customer: 'Production Customer',
              workOrderNumber: 'WO-FP-STALE',
              customerReference: 'PO-FP-STALE',
              assetName: 'HPU Stale Unit',
              siteLocation: 'Mine service bay',
              technicianName: 'CTS Tech',
              servicingShop: 'CTS Edmonton',
              finalTechComments: 'Should not create a replacement record.',
            ),
          ),
          throwsStateError,
        );

        expect(await repository.allInspections(), isEmpty);
      },
    );

    test(
      'fully answered draft can be completed through the repository',
      () async {
        final controller = AppWorkspaceController(
          repository: repository,
          seedDemoData: false,
        );

        final saved = await controller.saveFormDraft(
          _completeDraft(),
          complete: true,
        );
        final record = await repository.getInspection(saved.id);

        expect(saved.status, InspectionStatus.complete);
        expect(record, isNotNull);
        expect(record!.completedAt, isNotNull);
        expect(
          InspectionValidator.validateForCompletion(record).issues,
          isEmpty,
        );
        expect(
          record
              .responseByKey(
                InspectionSectionKeys.fluidTankService,
                InspectionItemKeys.fluidLevel,
              )
              ?.value,
          FluidLevelOption.withinTolerance.value,
        );
        expect(
          record
              .responseByKey(
                InspectionSectionKeys.filtrationBreatherService,
                InspectionItemKeys.breatherPartNumber,
              )
              ?.value,
          'BR-100',
        );
      },
    );

    test('saving an edit clears stale field responses', () async {
      final controller = AppWorkspaceController(
        repository: repository,
        seedDemoData: false,
      );

      final saved = await controller.saveFormDraft(
        const InspectionFormDraft(
          customer: 'Production Customer',
          workOrderNumber: 'WO-FP-005',
          customerReference: 'PO-FP-005',
          assetName: 'HPU Production Unit',
          siteLocation: 'Mine service bay',
          technicianName: 'CTS Tech',
          servicingShop: 'CTS Edmonton',
          finalTechComments: 'Tank rating will be cleared.',
          tankIntegrity: ConditionRating.satisfactory,
        ),
      );
      expect(
        (await repository.getInspection(saved.id))?.responseByKey(
          InspectionSectionKeys.fluidTankService,
          InspectionItemKeys.tankIntegrity,
        ),
        isA<InspectionResponse>(),
      );

      await controller.saveFormDraft(
        InspectionFormDraft(
          inspectionId: saved.id,
          customer: 'Production Customer',
          workOrderNumber: 'WO-FP-005',
          customerReference: 'PO-FP-005',
          assetName: 'HPU Production Unit',
          siteLocation: 'Mine service bay',
          technicianName: 'CTS Tech',
          servicingShop: 'CTS Edmonton',
          finalTechComments: 'Tank rating cleared.',
        ),
      );

      expect(
        (await repository.getInspection(saved.id))?.responseByKey(
          InspectionSectionKeys.fluidTankService,
          InspectionItemKeys.tankIntegrity,
        ),
        isNull,
      );
    });

    test(
      'draft photos from bundled assets are not persisted as evidence',
      () async {
        final controller = AppWorkspaceController(
          repository: repository,
          seedDemoData: false,
        );

        final saved = await controller.saveFormDraft(
          InspectionFormDraft(
            customer: 'Production Customer',
            workOrderNumber: 'WO-FP-ASSET-PHOTO',
            customerReference: 'PO-FP-ASSET-PHOTO',
            assetName: 'HPU Production Unit',
            siteLocation: 'Mine service bay',
            technicianName: 'CTS Tech',
            servicingShop: 'CTS Edmonton',
            finalTechComments: 'Asset photo should be rejected.',
            photos: <InspectionPhotoView>[
              InspectionPhotoView(
                assetPath: 'assets/demo/sample_photo_1.jpg',
                caption: 'Sample asset photo',
                sectionTitle: 'Fluid & Tank Service',
                itemLabel: InspectionItemKeys.tankIntegrity,
                capturedAt: DateTime.utc(2026, 4, 20, 12),
              ),
            ],
          ),
        );

        final record = await repository.getInspection(saved.id);
        expect(record?.photos, isEmpty);
      },
    );

    test(
      'saving an edit invalidates generated PDF and emailed state',
      () async {
        final existing = await repository.createInspection();
        existing.customer = 'Production Customer';
        existing.workOrderNumber = 'WO-FP-006';
        existing.customerReference = 'PO-FP-006';
        existing.assetName = 'HPU Production Unit';
        existing.siteLocation = 'Mine service bay';
        existing.technicianName = 'CTS Tech';
        existing.servicingShop = 'CTS Edmonton';
        existing.signatureFilePath = '/tmp/signature.png';
        existing.generatedPdfPath = '/tmp/stale-report.pdf';
        fillRequiredResponses(existing);
        final completed = await repository.saveInspection(existing);
        expect(completed.generatedPdfPath, '/tmp/stale-report.pdf');
        completed.emailedAt = DateTime.utc(2026, 4, 20, 13, 0);
        completed.status = InspectionStatus.emailed;
        final db = await database.open();
        await db.update(
          'inspections',
          <String, Object?>{
            'status': completed.status.value,
            'emailed_at': completed.emailedAt!.toIso8601String(),
            'generated_pdf_path': completed.generatedPdfPath,
            'payload_json': jsonEncode(completed.toJson()),
          },
          where: 'id = ?',
          whereArgs: <Object?>[completed.id],
        );
        final emailed = await repository.getInspection(completed.id);
        expect(emailed, isNotNull);
        final emailedRecord = emailed!;
        expect(emailedRecord.emailedAt, isNotNull);
        expect(emailedRecord.generatedPdfPath, '/tmp/stale-report.pdf');

        final controller = AppWorkspaceController(
          repository: repository,
          seedDemoData: false,
        );
        await controller.saveFormDraft(
          InspectionFormDraft(
            inspectionId: emailedRecord.id,
            customer: 'Updated Production Customer',
            workOrderNumber: 'WO-FP-006',
            customerReference: 'PO-FP-006',
            assetName: 'HPU Production Unit',
            siteLocation: 'Mine service bay',
            technicianName: 'CTS Tech',
            servicingShop: 'CTS Edmonton',
            finalTechComments: 'Edited after emailing.',
          ),
        );

        final edited = await repository.getInspection(emailedRecord.id);
        expect(edited?.emailedAt, isNull);
        expect(edited?.generatedPdfPath, isNull);
      },
    );

    test('editing completed work requires explicit completion again', () async {
      final controller = AppWorkspaceController(
        repository: repository,
        seedDemoData: false,
      );
      final completed = await controller.saveFormDraft(
        _completeDraft(),
        complete: true,
      );
      final firstCompletion = (await repository.getInspection(
        completed.id,
      ))!.completedAt;

      final edited = await controller.saveFormDraft(
        _completeDraft(
          inspectionId: completed.id,
          customer: 'Updated Production Customer',
        ),
      );

      expect(edited.status, isNot(InspectionStatus.complete));
      expect(
        (await repository.getInspection(completed.id))!.completedAt,
        isNull,
      );

      final recompleted = await controller.saveFormDraft(
        _completeDraft(
          inspectionId: completed.id,
          customer: 'Updated Production Customer',
        ),
        complete: true,
      );
      final secondCompletion = (await repository.getInspection(
        recompleted.id,
      ))!.completedAt;
      expect(secondCompletion, isNotNull);
      expect(secondCompletion, isNot(firstCompletion));
    });

    test(
      'component cards and operational notes persist independently',
      () async {
        final controller = AppWorkspaceController(
          repository: repository,
          seedDemoData: false,
        );

        final saved = await controller.saveFormDraft(
          const InspectionFormDraft(
            customer: 'Component Customer',
            workOrderNumber: 'WO-COMPONENTS',
            customerReference: 'PO-COMPONENTS',
            assetName: 'HPU Components',
            siteLocation: 'Component bay',
            technicianName: 'CTS Tech',
            servicingShop: 'CTS Edmonton',
            finalTechComments: '',
            componentPartNumbers: <String, String>{
              'Main Pump': 'PUMP-100',
              'Main Motor': 'MOTOR-200',
              'Cooler': 'COOLER-300',
              'Accumulator': 'ACC-400',
            },
            operationalNotes: 'Pressure stabilized after warm-up.',
          ),
        );

        final record = await repository.getInspection(saved.id);
        expect(record, isNotNull);
        expect(
          <String, String?>{
            for (final entry in record!.componentEntries)
              entry.componentType: entry.modelPartNumber,
          },
          <String, String?>{
            'Main Pump': 'PUMP-100',
            'Main Motor': 'MOTOR-200',
            'Cooler': 'COOLER-300',
            'Accumulator': 'ACC-400',
          },
        );
        expect(
          record
              .responseByKey(
                InspectionSectionKeys.operationalDataSystemTest,
                InspectionItemKeys.operationalNotes,
              )
              ?.value,
          'Pressure stabilized after warm-up.',
        );
      },
    );

    test('clearing an existing signature removes the persisted path', () async {
      final controller = AppWorkspaceController(
        repository: repository,
        seedDemoData: false,
      );
      final saved = await controller.saveFormDraft(
        InspectionFormDraft(
          customer: 'Signature Customer',
          workOrderNumber: 'WO-SIGNATURE',
          customerReference: 'PO-SIGNATURE',
          assetName: 'HPU Signature',
          siteLocation: 'Signature bay',
          technicianName: 'CTS Tech',
          servicingShop: 'CTS Edmonton',
          finalTechComments: '',
          technicianSignaturePngBytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
      );
      expect(
        (await repository.getInspection(saved.id))?.signatureFilePath,
        isNotNull,
      );

      await controller.saveFormDraft(
        InspectionFormDraft(
          inspectionId: saved.id,
          customer: 'Signature Customer',
          workOrderNumber: 'WO-SIGNATURE',
          customerReference: 'PO-SIGNATURE',
          assetName: 'HPU Signature',
          siteLocation: 'Signature bay',
          technicianName: 'CTS Tech',
          servicingShop: 'CTS Edmonton',
          finalTechComments: '',
          keepExistingTechnicianSignature: false,
        ),
      );

      expect(
        (await repository.getInspection(saved.id))?.signatureFilePath,
        isNull,
      );
    });

    test('additional repair notes create a manual follow-up action', () async {
      final controller = AppWorkspaceController(
        repository: repository,
        seedDemoData: false,
      );

      final saved = await controller.saveFormDraft(
        const InspectionFormDraft(
          customer: 'Repair Customer',
          workOrderNumber: 'WO-REPAIR',
          customerReference: 'PO-REPAIR',
          assetName: 'HPU Repair',
          siteLocation: 'Repair bay',
          technicianName: 'CTS Tech',
          servicingShop: 'CTS Edmonton',
          finalTechComments: 'Order a replacement pressure gauge.',
          additionalPartsRepairs: YesNoNa.yes,
        ),
      );

      final record = await repository.getInspection(saved.id);
      expect(
        record?.actionItems,
        contains(
          isA<ActionItem>()
              .having((item) => item.isAutoGenerated, 'auto generated', isFalse)
              .having(
                (item) => item.description,
                'description',
                'Order a replacement pressure gauge.',
              ),
        ),
      );
    });

    test('share handoff waits for explicit emailed confirmation', () async {
      final shareAdapter = FakeEmailShareAdapter();
      final recipientStore = JsonFileRecipientStore(
        documentsDirectoryProvider: () async => tempDir,
      );
      final emailService = EmailService(
        shareAdapter: shareAdapter,
        recipientStore: recipientStore,
      );
      final controller = AppWorkspaceController(
        repository: repository,
        emailService: emailService,
        seedDemoData: false,
      );
      final saved = await controller.saveFormDraft(
        _completeDraft(),
        complete: true,
      );
      final pdfFile = File('${tempDir.path}/completed-report.pdf');
      await pdfFile.writeAsBytes(<int>[1, 2, 3], flush: true);
      final record = (await repository.getInspection(saved.id))!;
      record.generatedPdfPath = pdfFile.path;
      await repository.saveInspection(record);

      await controller.emailInspectionPdf(
        saved.id,
        recipients: const <String>['service@example.com'],
      );
      final afterHandoff = await repository.getInspection(saved.id);
      expect(shareAdapter.lastSharedPdf?.path, pdfFile.path);
      expect(
        await emailService.customerRecipient('Production Customer'),
        'service@example.com',
      );
      expect(afterHandoff?.status, InspectionStatus.complete);
      expect(afterHandoff?.emailedAt, isNull);

      await controller.confirmInspectionEmailed(saved.id);
      final confirmed = await repository.getInspection(saved.id);
      expect(confirmed?.status, InspectionStatus.emailed);
      expect(confirmed?.emailedAt, isNotNull);
    });

    test('export action writes a portable inspection archive', () async {
      final controller = AppWorkspaceController(
        repository: repository,
        seedDemoData: false,
      );
      final saved = await controller.saveFormDraft(
        const InspectionFormDraft(
          customer: 'Export Customer',
          workOrderNumber: 'WO-EXPORT',
          customerReference: 'PO-EXPORT',
          assetName: 'HPU Export',
          siteLocation: 'Export bay',
          technicianName: 'CTS Tech',
          servicingShop: 'CTS Edmonton',
          finalTechComments: '',
        ),
      );

      final result = await controller.exportInspection(saved.id);

      expect(await result.archiveFile.exists(), isTrue);
      expect(await result.archiveFile.length(), greaterThan(0));
      expect(result.exportedFileCount, greaterThanOrEqualTo(2));
    });

    test('exported inspection restores as a separate local record', () async {
      final controller = AppWorkspaceController(
        repository: repository,
        seedDemoData: false,
      );
      final source = await controller.saveFormDraft(
        _completeDraft(),
        complete: true,
      );
      final export = await controller.exportInspection(source.id);

      final imported = await controller.importInspectionArchive(
        export.archiveFile,
      );

      final records = await repository.allInspections();
      expect(records, hasLength(2));
      expect(imported.id, isNot(source.id));
      expect(imported.documentNumber, isNot(source.documentNumber));
      expect(imported.status, InspectionStatus.complete);
      final importedRecord = await repository.getInspection(imported.id);
      expect(importedRecord?.signatureFilePath, isNotNull);
      expect(await File(importedRecord!.signatureFilePath!).exists(), isTrue);
      expect(importedRecord.customer, 'Production Customer');
    });

    test(
      'component photos persist through reports and portable archives',
      () async {
        final sourcePhoto = File('${tempDir.path}/main-pump.jpg');
        await sourcePhoto.writeAsBytes(<int>[1, 2, 3, 4], flush: true);
        final pdfService = _CapturingPdfService();
        final controller = AppWorkspaceController(
          repository: repository,
          pdfService: pdfService,
          seedDemoData: false,
        );
        final itemKey = InspectionItemKeys.componentPhoto('Main Pump');
        final saved = await controller.saveFormDraft(
          _completeDraft(
            componentPartNumbers: const <String, String>{
              'Main Pump': 'PUMP-100',
            },
            photos: <InspectionPhotoView>[
              InspectionPhotoView(
                assetPath: sourcePhoto.path,
                caption: 'Main Pump nameplate',
                sectionTitle: InspectionSectionKeys.titleFor(
                  InspectionSectionKeys.componentTracking,
                ),
                itemLabel: itemKey,
                capturedAt: DateTime.utc(2026, 4, 20, 12),
              ),
            ],
          ),
          complete: true,
        );

        final reloaded = (await repository.getInspection(saved.id))!;
        expect(
          reloaded.photos,
          contains(
            isA<InspectionPhoto>()
                .having(
                  (photo) => photo.sectionKey,
                  'section key',
                  InspectionSectionKeys.componentTracking,
                )
                .having((photo) => photo.itemKey, 'item key', itemKey),
          ),
        );

        await controller.generatePdf(saved.id);
        final report = pdfService.capturedData!;
        final componentSection = report.sections.singleWhere(
          (section) => section.key == InspectionSectionKeys.componentTracking,
        );
        final pumpItem = componentSection.items.singleWhere(
          (item) => item.label == 'Main Pump',
        );
        expect(pumpItem.photos, hasLength(1));
        expect(pumpItem.photos.single.itemLabel, 'Main Pump');
        expect(report.allPhotos, contains(pumpItem.photos.single));

        final export = await controller.exportInspection(saved.id);
        final imported = await controller.importInspectionArchive(
          export.archiveFile,
        );
        final importedRecord = (await repository.getInspection(imported.id))!;
        final importedPhoto = importedRecord.photos.singleWhere(
          (photo) => photo.itemKey == itemKey,
        );
        expect(await File(importedPhoto.filePath).exists(), isTrue);
      },
    );
  });
}

InspectionFormDraft _completeDraft({
  String? inspectionId,
  String customer = 'Production Customer',
  Map<String, String> componentPartNumbers = const <String, String>{},
  List<InspectionPhotoView> photos = const <InspectionPhotoView>[],
}) {
  return InspectionFormDraft(
    inspectionId: inspectionId,
    customer: customer,
    workOrderNumber: 'WO-FP-COMPLETE',
    customerReference: 'PO-FP-COMPLETE',
    assetName: 'HPU Complete Unit',
    siteLocation: 'Mine service bay',
    technicianName: 'CTS Tech',
    servicingShop: 'CTS Edmonton',
    finalTechComments: 'Ready for completion.',
    componentPartNumbers: componentPartNumbers,
    fluidLevel: FluidLevelOption.withinTolerance,
    fluidClarity: FluidClarityOption.clear,
    tankIntegrity: ConditionRating.satisfactory,
    tankCleanoutPerformed: YesNoNa.yes,
    hoseCondition: ConditionRating.satisfactory,
    breatherPartNumber: 'BR-100',
    breatherReplaced: FilterReplacementStatus.yes,
    pressureFilterPartNumber: 'PF-200',
    pressureFilterReplaced: FilterReplacementStatus.yes,
    returnFilterPartNumber: 'RF-300',
    returnFilterReplaced: FilterReplacementStatus.yes,
    equipmentRunning: YesNoNa.yes,
    pumpCompensatorSetting: '2800',
    changePumpCompensator: YesNoNa.no,
    systemReliefSetting: '3000',
    changeSystemRelief: YesNoNa.no,
    operatingTemperature: '55',
    operatingTemperatureUnit: TemperatureUnit.celsius,
    accumulatorPreCharge: '900',
    chargeAccumulator: YesNoNa.no,
    additionalPartsRepairs: YesNoNa.no,
    photos: photos,
    technicianSignaturePngBytes: Uint8List.fromList(<int>[0, 1, 2, 3]),
  );
}

class _CapturingPdfService extends PdfService {
  InspectionReportData? capturedData;

  @override
  Future<File> generateInspectionReportFile(
    InspectionReportData data, {
    required Directory outputDirectory,
    bool includeLogoAsset = true,
  }) async {
    capturedData = data;
    final output = File('${outputDirectory.path}/captured-report.pdf');
    await output.create(recursive: true);
    await output.writeAsBytes(<int>[1, 2, 3], flush: true);
    return output;
  }
}

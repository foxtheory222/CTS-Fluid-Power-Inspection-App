import 'dart:io';

import 'package:cts_fluid_power_inspection_app/core/constants.dart';
import 'package:cts_fluid_power_inspection_app/core/validators.dart';
import 'package:cts_fluid_power_inspection_app/data/models/inspection_enums.dart';
import 'package:cts_fluid_power_inspection_app/data/models/inspection_models.dart';
import 'package:cts_fluid_power_inspection_app/data/repositories/inspection_repository.dart';
import 'package:cts_fluid_power_inspection_app/services/document_number_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../support/persistence_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late TestAppDatabase database;
  late InspectionRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('inspection_repo_test_');
    database = TestAppDatabase(tempDir);
    repository = InspectionRepository(
      database: database,
      documentNumberService: DocumentNumberService(),
      uuid: const Uuid(),
    );
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'duplicateInspection copies only header fields and assigns new document number',
    () async {
      final source = buildInspection(
        id: 'source',
        documentNumber: '20260420-0001',
        status: InspectionStatus.complete,
        completedAt: DateTime.utc(2026, 4, 20, 12, 30),
        signatureFilePath: '/tmp/signature.png',
      );
      fillRequiredResponses(source);
      source.photos.add(
        InspectionPhoto(
          id: 'photo-1',
          inspectionId: source.id,
          sectionKey: InspectionSectionKeys.fluidTankService,
          itemKey: InspectionItemKeys.tankIntegrity,
          filePath: '/tmp/photo.jpg',
          caption: 'Damage',
          sortOrder: 0,
          capturedAt: DateTime.utc(2026, 4, 20, 12, 0),
          createdAt: DateTime.utc(2026, 4, 20, 12, 0),
        ),
      );

      final duplicate = await repository.duplicateInspection(
        source,
        createdAt: DateTime.utc(2026, 4, 21, 8, 0),
      );

      expect(duplicate.documentNumber, isNot(source.documentNumber));
      expect(duplicate.customer, source.customer);
      expect(duplicate.workOrderNumber, source.workOrderNumber);
      expect(duplicate.responses, isEmpty);
      expect(duplicate.photos, isEmpty);
      expect(duplicate.actionItems, isEmpty);
      expect(duplicate.signatureFilePath, isNull);
      expect(duplicate.completedAt, isNull);
      expect(duplicate.emailedAt, isNull);
      expect(duplicate.status, InspectionStatus.inProgress);
    },
  );

  test('a valid save stays in progress until completion is explicit', () async {
    final inspection = buildInspection(
      id: 'explicit-completion',
      documentNumber: '20260420-0090',
      status: InspectionStatus.inProgress,
    );
    fillRequiredResponses(inspection);
    inspection.signatureFilePath = '/tmp/signature.png';

    final saved = await repository.saveInspection(inspection);

    expect(saved.completedAt, isNull);
    expect(saved.status, InspectionStatus.inProgress);
  });

  test('an incomplete inspection cannot be marked as emailed', () async {
    final inspection = buildInspection(
      id: 'invalid-email-state',
      documentNumber: '20260420-0091',
      status: InspectionStatus.inProgress,
    );

    await expectLater(
      repository.markEmailed(inspection),
      throwsA(isA<StateError>()),
    );
    expect(inspection.emailedAt, isNull);
  });

  test('saving an emailed inspection clears emailed state on edit', () async {
    final inspection = buildInspection(
      id: 'save-edit',
      documentNumber: '20260420-0002',
      status: InspectionStatus.inProgress,
    );
    fillRequiredResponses(inspection);
    inspection.signatureFilePath = '/tmp/signature.png';
    inspection.completedAt = DateTime.utc(2026, 4, 20, 12, 30);

    final completed = await repository.saveInspection(inspection);
    expect(completed.status, InspectionStatus.complete);

    final emailed = await repository.markEmailed(completed);
    expect(emailed.status, InspectionStatus.emailed);
    expect(emailed.emailedAt, isNotNull);

    emailed.customer = 'Updated Customer';
    final edited = await repository.saveInspection(emailed);

    expect(edited.emailedAt, isNull);
    expect(edited.status, InspectionStatus.complete);
    expect(edited.customer, 'Updated Customer');
  });

  test('saving an edited inspection invalidates generated PDF path', () async {
    final inspection = buildInspection(
      id: 'save-edit-pdf',
      documentNumber: '20260420-0005',
      status: InspectionStatus.inProgress,
      generatedPdfPath: '/tmp/stale-report.pdf',
    );
    fillRequiredResponses(inspection);
    inspection.signatureFilePath = '/tmp/signature.png';
    inspection.completedAt = DateTime.utc(2026, 4, 20, 12, 30);

    final completed = await repository.saveInspection(inspection);
    expect(completed.status, InspectionStatus.complete);
    expect(completed.generatedPdfPath, '/tmp/stale-report.pdf');

    completed.customer = 'Updated Customer';
    final edited = await repository.saveInspection(completed);

    expect(edited.generatedPdfPath, isNull);
    expect(edited.customer, 'Updated Customer');
  });

  test(
    'search finds inspections by work order, customer, asset, document, and technician',
    () async {
      final inspection = buildInspection(
        id: 'searchable',
        documentNumber: '20260420-0003',
        status: InspectionStatus.inProgress,
        customer: 'Contoso Hydraulics',
        workOrderNumber: 'WO-4242',
        customerReference: 'PO-4242',
        assetName: 'Boom Lift',
        technicianName: 'Taylor Smith',
      );
      fillRequiredResponses(inspection);
      inspection.signatureFilePath = '/tmp/signature.png';
      inspection.completedAt = DateTime.utc(2026, 4, 20, 12, 30);
      await repository.saveInspection(inspection);

      expect(
        await repository.search(const InspectionSearchQuery(term: 'WO-4242')),
        hasLength(1),
      );
      expect(
        await repository.search(
          const InspectionSearchQuery(term: 'Contoso Hydraulics'),
        ),
        hasLength(1),
      );
      expect(
        await repository.search(const InspectionSearchQuery(term: 'Boom Lift')),
        hasLength(1),
      );
      expect(
        await repository.search(
          const InspectionSearchQuery(term: '20260420-0003'),
        ),
        hasLength(1),
      );
      expect(
        await repository.search(
          const InspectionSearchQuery(term: 'Taylor Smith'),
        ),
        hasLength(1),
      );
    },
  );

  test('validation helper detects a complete inspection', () {
    final inspection = buildInspection(
      id: 'validate',
      documentNumber: '20260420-0004',
      status: InspectionStatus.inProgress,
    );
    fillRequiredResponses(inspection);
    inspection.signatureFilePath = '/tmp/signature.png';
    inspection.completedAt = DateTime.utc(2026, 4, 20, 12, 30);

    final validation = InspectionValidator.validateForCompletion(inspection);
    expect(validation.isValid, isTrue);
  });

  test('inspection json round-trips customer signature path', () {
    final inspection = buildInspection(
      id: 'customer-signature',
      documentNumber: '20260420-0004',
      status: InspectionStatus.inProgress,
    );
    inspection.customerSignatureFilePath = '/tmp/customer-signature.png';

    final restored = InspectionRecord.fromJson(inspection.toJson());

    expect(restored.customerSignatureFilePath, '/tmp/customer-signature.png');
  });
}

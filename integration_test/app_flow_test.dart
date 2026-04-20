import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:cts_fluid_power_inspection_app/app.dart';
import 'package:cts_fluid_power_inspection_app/core/workspace_providers.dart';
import 'package:cts_fluid_power_inspection_app/data/database/app_database.dart';
import 'package:cts_fluid_power_inspection_app/data/models/inspection_enums.dart';
import 'package:cts_fluid_power_inspection_app/data/repositories/inspection_repository.dart';
import 'package:cts_fluid_power_inspection_app/services/document_number_service.dart';
import 'package:cts_fluid_power_inspection_app/services/email_service.dart';
import 'package:cts_fluid_power_inspection_app/services/photo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real app tablet flow creates completes shares searches and duplicates inspections',
    (WidgetTester tester) async {
      final Directory tempDir = await getTemporaryDirectory();
      final ByteData photoBytes = await rootBundle.load(
        'assets/demo/sample_photo_1.jpg',
      );
      final File samplePhoto = File(
        p.join(tempDir.path, 'integration_photo.jpg'),
      );
      await samplePhoto.writeAsBytes(
        photoBytes.buffer.asUint8List(),
        flush: true,
      );

      final AppDatabase database = AppDatabase();
      final InspectionRepository repository = InspectionRepository(
        database: database,
        documentNumberService: DocumentNumberService(),
      );
      await repository.replaceAllForTests();

      final FakeInspectionPhotoPicker picker = FakeInspectionPhotoPicker(
        galleryPhotos: <XFile>[XFile(samplePhoto.path)],
      );
      final PhotoService photoService = PhotoService(photoPicker: picker);
      final EmailService emailService = EmailService(
        shareAdapter: FakeEmailShareAdapter(),
      );

      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        await database.close();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            inspectionRepositoryProvider.overrideWithValue(repository),
            photoServiceProvider.overrideWithValue(photoService),
            emailServiceProvider.overrideWithValue(emailService),
          ],
          child: const CtsFluidPowerInspectionApp(),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byKey(const Key('new_inspection_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('new_inspection_button')));
      await tester.pump(const Duration(seconds: 1));

      await tester.enterText(
        find.byKey(const Key('customer_field')),
        'North Basin Processing',
      );
      await tester.enterText(
        find.byKey(const Key('asset_field')),
        'HPU-42 Main System',
      );
      await tester.enterText(
        find.byKey(const Key('work_order_field')),
        'WO-7788',
      );
      await tester.enterText(
        find.byKey(const Key('customer_reference_field')),
        'PO-4421',
      );
      await tester.enterText(
        find.byKey(const Key('site_field')),
        'North Tank Farm',
      );
      await tester.enterText(
        find.byKey(const Key('technician_field')),
        'Alex Technician',
      );
      await tester.enterText(
        find.byKey(const Key('servicing_shop_field')),
        'CTS Edmonton',
      );

      await tester.ensureVisible(
        find.byKey(const Key('overview_gallery_button')),
      );
      await tester.tap(find.byKey(const Key('overview_gallery_button')));
      await tester.pumpAndSettle();

      await _selectDropdown(
        tester,
        find.byKey(const Key('fluid_level_field')),
        'High',
      );
      await _selectDropdown(
        tester,
        find.byKey(const Key('fluid_clarity_field')),
        'Clear',
      );
      final atRiskFinder = find.descendant(
        of: find.byKey(const Key('fluid_level_condition_selector')),
        matching: find.text('At Risk'),
      );
      await tester.ensureVisible(atRiskFinder);
      await tester.tap(atRiskFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.byKey(const Key('fluid_level_comment_field')),
        'Fluid level is outside the expected range.',
      );
      await tester.ensureVisible(
        find.byKey(const Key('fluid_level_gallery_button')),
      );
      await tester.tap(find.byKey(const Key('fluid_level_gallery_button')));
      await tester.pumpAndSettle();

      final criticalFinder = find.descendant(
        of: find.byKey(const Key('tank_integrity_condition_selector')),
        matching: find.text('Critical'),
      );
      await tester.ensureVisible(criticalFinder);
      await tester.tap(criticalFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.byKey(const Key('tank_integrity_comment_field')),
        'Severe corrosion is visible on the lower seam.',
      );
      await tester.ensureVisible(
        find.byKey(const Key('tank_integrity_gallery_button')),
      );
      await tester.tap(find.byKey(const Key('tank_integrity_gallery_button')));
      await tester.pumpAndSettle();
      await _selectDropdown(
        tester,
        find.byKey(const Key('tank_cleanout_performed_field')),
        'Yes',
      );

      final hoseSatisfactoryFinder = find.descendant(
        of: find.byKey(const Key('overall_hose_condition_selector')),
        matching: find.text('Satisfactory'),
      );
      await tester.ensureVisible(hoseSatisfactoryFinder);
      await tester.tap(hoseSatisfactoryFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(
        find.byKey(const Key('add_hose_entry_button')),
      );
      await tester.tap(find.byKey(const Key('add_hose_entry_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        _fieldByKeySuffix('_name').last,
        'Return hose at manifold',
      );
      await _selectDropdown(tester, _fieldByKeySuffix('_failure').last, 'Leak');
      await tester.enterText(
        _fieldByKeySuffix('_replacement_parts').last,
        'Return hose assembly',
      );

      await tester.enterText(
        find.byKey(const Key('breather_part_number_field')),
        'BR-100',
      );
      await _selectDropdown(
        tester,
        find.byKey(const Key('breather_replaced_field')),
        'Yes',
      );
      await tester.enterText(
        find.byKey(const Key('pressure_filter_part_number_field')),
        'PF-200',
      );
      await _selectDropdown(
        tester,
        find.byKey(const Key('pressure_filter_replaced_field')),
        'Yes',
      );
      await tester.enterText(
        find.byKey(const Key('return_filter_part_number_field')),
        'RF-300',
      );
      await _selectDropdown(
        tester,
        find.byKey(const Key('return_filter_replaced_field')),
        'Yes',
      );

      await _selectDropdown(
        tester,
        find.byKey(const Key('equipment_running_field')),
        'Yes',
      );
      await tester.enterText(
        find.byKey(const Key('pump_compensator_setting_field')),
        '2800',
      );
      await _selectDropdown(
        tester,
        find.byKey(const Key('change_pump_compensator_field')),
        'No',
      );
      await tester.enterText(
        find.byKey(const Key('system_relief_setting_field')),
        '3000',
      );
      await _selectDropdown(
        tester,
        find.byKey(const Key('change_system_relief_field')),
        'No',
      );
      await tester.enterText(
        find.byKey(const Key('operating_temperature_field')),
        '55',
      );
      await _selectDropdown(
        tester,
        find.byKey(const Key('operating_temperature_unit_field')),
        '°C',
      );
      await tester.enterText(
        find.byKey(const Key('accumulator_pre_charge_field')),
        '900',
      );
      await _selectDropdown(
        tester,
        find.byKey(const Key('charge_accumulator_field')),
        'No',
      );

      await _selectDropdown(
        tester,
        find.byKey(const Key('additional_parts_repairs_field')),
        'No',
      );
      await tester.enterText(
        find.byKey(const Key('final_comments_field')),
        'Inspection completed offline on tablet.',
      );

      await tester.ensureVisible(
        find.byKey(const Key('critical_acknowledgement_checkbox')),
      );
      await tester.tap(
        find.byKey(const Key('critical_acknowledgement_checkbox')),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.ensureVisible(find.byType(Signature));
      await tester.timedDrag(
        find.byType(Signature),
        const Offset(160, 0),
        const Duration(milliseconds: 600),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.ensureVisible(
        find.byKey(const Key('complete_inspection_button')),
      );
      await tester.tap(find.byKey(const Key('complete_inspection_button')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      var inspections = await repository.allInspections();
      expect(inspections, hasLength(1));
      expect(inspections.single.status, InspectionStatus.complete);
      expect(inspections.single.signatureFilePath, isNotNull);

      await tester.ensureVisible(find.byKey(const Key('generate_pdf_button')));
      await tester.tap(find.byKey(const Key('generate_pdf_button')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      inspections = await repository.allInspections();
      final generated = inspections.single;
      expect(generated.generatedPdfPath, isNotNull);
      final File pdfFile = File(generated.generatedPdfPath!);
      expect(await pdfFile.exists(), isTrue);
      expect(await pdfFile.length(), greaterThan(0));

      await tester.ensureVisible(find.byKey(const Key('share_pdf_button')));
      await tester.tap(find.byKey(const Key('share_pdf_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark emailed'));
      await tester.pumpAndSettle();

      inspections = await repository.allInspections();
      expect(inspections.single.status, InspectionStatus.emailed);

      await tester.tap(find.text('Inspections').last);
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(
        find.byKey(const Key('inspection_search_field')),
        'WO-7788',
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('WO-7788'), findsWidgets);

      await tester.tap(find.text('North Basin Processing').first);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Duplicate'));
      await tester.pump(const Duration(seconds: 1));

      inspections = await repository.allInspections();
      expect(inspections, hasLength(2));
      final duplicate = inspections.firstWhere(
        (inspection) => inspection.id != generated.id,
      );
      expect(duplicate.documentNumber, isNot(generated.documentNumber));
      expect(duplicate.customer, generated.customer);
      expect(duplicate.photos, isEmpty);
      expect(duplicate.signatureFilePath, isNull);

      final reloaded = await repository.allInspections();
      expect(reloaded, hasLength(2));
    },
  );
}

Finder _fieldByKeySuffix(String suffix) {
  return find.byWidgetPredicate((Widget widget) {
    final Key? key = widget.key;
    if (key is! ValueKey) {
      return false;
    }
    final Object? value = key.value;
    return value is String && value.endsWith(suffix);
  });
}

Future<void> _selectDropdown(
  WidgetTester tester,
  Finder finder,
  String optionText,
) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionText).last);
  await tester.pumpAndSettle();
}

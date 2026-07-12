import 'package:cts_fluid_power_inspection_app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('production app saves a draft and lists it', (tester) async {
    final workOrder = 'WO-PROD-${DateTime.now().millisecondsSinceEpoch}';
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: CtsFluidPowerInspectionApp()),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.text('New Inspection').first);
    await tester.pumpAndSettle();

    Future<void> enter(String key, String value) async {
      final finder = find.byKey(ValueKey<String>(key));
      await tester.ensureVisible(finder);
      await tester.enterText(finder, value);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 150));
    }

    await enter('field-customer', 'Production Smoke Customer');
    await enter('field-work-order', workOrder);
    await enter('field-customer-reference', 'PO-PROD-SMOKE');
    await enter('field-asset', 'HPU Production Smoke Unit');
    await enter('field-site-location', 'Production smoke bay');
    await enter('field-technician', 'CTS Smoke Tech');
    await enter('field-shop', 'CTS Edmonton');

    await tester.ensureVisible(find.text('Save draft'));
    await tester.tap(find.text('Save draft'));
    await tester.pumpUntilFound(find.textContaining('Progress saved as'));
    expect(find.textContaining('Progress saved as'), findsOneWidget);

    final fluidAddPhoto = find.byKey(const Key('fluid-add-photo-button'));
    await tester.ensureVisible(fluidAddPhoto);
    await tester.tap(fluidAddPhoto);
    await tester.pumpUntilFound(find.text('Use camera'));
    expect(find.text('Choose from device'), findsOneWidget);
    Navigator.of(tester.element(find.text('Use camera'))).pop();
    await tester.pumpAndSettle();

    final completeButton = find.widgetWithText(OutlinedButton, 'Mark complete');
    await tester.ensureVisible(completeButton);
    await tester.pumpAndSettle();
    await tester.tap(completeButton);
    await tester.pumpUntilFound(find.text('Close'));
    expect(find.text('Fluid Level must be answered.'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.selectDropdown('Fluid Level', 'Within Tolerance');
    await tester.selectDropdown('Fluid Clarity', 'Clear');
    await tester.selectDropdown('Tank Cleanout Performed', 'Yes');
    await tester.ensureVisible(find.text('Tank integrity'));
    await tester.tap(find.text('Satisfactory').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hose & Connection Inspection').last);
    await tester.tap(find.text('Satisfactory').last);
    await tester.pumpAndSettle();

    await tester.enterByLabel('Breather part number', 'BR-10');
    await tester.enterByLabel('Pressure filter PN', 'PF-20');
    await tester.enterByLabel('Return filter PN', 'RF-30');
    await tester.selectDropdown('Breather Replaced', 'Yes');
    await tester.selectDropdown('Pressure Filter Replaced', 'Yes');
    await tester.selectDropdown('Return Filter Replaced', 'Yes');

    await tester.selectDropdown(
      'Were you able to have the equipment running?',
      'Yes',
    );
    await tester.enterByLabel('Pump Compensator Setting Observed', '2800');
    await tester.selectDropdown('Change Pump Compensator Setting', 'No');
    await tester.enterByLabel('System Relief Setting Observed', '3100');
    await tester.selectDropdown('Change System Relief Setting', 'No');
    await tester.enterByLabel('Operating Temperature', '48');
    await tester.selectDropdown('Operating Temperature Unit', '°C');
    await tester.enterByLabel('Accumulator Pre-charge', '900');
    await tester.selectDropdown('Charge Accumulator', 'No');
    await tester.selectDropdown('Are additional parts/repairs required?', 'No');

    final signature = find.byKey(const Key('signature_input_area'));
    await tester.ensureVisible(signature);
    await tester.drag(signature, const Offset(160, 40));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.ensureVisible(completeButton);
    await tester.pumpAndSettle();
    await tester.tap(completeButton);
    await tester.pumpUntilFound(
      find.textContaining('Inspection completed as'),
      timeout: const Duration(seconds: 20),
    );
    expect(find.textContaining('Inspection completed as'), findsOneWidget);

    await tester.tap(find.text('Inspections').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('inspection-search-field')),
      workOrder,
    );
    await tester.pumpAndSettle();

    expect(find.text(workOrder), findsWidgets);
    expect(find.text('Production Smoke Customer'), findsWidgets);
  });
}

extension on WidgetTester {
  Future<void> enterByLabel(String label, String value) async {
    final field = find.ancestor(
      of: find.text(label),
      matching: find.byType(TextField),
    );
    await ensureVisible(field.first);
    await enterText(field.first, value);
    await testTextInput.receiveAction(TextInputAction.done);
    await pump(const Duration(milliseconds: 150));
  }

  Future<void> selectDropdown(String label, String option) async {
    final dropdown = find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField<dynamic>,
      ),
    );
    await ensureVisible(dropdown.first);
    await tap(dropdown.first);
    await pumpAndSettle();
    await tap(find.text(option).last);
    await pumpAndSettle();
  }

  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = binding.clock.fromNowBy(timeout);
    do {
      await pump(const Duration(milliseconds: 100));
      if (any(finder)) {
        return;
      }
    } while (binding.clock.now().isBefore(end));

    expect(finder, findsOneWidget);
  }
}

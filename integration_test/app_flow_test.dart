import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cts_fluid_power_inspection_app/data/models/inspection_enums.dart';

import '../test/support/spec_fixtures.dart';
import '../test/support/spec_tablet_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'tablet inspection flow covers create, complete, pdf, email, export, import, and duplicate',
    (WidgetTester tester) async {
      final service = await createService();
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(SpecTabletHarnessApp(service: service));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('dashboard_title')), findsOneWidget);
      await tester.tap(find.byKey(const Key('new_inspection_button')));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(
        find.byKey(const Key('issue_comment_field')),
        'Minor abrasion',
      );
      await tester.tap(find.byKey(const Key('at_risk_button')));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('add_photo_button')));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('critical_button')));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('add_photo_button')));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('loto_ack_button')));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('add_hose_button')));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('signature_button')));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('complete_button')));
      await tester.pump(const Duration(milliseconds: 100));
      final completedInspection = service.inspections.single;
      final validation = service.validateCompletion(completedInspection);
      expect(
        validation.issues,
        isEmpty,
        reason: validation.issues
            .map((issue) => '${issue.fieldKey}: ${issue.message}')
            .join('\n'),
      );
      expect(completedInspection.status, InspectionStatus.complete);
      expect(find.textContaining('Inspection completed'), findsOneWidget);
      expect(find.textContaining('Status: Complete'), findsWidgets);

      final completedDocument = tester
          .widget<Text>(find.byKey(const Key('document_number_text')))
          .data!;

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('pdf_button')));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpUntilFound(find.textContaining('PDF generated at'));
      expect(find.textContaining('PDF generated at'), findsOneWidget);

      await tester.tap(find.byKey(const Key('email_button')));
      await tester.pumpUntilFound(find.textContaining('Marked as emailed'));
      expect(find.textContaining('Marked as emailed'), findsOneWidget);
      expect(find.textContaining('Status: Emailed'), findsWidgets);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('export_button')));
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpUntilFound(find.textContaining('Exported to'));
      expect(find.textContaining('Exported to'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('import_button')));
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pumpUntilFound(find.textContaining('Imported'));
      expect(find.textContaining('Imported'), findsOneWidget);

      final importedDocument = tester
          .widget<Text>(find.byKey(const Key('document_number_text')))
          .data!;
      expect(importedDocument, isNotEmpty);
      expect(importedDocument, isNot(equals(completedDocument)));

      await tester.tap(find.byKey(const Key('duplicate_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Document number:'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Status: Draft'), findsWidgets);
    },
  );
}

extension on WidgetTester {
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

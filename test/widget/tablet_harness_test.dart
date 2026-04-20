import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cts_fluid_power_inspection_app/data/models/inspection_enums.dart';
import 'package:cts_fluid_power_inspection_app/core/constants.dart';

import '../support/spec_tablet_harness.dart';
import '../support/spec_service.dart';

void main() {
  testWidgets(
    'tablet harness shows dashboard and completes a flagged inspection flow',
    (WidgetTester tester) async {
      final service = SpecInspectionService();
      await tester.binding.setSurfaceSize(const Size(1366, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(SpecTabletHarnessApp(service: service));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard_title')), findsOneWidget);
      expect(find.byKey(const Key('new_inspection_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('new_inspection_button')));
      await tester.pumpAndSettle();

      expect(find.text('Job & Asset Identification'), findsOneWidget);
      expect(find.text('Review Summary'), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('issue_comment_field')),
        'Minor abrasion',
      );
      await tester.tap(find.byKey(const Key('at_risk_button')));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('add_photo_button')));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(service.inspections.single.photos, hasLength(1));
      expect(
        service.inspections.single.photos.single.itemKey,
        InspectionItemKeys.overallHoseCondition,
      );

      await tester.tap(find.byKey(const Key('signature_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('complete_button')));
      await tester.pumpAndSettle();

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
      expect(find.byKey(const Key('info_message')), findsOneWidget);
      expect(find.textContaining('Inspection completed'), findsOneWidget);
    },
  );
}

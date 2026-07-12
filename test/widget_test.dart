import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:cts_fluid_power_inspection_app/app.dart';
import 'package:cts_fluid_power_inspection_app/core/workspace_controller.dart';
import 'package:cts_fluid_power_inspection_app/core/workspace_models.dart';
import 'package:cts_fluid_power_inspection_app/core/workspace_providers.dart';
import 'package:cts_fluid_power_inspection_app/data/models/inspection_enums.dart';
import 'package:cts_fluid_power_inspection_app/data/models/inspection_models.dart';
import 'package:cts_fluid_power_inspection_app/features/inspection_form/inspection_form_screen.dart';
import 'package:cts_fluid_power_inspection_app/services/email_service.dart';
import 'package:cts_fluid_power_inspection_app/widgets/condition_selector.dart';
import 'package:cts_fluid_power_inspection_app/widgets/photo_grid.dart';

void main() {
  for (final layout in <(String, Size)>[
    ('phone portrait', const Size(412, 915)),
    ('compact landscape', const Size(800, 600)),
    ('tablet landscape', const Size(1280, 800)),
    ('wide tablet landscape', const Size(1600, 1000)),
  ]) {
    testWidgets('layout matrix: ${layout.$1}', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(layout.$2);
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await _pumpApp(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(FilledButton, 'New Inspection'));
      await tester.pumpAndSettle();

      expect(find.text('Job & Asset Identification'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('layout matrix: 150 percent text scaling', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() async {
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
    });
    await _pumpApp(tester);
    expect(tester.takeException(), isNull);

    final newInspectionButton = find.widgetWithText(
      FilledButton,
      'New Inspection',
    );
    await tester.ensureVisible(newInspectionButton);
    await tester.pumpAndSettle();
    await tester.tap(newInspectionButton);
    await tester.pumpAndSettle();

    expect(find.text('Job & Asset Identification'), findsWidgets);
    expect(tester.takeException(), isNull);

    await _navigateUsingRail(tester, 'Action Items');
    expect(find.text('Open Action Items'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _navigateUsingRail(tester, 'Settings');
    expect(find.text('Restore Inspection'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _navigateUsingRail(tester, 'Inspections');
    final firstInspection = find.text('Moraine Quarry').first;
    await tester.ensureVisible(firstInspection);
    await tester.pumpAndSettle();
    await tester.tap(firstInspection);
    await tester.pumpAndSettle();
    expect(find.text('Inspection Summary'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard shell renders the tablet layout', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('CTS Fluid Power Inspection App'), findsWidgets);
    expect(find.text('Inspection Suite'), findsOneWidget);
    expect(find.text('Critical Reports'), findsOneWidget);
    final activeLabel = tester.widget<Text>(find.text('Active'));
    final railScheme = Theme.of(
      tester.element(find.text('Active')),
    ).colorScheme;
    expect(activeLabel.style?.color, railScheme.onSurfaceVariant);
  });

  testWidgets('dashboard controls meet tablet accessibility guidelines', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('phone portrait controls meet accessibility guidelines', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('navigation rail opens the inspection list', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inspections').last);
    await tester.pumpAndSettle();

    expect(find.text('Inspection Search'), findsOneWidget);
    expect(find.text('Inspection Records'), findsOneWidget);
  });

  testWidgets('compact landscape route matrix renders every primary screen', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    await _navigateUsingRail(tester, 'Inspections');
    expect(find.text('Inspection Search'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final firstInspection = find.text('Moraine Quarry').first;
    await tester.ensureVisible(firstInspection);
    await tester.pumpAndSettle();
    await tester.tap(firstInspection);
    await tester.pumpAndSettle();
    expect(find.text('Inspection Summary'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Job & Asset Identification'), findsWidgets);
    expect(tester.takeException(), isNull);

    await _navigateUsingRail(tester, 'Action Items');
    expect(find.text('Open Action Items'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _navigateUsingRail(tester, 'Settings');
    expect(find.text('Restore Inspection'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _navigateUsingRail(tester, 'Dashboard');
    expect(find.text('Critical Reports'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone portrait route matrix renders every primary screen', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);

    await _navigateUsingRail(tester, 'Inspections');
    expect(find.text('Inspection Search'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final firstInspection = find.text('Moraine Quarry').first;
    await tester.ensureVisible(firstInspection);
    await tester.pumpAndSettle();
    await tester.tap(firstInspection);
    await tester.pumpAndSettle();
    expect(find.text('Inspection Summary'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final editButton = find.widgetWithText(FilledButton, 'Edit');
    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    expect(find.text('Job & Asset Identification'), findsWidgets);
    expect(tester.takeException(), isNull);

    await _navigateUsingRail(tester, 'Action Items');
    expect(find.text('Open Action Items'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _navigateUsingRail(tester, 'Settings');
    expect(find.text('Restore Inspection'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _navigateUsingRail(tester, 'Dashboard');
    expect(find.text('Critical Reports'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report handoff collects and remembers a valid recipient', (
    WidgetTester tester,
  ) async {
    final controller = _RecipientSuggestionsController();
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workspaceProvider.overrideWith((ref) => controller)],
        child: const CtsFluidPowerInspectionApp(),
      ),
    );
    await tester.pumpAndSettle();

    await _navigateUsingRail(tester, 'Inspections');
    final firstInspection = find.text('Moraine Quarry').first;
    await tester.ensureVisible(firstInspection);
    await tester.tap(firstInspection);
    await tester.pumpAndSettle();

    final shareReport = find.text('Share report');
    await tester.ensureVisible(shareReport);
    await tester.tap(shareReport);
    await tester.pumpAndSettle();

    expect(find.text('Share inspection report'), findsOneWidget);
    expect(find.text('recent@example.com'), findsOneWidget);

    final recipientField = find.byKey(const Key('email-recipient-field'));
    await tester.enterText(recipientField, 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Share PDF'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);

    await tester.enterText(recipientField, 'service@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Share PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Was the report sent?'), findsOneWidget);
    expect(controller.lastRecipients, const <String>['service@example.com']);

    await tester.tap(find.text('Not yet'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('inspection editor meets visible accessibility guidelines', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);
    await tester.tap(find.text('New Inspection').first);
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });

  testWidgets('fresh inspection form starts without demo values', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2400, 1800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceProvider.overrideWith(
            (ref) => AppWorkspaceController(seedDemoData: false),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: InspectionFormScreen())),
      ),
    );
    await tester.pump();

    expect(_editableTextWithValue('Moraine Quarry'), findsNothing);
    expect(_editableTextWithValue('R. Ellis'), findsNothing);
    expect(_editableTextWithValue('Parker PGP511A0120CL2H'), findsNothing);
    expect(find.text('Customer signature'), findsOneWidget);
  });

  testWidgets('production form save persists a draft into workspace', (
    WidgetTester tester,
  ) async {
    final controller = AppWorkspaceController(seedDemoData: false);
    await tester.binding.setSurfaceSize(const Size(2400, 1800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workspaceProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(home: Scaffold(body: InspectionFormScreen())),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('field-customer')),
      'Saved Customer',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field-work-order')),
      'WO-SAVED',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field-customer-reference')),
      'PO-SAVED',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field-asset')),
      'HPU Saved Unit',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field-site-location')),
      'Saved service bay',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field-technician')),
      'Saved Tech',
    );
    await tester.enterText(find.byKey(const ValueKey('field-shop')), 'CTS');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.ensureVisible(find.text('Save draft'));
    await tester.pump();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(controller.inspections, hasLength(1));
    expect(controller.inspections.single.customer, 'Saved Customer');
    expect(find.textContaining('Progress saved as'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'Save draft');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(controller.inspections, hasLength(1));
  });

  testWidgets('direct edit form hydrates record and keeps route id on save', (
    WidgetTester tester,
  ) async {
    final now = DateTime(2026, 4, 20, 12);
    final record = InspectionRecord(
      id: 'route-edit-record',
      documentNumber: '20260420-4011',
      status: InspectionStatus.inProgress,
      customer: 'Hydrated Customer',
      workOrderNumber: 'WO-HYDRATED',
      customerReference: 'PO-HYDRATED',
      assetName: 'Hydrated HPU',
      siteLocation: 'Hydrated bay',
      technicianName: 'Hydrated Tech',
      servicingShop: 'CTS Edmonton',
      inspectionDateTime: now,
      createdAt: now,
      updatedAt: now,
    );
    final controller = _FakeHydrationController(record);

    await tester.binding.setSurfaceSize(const Size(2400, 1800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workspaceProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(
          home: Scaffold(
            body: InspectionFormScreen(inspectionId: 'route-edit-record'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(_editableTextWithValue('Hydrated Customer'), findsOneWidget);
    expect(_editableTextWithValue('WO-HYDRATED'), findsOneWidget);

    await tester.ensureVisible(find.text('Save draft'));
    await tester.pump();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(controller.savedDraft?.inspectionId, 'route-edit-record');
    expect(controller.savedDraft?.customer, 'Hydrated Customer');
  });

  testWidgets('direct edit save is disabled until hydration completes', (
    WidgetTester tester,
  ) async {
    final now = DateTime(2026, 4, 20, 12);
    final record = InspectionRecord(
      id: 'slow-route-edit-record',
      documentNumber: '20260420-4012',
      status: InspectionStatus.inProgress,
      customer: 'Slow Hydrated Customer',
      workOrderNumber: 'WO-SLOW',
      customerReference: 'PO-SLOW',
      assetName: 'Slow HPU',
      siteLocation: 'Slow bay',
      technicianName: 'Slow Tech',
      servicingShop: 'CTS Edmonton',
      inspectionDateTime: now,
      createdAt: now,
      updatedAt: now,
    );
    final controller = _FakeHydrationController(record, delayHydration: true);

    await tester.binding.setSurfaceSize(const Size(2400, 1800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workspaceProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(
          home: Scaffold(
            body: InspectionFormScreen(inspectionId: 'slow-route-edit-record'),
          ),
        ),
      ),
    );
    await tester.pump();

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save draft'),
    );
    expect(saveButton.onPressed, isNull);

    controller.completeHydration();
    await tester.pumpAndSettle();

    final hydratedSaveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save draft'),
    );
    expect(hydratedSaveButton.onPressed, isNotNull);
    expect(_editableTextWithValue('Slow Hydrated Customer'), findsOneWidget);
  });

  testWidgets('component cards keep independent part numbers', (tester) async {
    final now = DateTime(2026, 4, 20, 12);
    final record = InspectionRecord(
      id: 'component-record',
      documentNumber: '20260420-4013',
      status: InspectionStatus.inProgress,
      customer: 'Component Customer',
      workOrderNumber: 'WO-COMPONENT',
      customerReference: 'PO-COMPONENT',
      assetName: 'Component HPU',
      siteLocation: 'Component bay',
      technicianName: 'Component Tech',
      servicingShop: 'CTS Edmonton',
      inspectionDateTime: now,
      createdAt: now,
      updatedAt: now,
      componentEntries: <ComponentEntry>[
        ComponentEntry(
          id: 'pump',
          inspectionId: 'component-record',
          componentType: 'Main Pump',
          modelPartNumber: 'PUMP-OLD',
        ),
        ComponentEntry(
          id: 'motor',
          inspectionId: 'component-record',
          componentType: 'Main Motor',
          modelPartNumber: 'MOTOR-OLD',
        ),
      ],
    );
    final controller = _FakeHydrationController(record);
    await tester.binding.setSurfaceSize(const Size(2400, 1800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workspaceProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(
          home: Scaffold(
            body: InspectionFormScreen(inspectionId: 'component-record'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final pump = find.byKey(const ValueKey('component-main-pump'));
    final motor = find.byKey(const ValueKey('component-main-motor'));
    await tester.enterText(pump, 'PUMP-NEW');
    await tester.enterText(motor, 'MOTOR-NEW');
    await tester.ensureVisible(find.text('Save draft'));
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(
      controller.savedDraft?.componentPartNumbers['Main Pump'],
      'PUMP-NEW',
    );
    expect(
      controller.savedDraft?.componentPartNumbers['Main Motor'],
      'MOTOR-NEW',
    );
  });

  testWidgets('photo action asks for a camera or device photo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(2400, 1800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceProvider.overrideWith(
            (ref) => AppWorkspaceController(seedDemoData: false),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: InspectionFormScreen())),
      ),
    );
    await tester.pump();

    final addPhoto = find.byKey(const Key('fluid-add-photo-button'));
    await tester.ensureVisible(addPhoto);
    await tester.tap(addPhoto);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('photo-source-camera')), findsOneWidget);
    expect(find.byKey(const Key('photo-source-gallery')), findsOneWidget);
    expect(find.text('Use camera'), findsOneWidget);
    expect(find.text('Choose from device'), findsOneWidget);
  });

  testWidgets(
    'photo grid does not render dead add controls without a callback',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PhotoGrid(photos: <InspectionPhotoView>[])),
        ),
      );

      expect(find.text('Add first photo'), findsNothing);
      expect(find.text('Add photo'), findsNothing);
    },
  );

  testWidgets('condition selector reports cleared selections', (
    WidgetTester tester,
  ) async {
    ConditionRating? selected = ConditionRating.satisfactory;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConditionSelector(
            value: selected,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Satisfactory'));

    expect(selected, isNull);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workspaceProvider.overrideWith(
          (ref) => AppWorkspaceController(seedDemoData: true),
        ),
      ],
      child: const CtsFluidPowerInspectionApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _navigateUsingRail(WidgetTester tester, String destination) async {
  final destinationIcon = find.byTooltip(destination);
  expect(destinationIcon, findsOneWidget);
  await tester.tap(destinationIcon);
  await tester.pumpAndSettle();
}

Finder _editableTextWithValue(String value) {
  return find.byWidgetPredicate(
    (widget) => widget is EditableText && widget.controller.text == value,
    description: 'EditableText with value "$value"',
  );
}

class _FakeHydrationController extends AppWorkspaceController {
  _FakeHydrationController(this.record, {bool delayHydration = false})
    : _hydrationCompleter = delayHydration
          ? Completer<InspectionRecord?>()
          : null,
      super(seedDemoData: false);

  final InspectionRecord record;
  final Completer<InspectionRecord?>? _hydrationCompleter;
  InspectionFormDraft? savedDraft;

  void completeHydration() {
    final completer = _hydrationCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(record);
    }
  }

  @override
  Future<InspectionRecord?> inspectionRecordById(String id) async {
    final completer = _hydrationCompleter;
    if (completer != null) {
      return completer.future;
    }
    return id == record.id ? record : null;
  }

  @override
  Future<InspectionSummary> saveFormDraft(
    InspectionFormDraft draft, {
    bool complete = false,
  }) async {
    savedDraft = draft;
    return InspectionSummary(
      id: record.id,
      documentNumber: record.documentNumber,
      customer: draft.customer,
      workOrderNumber: draft.workOrderNumber,
      customerReference: draft.customerReference,
      assetName: draft.assetName,
      siteLocation: draft.siteLocation,
      technicianName: draft.technicianName,
      servicingShop: draft.servicingShop,
      inspectionDateTime: record.inspectionDateTime,
      createdAt: record.createdAt,
      status: record.status,
      sections: const <InspectionSectionView>[],
      actionItems: const <InspectionActionItemView>[],
      photos: const <InspectionPhotoView>[],
      flaggedCount: 0,
      atRiskCount: 0,
      unsatisfactoryCount: 0,
      criticalCount: 0,
      photoCount: 0,
      lastUpdatedAt: record.updatedAt,
    );
  }
}

class _RecipientSuggestionsController extends AppWorkspaceController {
  _RecipientSuggestionsController() : super(seedDemoData: true);

  List<String>? lastRecipients;

  @override
  Future<List<RecentEmailRecipient>> emailRecipientSuggestions(
    String customer,
  ) async {
    return <RecentEmailRecipient>[
      RecentEmailRecipient(
        email: 'recent@example.com',
        customer: customer,
        lastUsedAt: DateTime(2026, 4, 20, 12),
        usageCount: 2,
      ),
    ];
  }

  @override
  Future<void> emailInspectionPdf(
    String inspectionId, {
    List<String> recipients = const <String>[],
  }) async {
    lastRecipients = List<String>.of(recipients);
  }
}

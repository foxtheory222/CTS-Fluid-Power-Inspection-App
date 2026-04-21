import 'dart:io';

import 'package:cts_fluid_power_inspection_app/app.dart';
import 'package:cts_fluid_power_inspection_app/core/workspace_controller.dart';
import 'package:cts_fluid_power_inspection_app/core/workspace_providers.dart';
import 'package:cts_fluid_power_inspection_app/data/repositories/inspection_repository.dart';
import 'package:cts_fluid_power_inspection_app/features/dashboard/dashboard_screen.dart';
import 'package:cts_fluid_power_inspection_app/features/inspection_list/inspection_list_screen.dart';
import 'package:cts_fluid_power_inspection_app/services/document_number_service.dart';
import 'package:cts_fluid_power_inspection_app/services/email_service.dart';
import 'package:cts_fluid_power_inspection_app/services/pdf_service.dart';
import 'package:cts_fluid_power_inspection_app/services/photo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/persistence_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late TestAppDatabase database;
  late InspectionRepository repository;
  late AppWorkspaceController controller;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cts_widget_app_test_');
    database = TestAppDatabase(tempDir);
    repository = InspectionRepository(
      database: database,
      documentNumberService: DocumentNumberService(),
    );
    controller = AppWorkspaceController(
      repository: repository,
      pdfService: PdfService(),
      photoService: PhotoService(photoPicker: FakeInspectionPhotoPicker()),
      emailService: EmailService(shareAdapter: FakeEmailShareAdapter()),
    );
    await controller.refresh();
  });

  tearDown(() async {
    await database.close();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } on FileSystemException {
      // The sqflite ffi worker can keep a short-lived handle open on Windows.
    }
  });

  Widget buildApp({Widget? home}) {
    return ProviderScope(
      overrides: [workspaceProvider.overrideWith((ref) => controller)],
      child: home == null
          ? const CtsFluidPowerInspectionApp()
          : MaterialApp(home: Scaffold(body: home)),
    );
  }

  testWidgets('dashboard shows the empty state for the real app', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildApp(home: const DashboardScreen()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Inspection Operations'), findsWidgets);
    expect(find.text('Fluid Power Inspection Reports'), findsWidgets);
    expect(find.text('No inspections yet'), findsWidgets);
    expect(find.text('Tap New Inspection to start.'), findsWidgets);
  });

  testWidgets('inspection list screen shows search and empty state', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildApp(home: const InspectionListScreen()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Inspection Search'), findsOneWidget);
    expect(find.text('Inspection Records'), findsOneWidget);
    expect(find.text('No inspections yet'), findsWidgets);
  });
}

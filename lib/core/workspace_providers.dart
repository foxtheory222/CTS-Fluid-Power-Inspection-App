import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/database/app_database.dart';
import '../data/repositories/inspection_repository.dart';
import '../services/document_number_service.dart';
import '../services/backup_service.dart';
import '../services/email_service.dart';
import '../services/pdf_service.dart';
import '../services/photo_service.dart';
import 'workspace_controller.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final documentNumberServiceProvider = Provider<DocumentNumberService>(
  (ref) => DocumentNumberService(),
);

final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  return InspectionRepository(
    database: ref.watch(appDatabaseProvider),
    documentNumberService: ref.watch(documentNumberServiceProvider),
  );
});

final pdfServiceProvider = Provider<PdfService>((ref) => PdfService());

final emailServiceProvider = Provider<EmailService>((ref) => EmailService());

final photoServiceProvider = Provider<PhotoService>((ref) => PhotoService());

final backupServiceProvider = Provider<BackupService>((ref) => BackupService());

final workspaceProvider = ChangeNotifierProvider<AppWorkspaceController>((ref) {
  final controller = AppWorkspaceController(
    repository: ref.watch(inspectionRepositoryProvider),
    pdfService: ref.watch(pdfServiceProvider),
    emailService: ref.watch(emailServiceProvider),
    backupService: ref.watch(backupServiceProvider),
    seedDemoData: false,
  );
  unawaited(controller.loadPersistedInspections());
  return controller;
});

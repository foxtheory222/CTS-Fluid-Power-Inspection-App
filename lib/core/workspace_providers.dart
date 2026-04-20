import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show ChangeNotifierProvider;

import '../data/database/app_database.dart';
import '../data/repositories/inspection_repository.dart';
import '../services/document_number_service.dart';
import '../services/email_service.dart';
import '../services/pdf_service.dart';
import '../services/photo_service.dart';
import 'workspace_controller.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

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

final photoServiceProvider = Provider<PhotoService>((ref) => PhotoService());

final emailServiceProvider = Provider<EmailService>((ref) => EmailService());

final workspaceProvider = ChangeNotifierProvider<AppWorkspaceController>(
  (ref) => AppWorkspaceController(
    repository: ref.watch(inspectionRepositoryProvider),
    pdfService: ref.watch(pdfServiceProvider),
    photoService: ref.watch(photoServiceProvider),
    emailService: ref.watch(emailServiceProvider),
  ),
);

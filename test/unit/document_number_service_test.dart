import 'dart:io';

import 'package:cts_fluid_power_inspection_app/core/constants.dart';
import 'package:cts_fluid_power_inspection_app/services/document_number_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('doc_number_service_test_');
    final dbPath =
        '${tempDir.path}${Platform.pathSeparator}${AppConstants.databaseName}';
    db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE document_sequences(
              date_key TEXT PRIMARY KEY,
              last_sequence INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('generates sequential document numbers per day', () async {
    final service = DocumentNumberService();
    expect(
      await service.nextDocumentNumber(db, DateTime.utc(2026, 4, 18)),
      '20260418-0001',
    );
    expect(
      await service.nextDocumentNumber(db, DateTime.utc(2026, 4, 18)),
      '20260418-0002',
    );
    expect(
      await service.nextDocumentNumber(db, DateTime.utc(2026, 4, 19)),
      '20260419-0001',
    );
  });
}

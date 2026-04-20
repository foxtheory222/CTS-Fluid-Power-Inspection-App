import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/constants.dart';
import '../../core/file_utils.dart';

class AppDatabase {
  AppDatabase();

  Database? _database;

  Future<Database> open() async {
    if (_database != null) {
      return _database!;
    }

    final String dbPath = p.join(
      (await FileUtils.appRootDirectory()).path,
      AppConstants.databaseName,
    );

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE inspections(
            id TEXT PRIMARY KEY,
            document_number TEXT NOT NULL UNIQUE,
            status TEXT NOT NULL,
            customer TEXT NOT NULL,
            work_order_number TEXT NOT NULL,
            asset_name TEXT NOT NULL,
            technician_name TEXT NOT NULL,
            customer_reference TEXT NOT NULL,
            site_location TEXT NOT NULL,
            servicing_shop TEXT NOT NULL,
            inspection_date_time TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            completed_at TEXT,
            emailed_at TEXT,
            generated_pdf_path TEXT,
            has_critical INTEGER NOT NULL DEFAULT 0,
            flagged_count INTEGER NOT NULL DEFAULT 0,
            photo_count INTEGER NOT NULL DEFAULT 0,
            payload_json TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE document_sequences(
            date_key TEXT PRIMARY KEY,
            last_sequence INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE email_recipients(
            id TEXT PRIMARY KEY,
            email TEXT NOT NULL,
            customer TEXT,
            last_used_at TEXT NOT NULL,
            usage_count INTEGER NOT NULL DEFAULT 0,
            is_customer_default INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_inspections_status ON inspections(status)',
        );
        await db.execute(
          'CREATE INDEX idx_inspections_updated ON inspections(updated_at DESC)',
        );
        await db.execute(
          'CREATE INDEX idx_inspections_document_number ON inspections(document_number)',
        );
        await db.execute(
          'CREATE INDEX idx_inspections_customer ON inspections(customer)',
        );
        await db.execute(
          'CREATE INDEX idx_inspections_work_order_number ON inspections(work_order_number)',
        );
        await db.execute(
          'CREATE INDEX idx_inspections_asset_name ON inspections(asset_name)',
        );
        await db.execute(
          'CREATE INDEX idx_inspections_technician_name ON inspections(technician_name)',
        );
        await db.execute(
          'CREATE INDEX idx_inspections_inspection_date_time ON inspections(inspection_date_time)',
        );
      },
    );

    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}

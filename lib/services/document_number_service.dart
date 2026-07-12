import 'package:sqflite/sqflite.dart';

import '../core/date_time_utils.dart';

class DocumentNumberService {
  Future<String> nextDocumentNumber(Database db, DateTime createdAt) async {
    final String dateKey = DateTimeUtils.documentDateKey(createdAt);

    return db.transaction((Transaction txn) async {
      final List<Map<String, Object?>> rows = await txn.query(
        'document_sequences',
        columns: <String>['last_sequence'],
        where: 'date_key = ?',
        whereArgs: <Object?>[dateKey],
        limit: 1,
      );

      var nextSequence = rows.isEmpty
          ? 1
          : ((rows.first['last_sequence'] as num).toInt() + 1);

      while (true) {
        final candidate = '$dateKey-${nextSequence.toString().padLeft(4, '0')}';
        final existing = await txn.query(
          'inspections',
          columns: <String>['document_number'],
          where: 'document_number = ?',
          whereArgs: <Object?>[candidate],
          limit: 1,
        );
        if (existing.isEmpty) {
          break;
        }
        nextSequence++;
      }

      await txn.insert('document_sequences', <String, Object?>{
        'date_key': dateKey,
        'last_sequence': nextSequence,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      return '$dateKey-${nextSequence.toString().padLeft(4, '0')}';
    });
  }
}

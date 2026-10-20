/// Opens the SQLite files written by DITING 1.4.3 instead of creating new ones.
///
/// The file names, `user_version` and WAL mode are owned by Room; sqflite is
/// used only as a client so an upgraded install keeps reading its own data.
library;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LegacyDatabase {
  LegacyDatabase._();

  /// Normal (full tunnel) database, `AppDatabase`, version 3.
  static const mainFile = 'diting_database';

  /// Express-mode database, version 2.
  static const expressFile = 'diting_express';

  /// Server-mode rules database, version 3.
  static const serverFile = 'diting_dns_rules';

  /// Returns null when the file is absent (fresh install), so callers can
  /// distinguish "no legacy data yet" from an open failure.
  static Future<Database?> open(String fileName) async {
    final path = p.join(await getDatabasesPath(), fileName);
    if (!await databaseExists(path)) {
      return null;
    }
    try {
      return await openDatabase(
        path,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      );
    } on DatabaseException catch (error) {
      debugPrint('legacy database open failed: $fileName ($error)');
      return null;
    }
  }
}

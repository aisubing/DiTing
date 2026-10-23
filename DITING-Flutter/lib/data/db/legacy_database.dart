/// Opens the three legacy SQLite databases, creating them when absent.
///
/// An upgraded install keeps the files Room already created, with the same
/// columns and `user_version`. After a fresh install or a data wipe the files
/// do not exist, so they are created from [LegacySchema]; both paths yield a
/// schema identical to the legacy one, which the rest of the app relies on.
library;

import 'package:diting/data/db/legacy_schema.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LegacyDatabase {
  LegacyDatabase._();

    /// Normal (full tunnel) database, version 3.
  static const mainFile = 'diting_database';

  /// Express-mode database, version 2.
  static const expressFile = 'diting_express';

  /// Server-mode rules database, version 3.
  static const serverFile = 'diting_dns_rules';

    /// Opens [fileName], creating it when absent.
    ///
    /// Null means the database could neither be opened nor created, for example
    /// on a full disk; callers degrade to "no rule database" instead of blocking
    /// startup.
  static Future<Database?> open(String fileName, {bool create = true}) async {
    final path = p.join(await getDatabasesPath(), fileName);
    if (!await databaseExists(path)) {
      if (!create) return null;
      return _create(path, fileName);
    }
    try {
      return await openDatabase(path, onConfigure: _configure);
    } on DatabaseException catch (error) {
      debugPrint('legacy database open failed: $fileName ($error)');
      return null;
    }
  }

    /// `PRAGMA foreign_keys` is per connection, not stored in the file, so it has
    /// to be set on every open; without it `*_source` rows are not cascaded.
  static Future<void> _configure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<Database?> _create(String path, String fileName) async {
    final statements = LegacySchema.statementsFor(fileName);
    try {
      return await openDatabase(
        path,
        version: LegacySchema.versionOf(fileName),
        onConfigure: _configure,
        onCreate: (db, version) async {
          for (final statement in statements) {
            await db.execute(statement);
          }
        },
        onUpgrade: (db, from, to) async {
                    // The file exists with a lower `user_version`, which only happens to
                    // a damaged or externally modified database. Patching is cheaper than
                    // asking the user to reinstall.
          await _createIfMissing(db, statements);
        },
      );
    } on DatabaseException catch (error) {
      debugPrint('legacy database create failed: $fileName ($error)');
            // Drop the half-built file, otherwise the next launch opens a database
            // missing tables and fails with "no such column".
      try {
        await deleteDatabase(path);
      } on DatabaseException catch (cleanupError) {
        debugPrint('legacy database cleanup failed: $fileName ($cleanupError)');
      }
      return null;
    }
  }

    /// Creates only the missing tables and indexes.
    ///
    /// `IF NOT EXISTS` cannot repair a table that exists with different columns;
    /// that only happens to externally damaged files, where partial recovery is
    /// all that is possible.
  static Future<void> _createIfMissing(
    Database db,
    List<String> statements,
  ) async {
    for (final statement in statements) {
      try {
        await db.execute(_withIfNotExists(statement));
      } on DatabaseException catch (error) {
        debugPrint('legacy schema patch skipped: $error');
      }
    }
  }

    /// Inserts `IF NOT EXISTS` into a `CREATE TABLE` / `CREATE INDEX` statement.
  static String _withIfNotExists(String statement) {
    if (statement.startsWith('CREATE UNIQUE INDEX ')) {
      return statement.replaceFirst(
        'CREATE UNIQUE INDEX ',
        'CREATE UNIQUE INDEX IF NOT EXISTS ',
      );
    }
    if (statement.startsWith('CREATE INDEX ')) {
      return statement.replaceFirst(
        'CREATE INDEX ',
        'CREATE INDEX IF NOT EXISTS ',
      );
    }
    return statement.replaceFirst(
      'CREATE TABLE ',
      'CREATE TABLE IF NOT EXISTS ',
    );
  }
}

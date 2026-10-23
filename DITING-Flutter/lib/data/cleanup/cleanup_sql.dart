library;

import 'package:diting/data/db/legacy_database.dart';
import 'package:diting/data/db/preset_whitelist.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

/// Opens each database file at most once per cleanup session.
///
/// "Clear all local data" runs a dozen actions in a row, and every
/// `LegacyDatabase.open` call re-checks and reopens the file.
class CleanupDatabases {
  CleanupDatabases(this._open);

  final Future<Database?> Function(String fileName) _open;
  final Map<String, Database?> _cache = {};

  Future<Database?> of(String fileName) async =>
      _cache.containsKey(fileName) ? _cache[fileName] : (_cache[fileName] = await _open(fileName));

  Future<Database?> get main => of(LegacyDatabase.mainFile);

  Future<Database?> get express => of(LegacyDatabase.expressFile);

  Future<Database?> get server => of(LegacyDatabase.serverFile);

  /// Rule databases that exist, in fixed order: main, express, server.
  ///
  /// The order is pinned so map iteration order cannot make tests flaky.
  Future<List<Database>> ruleDatabases() async {
    final databases = <Database>[];
    for (final fileName in _ruleFiles) {
      final db = await of(fileName);
      if (db != null) databases.add(db);
    }
    return databases;
  }

  /// Databases holding runtime tables (logs, cache): main and express only.
  Future<List<Database>> runtimeDatabases() async {
    final databases = <Database>[];
    for (final fileName in [LegacyDatabase.mainFile, LegacyDatabase.expressFile]) {
      final db = await of(fileName);
      if (db != null) databases.add(db);
    }
    return databases;
  }

  bool isMain(Database db) => db.path == _cache[LegacyDatabase.mainFile]?.path;

  static const _ruleFiles = [
    LegacyDatabase.mainFile,
    LegacyDatabase.expressFile,
    LegacyDatabase.serverFile,
  ];
}

/// Deletes all rows; a missing table returns 0 and logs why.
Future<int> deleteAllRows(DatabaseExecutor db, String table) => _guard(
  () => db.delete(table),
  'delete $table',
);

/// Deletes matching rows; a missing table or column returns 0.
Future<int> deleteRowsWhere(
  DatabaseExecutor db,
  String table,
  String where,
) => _guard(() => db.delete(table, where: where), 'delete $table ($where)');

/// Deletes rule rows that no source row references (`NOT EXISTS`).
Future<int> deleteOrphanRows(
  DatabaseExecutor db,
  String ruleTable,
  String sourceTable,
) => deleteRowsWhere(
  db,
  ruleTable,
  'NOT EXISTS (SELECT 1 FROM $sourceTable s WHERE s.ruleId = $ruleTable.id)',
);

/// Zeroes subscription import metadata after the rule tables are cleared.
///
/// A stale ETag would get a 304 from the server and the rules would never return.
Future<void> resetSubscriptionImportState(DatabaseExecutor db) async {
  try {
    await db.update('subscription', {
      'ruleCount': 0,
      'lastUpdated': 0,
      'httpEtag': null,
      'httpLastModified': null,
      'ruleSetHash': null,
    });
  } on DatabaseException catch (error) {
    debugPrint('cleanup: subscription reset skipped ($error)');
  }
}

/// Deletes auto-update items whose subscription no longer exists.
Future<void> deleteOrphanAutoUpdateItems(DatabaseExecutor db) async {
  try {
    await db.delete(
      'subscription_auto_update_item',
      where: 'subscriptionId NOT IN (SELECT id FROM subscription)',
    );
  } on DatabaseException catch (error) {
    debugPrint('cleanup: auto-update orphans skipped ($error)');
  }
}

/// Reads the preset whitelist asset; empty when it cannot be loaded.
///
/// Callers must skip seeding on an empty result: deleting preset rows before the
/// asset is known to load leaves the seeded flag set with an empty whitelist.
Future<List<({String domain, String group})>> loadPresetEntries({
  Future<String> Function()? load,
}) async {
  final asset = load ?? (() => rootBundle.loadString('assets/https_passthrough.txt'));
  try {
    return parsePresetWhitelist(await asset());
  } on FlutterError catch (error) {
    debugPrint('cleanup: preset whitelist asset unavailable ($error)');
    return const [];
  }
}

Future<int> _guard(Future<int> Function() action, String label) async {
  try {
    return await action();
  } on DatabaseException catch (error) {
    debugPrint('cleanup: $label ignored ($error)');
    return 0;
  }
}

import 'package:diting/data/db/legacy_database.dart';
import 'package:diting/data/db/preset_whitelist.dart';
import 'package:diting/data/db/rule_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

typedef RuleBootstrap = ({
  RuleRepository? repository,
  Map<RuleKind, List<MockRule>> rules,
});

/// Opens the legacy database and applies the one-time preset whitelist seed.
///
/// 1.4.3 re-seeds the preset when the versionCode or preset schema changes; the
/// same gate is kept here so an upgrade does not silently drop the passthrough
/// hosts that keep Play services reachable.
Future<RuleBootstrap> bootstrapRules(
  LegacySettings settings, {
  int? versionCode,
}) async {
  final db = await LegacyDatabase.open(LegacyDatabase.mainFile);
  if (db == null) {
    return (repository: null, rules: _emptyRules());
  }

  final repository = RuleRepository(db);
  await _seedPresetIfNeeded(repository, settings, versionCode ?? 10404);
  try {
    return (repository: repository, rules: await repository.loadAll());
  } on DatabaseException catch (error) {
    debugPrint('rule load failed: $error');
    return (repository: null, rules: _emptyRules());
  }
}

Future<void> _seedPresetIfNeeded(
  RuleRepository repository,
  LegacySettings settings,
  int versionCode,
) async {
  final target = versionCode * 1000 + 2;
  if (settings.defaultWhitelistInitialized &&
      settings.defaultWhitelistSeededVersion == target) {
    return;
  }
  try {
    final content = await rootBundle.loadString('assets/https_passthrough.txt');
    final entries = parsePresetWhitelist(content);
    if (entries.isEmpty) {
      // Never mark an empty asset as seeded: the next launch must retry.
      debugPrint('preset whitelist asset produced no entries');
      return;
    }
    await repository.resetPresetWhitelist(entries);
    settings.markDefaultWhitelistSeeded(versionCode);
  } on FlutterError catch (error) {
    debugPrint('preset whitelist asset missing: $error');
  } on DatabaseException catch (error) {
    debugPrint('preset whitelist seed failed: $error');
  }
}

Map<RuleKind, List<MockRule>> _emptyRules() => {
  for (final kind in RuleKind.values) kind: const [],
};

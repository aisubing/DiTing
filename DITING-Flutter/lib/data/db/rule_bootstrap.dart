import 'package:diting/data/db/legacy_database.dart';
import 'package:diting/data/db/preset_whitelist.dart';
import 'package:diting/data/db/rule_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

typedef RuleBootstrap = ({RuleRepository? repository});

/// Opens the legacy database and seeds the preset whitelist once per version code, so an upgrade
/// keeps the passthrough hosts Play services need; [versionCode] has no default.
///
/// Only the cheap parts live here: the full-table [RuleRepository.loadAll] that used to run before
/// `runApp` blocked the first frame for seconds on subscription-sized datasets, so it now runs via
/// [loadInitialRules] once the UI is up.
Future<RuleBootstrap> bootstrapRules(
  LegacySettings settings, {
  required int versionCode,
}) async {
  final db = await LegacyDatabase.open(LegacyDatabase.mainFile);
  if (db == null) {
    return (repository: null);
  }

  final repository = RuleRepository(db);
  await _seedPresetIfNeeded(repository, settings, versionCode);
  return (repository: repository);
}

/// Post-`runApp` fill for `initialRulesProvider`; a missing repository or failed read yields the
/// empty snapshot rather than blocking startup.
Future<Map<RuleKind, List<MockRule>>> loadInitialRules(
  RuleRepository? repository,
) async {
  if (repository == null) {
    return _emptyRules();
  }
  try {
    return await repository.loadAll();
  } on DatabaseException catch (error) {
    debugPrint('rule load failed: $error');
    return _emptyRules();
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

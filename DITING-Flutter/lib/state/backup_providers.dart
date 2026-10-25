library;

import 'dart:async';

import 'package:diting/data/backup/backup_exporter.dart';
import 'package:diting/data/backup/backup_importer.dart';
import 'package:diting/data/backup/backup_models.dart';
import 'package:diting/data/db/rule_index_bridge.dart';
import 'package:diting/data/db/rule_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/native/platform_bridge.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/state/cleanup_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/subscription_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackupStats {
  const BackupStats({
    required this.providers,
    required this.subscriptions,
    required this.customRules,
    required this.listedApps,
  });

  const BackupStats.empty()
    : providers = 0,
      subscriptions = 0,
      customRules = 0,
      listedApps = 0;

  final int providers;
  final int subscriptions;
  final int customRules;
  final int listedApps;
}

/// Real stats: providers from prefs, subscriptions and rules from their tables, apps from three
/// lists.
final backupStatsProvider = FutureProvider<BackupStats>((ref) async {
  ref.watch(legacySettingsRevisionProvider);
  ref.watch(subscriptionRevisionProvider);
  ref.watch(dnsLogRevisionProvider);
  final settings = ref.watch(legacySettingsProvider);
  final db = await ref.watch(activeLogDatabaseProvider.future);

  var subscriptions = 0;
  var customRules = 0;
  if (db != null) {
    try {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM subscription',
      );
      subscriptions = (rows.first['n'] as num?)?.toInt() ?? 0;
    } on Exception {
      subscriptions = 0;
    }
    final repository = RuleRepository(db);
    for (final kind in [RuleKind.block, RuleKind.allow, RuleKind.rewrite]) {
      try {
        final rules = await repository.loadKind(kind);
        customRules += rules.where((rule) => rule.source == RuleSource.user).length;
      } on Exception {
        // A missing table counts as 0: this tile is an overview, not an error.
        continue;
      }
    }
  }

  final listedApps = {
    ...settings.excludedPackages,
    ...settings.blockedAppPackages,
    ...settings.httpInspectionPackages,
    ...settings.appAllowlistRules.keys,
  }.length;

  return BackupStats(
    providers: _providerCount(settings.userProvidersJson),
    subscriptions: subscriptions,
    customRules: customRules,
    listedApps: listedApps,
  );
});

int _providerCount(String? raw) => parseUserProviders(raw).length;

final backupExporterProvider = Provider<BackupExporter>(
  (ref) => const BackupExporter(),
);

final backupImporterProvider = Provider<BackupImporter>(
  (ref) => const BackupImporter(),
);

class BackupActions {
  BackupActions(this._ref);

  final Ref _ref;

  Future<BackupExportResult> export(Set<BackupGroup> groups) async {
    final db = await _ref.read(activeLogDatabaseProvider.future);
    final result = await _ref.read(backupExporterProvider).export(
      BackupExportSource(
        settings: _ref.read(legacySettingsProvider),
        database: db,
      ),
      groups: groups,
    );
    return result;
  }

  /// Saves via the system picker; returns the user-facing result.
  Future<DocumentSaveResult> saveToDocument(BackupExportResult export) =>
      _ref.read(platformBridgeProvider).exportDocument(
        name: export.fileName,
        content: export.content,
      );

  /// Opens the system picker, parses and merges the picked file.
  Future<BackupImportResult> importFromDocument() async {
    final picked = await _ref.read(platformBridgeProvider).importDocument();
    if (picked.cancelled) return const BackupImportResult.cancelled();
    if (picked.error != null) return BackupImportResult.failed(picked.error!);
    final text = picked.text;
    if (text == null) return const BackupImportResult.failed('无法读取所选文件');
    return importText(text, sourceName: picked.name);
  }

  /// Merges backup text (WebDAV restore path, no file picker).
  Future<BackupImportResult> importText(
    String text, {
    String? sourceName,
  }) async {
    final db = await _ref.read(activeLogDatabaseProvider.future);
    final result = await _ref.read(backupImporterProvider).import(
      text,
      BackupImportTarget(
        store: _ref.read(legacyPrefsStoreProvider),
        database: db,
      ),
      sourceName: sourceName,
    );
    if (!result.failed && !result.cancelled) {
      _invalidate();
      _refreshIndexesIfNeeded(result);
    }
    return result;
  }

  /// Rule-writing groups went into the active database; recompile its tries so the next service
  /// start does not pay the compile itself (the stamp re-check would force it otherwise).
  void _refreshIndexesIfNeeded(BackupImportResult result) {
    const ruleGroups = {
      BackupGroup.subscriptions,
      BackupGroup.domainRules,
      BackupGroup.rewriteDomain,
      BackupGroup.rewriteCname,
      BackupGroup.addressRules,
    };
    if (result.outcomes.every((outcome) => !ruleGroups.contains(outcome.group))) {
      return;
    }
    final dataset = _ref.read(workModeProvider) == AppWorkMode.express
        ? RuleIndexDataset.express
        : RuleIndexDataset.normal;
    unawaited(refreshRuleIndexes(dataset));
  }

  void _invalidate() {
    _ref.read(legacySettingsRevisionProvider.notifier).bump();
    _ref.read(subscriptionRevisionProvider.notifier).bump();
    _ref.read(dnsLogRevisionProvider.notifier).bump();
  }
}

final backupActionsProvider = Provider<BackupActions>(BackupActions.new);

// ignore_for_file: prefer_initializing_formals
// False positive here: fields are private `_xxx`, and Dart forbids named
// parameters starting with `_`, so `required this._prefs` is impossible.
library;

import 'package:diting/data/cleanup/cleanup_models.dart';
import 'package:diting/data/cleanup/cleanup_sql.dart';
import 'package:diting/data/db/rule_repository.dart';
import 'package:diting/data/native/ca_bridge.dart';
import 'package:diting/data/native/outbound_proxy_bridge.dart';
import 'package:diting/data/native/platform_bridge.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

export 'cleanup_models.dart';

/// Runs all cleanup actions from one class.
///
/// They share handles (prefs, database cache, native channels) and
/// [CleanupAction.allData] runs them in sequence.
class DataCleanupService {
  DataCleanupService({
    required LegacyPrefsStore prefs,
    required PlatformBridge platform,
    required OutboundProxyStore outboundProxy,
    required Future<Database?> Function(String fileName) openDatabase,
    required int appVersionCode,
    CaCertificateService? caCertificate,
    Future<String> Function()? loadPresetAsset,
  }) : _prefs = prefs,
       _platform = platform,
       _outboundProxy = outboundProxy,
       _appVersionCode = appVersionCode,
       _ca = caCertificate ?? const UnavailableCaCertificateService(),
       _loadPresetAsset = loadPresetAsset,
       _databases = CleanupDatabases(openDatabase);

  final LegacyPrefsStore _prefs;
  final PlatformBridge _platform;
  final OutboundProxyStore _outboundProxy;

  /// App version code used for the seed marker; must match startup seeding.
  ///
  /// A lower value re-seeds on the next launch; a higher one skips future
  /// upgrade seeds entirely.
  final int _appVersionCode;

  final CaCertificateService _ca;
  final Future<String> Function()? _loadPresetAsset;
  final CleanupDatabases _databases;
  LegacySettings get _settings => LegacySettings(_prefs);

  /// Calls a native channel, degrading to 0 when the channel is unavailable.
  ///
  /// Actions that touch native storage also clear prefs; an exception here must
  /// not skip the prefs half.
  Future<int> _platformCall(Future<int> Function() call) async {
    try {
      return await call();
    } catch (error) {
      debugPrint('cleanup: platform call degraded to 0 ($error)');
      return 0;
    }
  }

  /// Prefs containers of the three rule datasets.
  static const _datasetContainers = [
    LegacySettings.uiContainer,
    LegacySettings.expressContainer,
    LegacySettings.serverContainer,
  ];

  /// Runs one action; any exception becomes [CleanupResult.failed].
  ///
  /// Never rethrows: the caller runs after a confirmation dialog and needs a
  /// reason, not a red screen.
  Future<CleanupResult> run(CleanupAction action) async {
    try {
      return switch (action) {
        CleanupAction.logs => await _clearLogs(),
        CleanupAction.traffic => await _clearTraffic(),
        CleanupAction.crash => _result(
          action,
          await _platformCall(_platform.clearCrashLogs),
        ),
        CleanupAction.dnsCache => await _clearDnsCache(),
        CleanupAction.providerWeights => _resetWeights(
          action,
          'provider_health_json',
        ),
        CleanupAction.bootstrapWeights => _resetWeights(
          action,
          'bootstrap_health_json',
        ),
        CleanupAction.domainRules => await _clearDomainRules(),
        CleanupAction.addressRules => await _clearAddressRules(),
        CleanupAction.subscriptions => await _clearSubscriptions(),
        CleanupAction.appRules => _resetAppRules(),
        CleanupAction.outboundProxy => await _resetOutboundProxy(),
        CleanupAction.caCertificate => await _resetCaCertificate(),
        CleanupAction.downloadCache => _result(
          action,
          await _platformCall(_platform.clearUpdateCache),
        ),
        CleanupAction.customBackground => await _clearCustomBackground(),
        CleanupAction.settingsGuides => _resetSettingsGuides(),
        CleanupAction.allData => await _clearAllLocalData(),
      };
    } catch (error) {
      debugPrint('data cleanup failed: ${action.name} ($error)');
      return CleanupResult.failed(action, '清理失败：$error');
    }
  }

  CleanupResult _result(CleanupAction action, int removed, {String? detail}) =>
      CleanupResult(action: action, removed: removed, detail: detail);



  /// Clears the four log tables.
  ///
  /// Per-table tolerance: the express database has no `http_request_log`, and a
  /// missing table must not skip the others.
  Future<CleanupResult> _clearLogs() async {
    var removed = 0;
    for (final db in await _databases.runtimeDatabases()) {
      for (final table in const [
        'dns_log',
        'http_request_log',
        'dns_race_log',
        'bootstrap_log',
      ]) {
        removed += await deleteAllRows(db, table);
      }
    }
    return _result(CleanupAction.logs, removed);
  }

  /// Clears `app_traffic_daily`.
  ///
  /// Main database only: the express and server databases lack this table.
  Future<CleanupResult> _clearTraffic() async {
    final db = await _databases.main;
    final removed = db == null ? 0 : await deleteAllRows(db, 'app_traffic_daily');
    return _result(CleanupAction.traffic, removed);
  }

  /// Clears the persisted `dns_cache` table.
  ///
  /// The engine keeps its own in-memory LRU, which is not cleared here.
  Future<CleanupResult> _clearDnsCache() async {
    var removed = 0;
    for (final db in await _databases.runtimeDatabases()) {
      removed += await deleteAllRows(db, 'dns_cache');
    }
    return _result(CleanupAction.dnsCache, removed);
  }



  /// Removes the stored provider/bootstrap health samples.
  ///
  /// Each dataset keeps its own copy, so all three containers are cleared.
  CleanupResult _resetWeights(CleanupAction action, String key) {
    var removed = 0;
    for (final container in _datasetContainers) {
      if (_removeKey(container, key)) removed++;
    }
    return _result(action, removed);
  }



  /// Clears block, allow, cosmetic and domain-subscription data, then re-seeds
  /// the preset whitelist on the main database.
  ///
  /// Skipping the re-seed would block hosts that must stay reachable.
  Future<CleanupResult> _clearDomainRules() async {
    final preset = await loadPresetEntries(load: _loadPresetAsset);
    var removed = 0;
    for (final db in await _databases.ruleDatabases()) {
      removed += await db.transaction<int>((txn) async {
        var count = 0;
        for (final (table, sourceTable) in const [
          ('block_rule', 'block_rule_source'),
          ('allow_rule', 'allow_rule_source'),
        ]) {
          count += await deleteAllRows(txn, sourceTable);
          count += await deleteAllRows(txn, table);
        }
        // Only IPv4/IPv6 rewrites here; CNAME rewrites belong to address rules.
        for (final (table, sourceTable) in const [
          ('rewrite_rule', 'rewrite_rule_source'),
        ]) {
          const types = "targetType IN ('IPv4','IPv6')";
          count += await deleteRowsWhere(
            txn,
            sourceTable,
            'ruleId IN (SELECT id FROM rewrite_rule WHERE $types)',
          );
          count += await deleteRowsWhere(txn, table, types);
        }
        count += await deleteAllRows(txn, 'cosmetic_rule_source');
        count += await deleteAllRows(txn, 'cosmetic_rule');
        count += await deleteRowsWhere(txn, 'subscription', "kind = 'domain'");
        await resetSubscriptionImportState(txn);
        await deleteOrphanAutoUpdateItems(txn);
        return count;
      });
            // Only the main dataset is re-seeded.
      if (preset.isNotEmpty && _databases.isMain(db)) {
        await RuleRepository(db).resetPresetWhitelist(preset);
        _settings.markDefaultWhitelistSeeded(_versionCodeOrFallback);
      }
    }
    return _result(CleanupAction.domainRules, removed);
  }

  /// Clears all `go_url_rule` rows and the CNAME half of `rewrite_rule`.
  Future<CleanupResult> _clearAddressRules() async {
    var removed = 0;
    for (final db in await _databases.ruleDatabases()) {
      removed += await db.transaction<int>((txn) async {
        var count = await deleteAllRows(txn, 'go_url_rule_source');
        count += await deleteAllRows(txn, 'go_url_rule');
        count += await deleteRowsWhere(
          txn,
          'rewrite_rule_source',
          "ruleId IN (SELECT id FROM rewrite_rule WHERE targetType = 'CNAME')",
        );
        count += await deleteRowsWhere(
          txn,
          'rewrite_rule',
          "targetType = 'CNAME'",
        );
        return count;
      });
    }
    return _result(CleanupAction.addressRules, removed);
  }

  /// Clears subscriptions, groups, auto-update items and subscription-owned rules.
  Future<CleanupResult> _clearSubscriptions() async {
    var removed = 0;
    for (final db in await _databases.ruleDatabases()) {
      removed += await db.transaction<int>((txn) async {
        var count = await deleteAllRows(txn, 'subscription');
        count += await deleteAllRows(txn, 'subscription_group');
        count += await deleteAllRows(txn, 'subscription_auto_update_item');
        // Subscription-owned rules use `sub_<id>` sources; `staging_sub_` is a
        // mid-import state.
        for (final (table, sourceTable) in const [
          ('block_rule', 'block_rule_source'),
          ('allow_rule', 'allow_rule_source'),
          ('rewrite_rule', 'rewrite_rule_source'),
          ('go_url_rule', 'go_url_rule_source'),
          ('cosmetic_rule', 'cosmetic_rule_source'),
        ]) {
          count += await deleteRowsWhere(
            txn,
            sourceTable,
            "source GLOB 'sub_*' OR source GLOB 'staging_sub_*'",
          );
          count += await deleteOrphanRows(txn, table, sourceTable);
        }
        return count;
      });
    }
    return _result(CleanupAction.subscriptions, removed);
  }



  /// Clears all app lists together.
  ///
  /// Clearing only some of them leaves a state where the page and the engine
  /// disagree about which apps are allowed.
  CleanupResult _resetAppRules() {
    var removed = 0;
    const keys = [
      'excluded_app_packages',
      'blocked_app_packages',
      'blocked_apps_enabled',
      'app_allowlist_rules_json',
      'app_allowlist_enabled',
      'http_inspection_app_packages',
      'http_inspection_enabled',
    ];
    for (final key in keys) {
      if (_removeKey(LegacySettings.uiContainer, key)) removed++;
    }
        // Reset `https_inspection_ready` too, otherwise the next tunnel start
        // assumes the CA is still usable.
    if (_prefs.read(LegacySettings.uiContainer, 'https_inspection_ready') !=
        null) {
      _settings.setHttpsInspectionReady(false);
      removed++;
    }
    return _result(CleanupAction.appRules, removed);
  }

  /// Resets the outbound proxy through the native channel; credentials live in
  /// the AndroidKeyStore.
  Future<CleanupResult> _resetOutboundProxy() async {
    await _outboundProxy.reset();
    return _result(CleanupAction.outboundProxy, 1, detail: '已恢复直连');
  }

  /// Deletes the HTTPS inspection CA and marks inspection as not ready.
  ///
  /// `inspect(regenerate: true)` is the only channel entry that deletes the
  /// files; the regenerated CA is not trusted by the system.
  Future<CleanupResult> _resetCaCertificate() async {
    await _ca.inspect(regenerate: true);
    _settings.setHttpsInspectionReady(false);
    return _result(
      CleanupAction.caCertificate,
      1,
      detail: '需重新生成并导入系统证书',
    );
  }



  /// Deletes the custom background files and clears the three prefs keys.
  ///
  /// Both halves must run: clearing only settings leaves stale files, clearing
  /// only files leaves the UI claiming a background is enabled.
  Future<CleanupResult> _clearCustomBackground() async {
    var removed = await _platformCall(_platform.clearCustomBackgroundCache);
    for (final key in const [
      'custom_background_enabled',
      'custom_background_uri',
      'custom_background_uris',
    ]) {
      if (_removeKey(LegacySettings.uiContainer, key)) removed++;
    }
    return _result(CleanupAction.customBackground, removed);
  }

  /// Resets guide acknowledgements and the first-launch consent flag.
  ///
  /// Also clears the "do not remind" entries in `mode_permission_preferences`:
  /// with no dismissal left there is no way to restore that reminder.
  CleanupResult _resetSettingsGuides() {
    var removed = 0;
    for (final key in const [
      'settings_guide_acknowledged_ids',
      'initial_agreement_accepted',
    ]) {
      if (_removeKey(LegacySettings.uiContainer, key)) removed++;
    }
    for (final key in _prefs
        .readAll('mode_permission_preferences')
        .keys
        .toList()) {
      if (!key.startsWith('recommendation_dismissed_')) continue;
      if (_removeKey('mode_permission_preferences', key)) removed++;
    }
    return _result(CleanupAction.settingsGuides, removed);
  }



  /// Runs every cleanup action in order: runtime data, weights, rules and
  /// subscriptions, then storage and guides.
  ///
  /// Each step's count is summed; a failing step does not stop the rest.
  Future<CleanupResult> _clearAllLocalData() async {
    var removed = 0;
    for (final action in const [
      CleanupAction.logs,
      CleanupAction.traffic,
      CleanupAction.crash,
      CleanupAction.dnsCache,
      CleanupAction.providerWeights,
      CleanupAction.bootstrapWeights,
      CleanupAction.domainRules,
      CleanupAction.addressRules,
      CleanupAction.subscriptions,
      CleanupAction.appRules,
      CleanupAction.outboundProxy,
      CleanupAction.caCertificate,
      CleanupAction.downloadCache,
      CleanupAction.customBackground,
      CleanupAction.settingsGuides,
    ]) {
      removed += (await run(action)).removed;
    }
    // Also clears mirror templates and the recognition members cache.
    final db = await _databases.main;
    if (db != null) removed += await deleteAllRows(db, 'mirror_template');
    if (_removeKey('recognition_members', 'members')) removed++;
    return _result(CleanupAction.allData, removed);
  }



  /// Removes a key and returns whether it existed.
  ///
  /// A key holding its default value still counts as removed.
  bool _removeKey(String container, String key) {
    final existed = _prefs.read(container, key) != null;
    if (existed) _prefs.remove(container, key);
    return existed;
  }

  /// Version code for the seed marker: the stored install version wins.
  int get _versionCodeOrFallback {
    final raw = _prefs.read(LegacySettings.uiContainer, 'app_version_code');
    return raw is int && raw > 0 ? raw : _appVersionCode;
  }
}

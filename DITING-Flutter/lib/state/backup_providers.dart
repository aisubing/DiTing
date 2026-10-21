/// 备份与迁移的 provider 层。
///
/// 页面只需要三样东西：真实统计、导出动作、导入动作。三者都依赖「当前模式的
/// 规则库 + prefs」这一对句柄，因此装配放在一处。
library;

import 'package:diting/data/backup/backup_exporter.dart';
import 'package:diting/data/backup/backup_importer.dart';
import 'package:diting/data/backup/backup_models.dart';
import 'package:diting/data/db/rule_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/native/platform_bridge.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/state/cleanup_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前模式规则库里的四项真实计数（页顶四格）。
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

/// 真实统计：服务商取 prefs、订阅取表、自定义规则取规则表、名单应用取三份名单的并集。
///
/// 上一轮四格是写死的 `6 / 5 / 23 / 8`。数字与备份内容毫无关系，用户会拿它判断
/// 「我的规则有没有被备份进去」。
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
        // 表缺失时按 0 计：这一格是概览，不该因为一个库不全就整页报错。
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

/// 导出服务。
final backupExporterProvider = Provider<BackupExporter>(
  (ref) => const BackupExporter(),
);

/// 导入服务。
final backupImporterProvider = Provider<BackupImporter>(
  (ref) => const BackupImporter(),
);

/// 备份动作的执行者：装配句柄、调服务、刷新受影响的页面。
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

  /// 让系统选择器落盘，返回给用户看的结果。
  Future<DocumentSaveResult> saveToDocument(BackupExportResult export) =>
      _ref.read(platformBridgeProvider).exportDocument(
        name: export.fileName,
        content: export.content,
      );

  /// 打开系统选择器读文件 → 解析 → 合并。
  Future<BackupImportResult> importFromDocument() async {
    final picked = await _ref.read(platformBridgeProvider).importDocument();
    if (picked.cancelled) return const BackupImportResult.cancelled();
    if (picked.error != null) return BackupImportResult.failed(picked.error!);
    final text = picked.text;
    if (text == null) return const BackupImportResult.failed('无法读取所选文件');

    final db = await _ref.read(activeLogDatabaseProvider.future);
    final result = await _ref.read(backupImporterProvider).import(
      text,
      BackupImportTarget(
        store: _ref.read(legacyPrefsStoreProvider),
        database: db,
      ),
      sourceName: picked.name,
    );
    if (!result.failed && !result.cancelled) _invalidate();
    return result;
  }

  void _invalidate() {
    _ref.read(legacySettingsRevisionProvider.notifier).bump();
    _ref.read(subscriptionRevisionProvider.notifier).bump();
    _ref.read(dnsLogRevisionProvider.notifier).bump();
  }
}

final backupActionsProvider = Provider<BackupActions>(BackupActions.new);

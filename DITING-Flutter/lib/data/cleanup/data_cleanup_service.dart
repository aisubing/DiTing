/// 数据清理的真实实现（1.4.3 `DataCleanupManager` 的 Dart 移植）。
///
/// ## 为什么必须重写而不是「调一个通道」
///
/// 1.4.3 的清理动作分散在四个存储里，每一处都有自己的 DAO 或 prefs 键：
///
/// | 动作 | 1.4.3 | 本仓 |
/// |---|---|---|
/// | 请求日志 / 流量 / 缓存 / 竞速 / Bootstrap | `LogMaintenance` + 各 DAO | sqflite 直接 `DELETE` |
/// | 权重（服务商 / Bootstrap） | `ProviderHealthStore.clearAll` | 删 prefs 的两个 JSON 键 |
/// | 域名 / 地址规则、订阅 | 各 DAO 的 `clearAll` 族 | sqflite 事务 + 预设白名单重播 |
/// | 应用名单 / 出站代理 / 证书 | `AppRulesSettingsStore` 等 | prefs 键 + 两条原生通道 |
/// | 下载缓存 / 背景缓存 / 引导 | `AppUpdateDirectories` 等 | 原生通道 + prefs 键 |
///
/// ## 三条必须照抄的语义
///
/// 1. **「删除全部域名规则」要重新播种预设白名单**。旧版 `clearAllDomainRules`
///    删完立刻 `DefaultWhitelistSeeder.seed(forceReset = true)`；只删不播会让
///    保活类域名从放行变成拦截，而界面显示「已删除」。
/// 2. **订阅行要 `resetAfterRuleCleanup()`**，见 [resetSubscriptionImportState]。
/// 3. **「清理全部本地数据」按序跑完整清单**。中途某一项失败就停下会留下
///    「日志清了、规则还在」的半清理态，而应用已经退出。
///
// ignore_for_file: prefer_initializing_formals
// 上面这条 lint 在这里是误报：字段全是私有的 `_xxx`，而 Dart 不允许具名参数
// 以 `_` 开头，所以无法写成 `required this._prefs`。
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

/// 清理服务：一个类装下 16 个动作。
///
/// 不拆成 16 个 provider：它们共享同一批句柄（prefs、数据库缓存、两条通道），
/// 拆开会让每个动作各自打开一次数据库，而「清理全部本地数据」又要把它们按序
/// 串起来。
class DataCleanupService {
  DataCleanupService({
    required LegacyPrefsStore prefs,
    required PlatformBridge platform,
    required OutboundProxyStore outboundProxy,
    required Future<Database?> Function(String fileName) openDatabase,
    CaCertificateService? caCertificate,
    Future<String> Function()? loadPresetAsset,
  }) : _prefs = prefs,
       _platform = platform,
       _outboundProxy = outboundProxy,
       _ca = caCertificate ?? const UnavailableCaCertificateService(),
       _loadPresetAsset = loadPresetAsset,
       _databases = CleanupDatabases(openDatabase);

  final LegacyPrefsStore _prefs;
  final PlatformBridge _platform;
  final OutboundProxyStore _outboundProxy;
  final CaCertificateService _ca;
  final Future<String> Function()? _loadPresetAsset;
  final CleanupDatabases _databases;
  LegacySettings get _settings => LegacySettings(_prefs);

  /// 包一层原生调用：通道缺失 / 宿主无 binding 时退化成 0，不让它拖垮整个动作。
  ///
  /// 三个用到原生通道的动作都**同时**要改 prefs（背景壁纸、抓包就绪标记），
  /// 原生半边失败就把 prefs 半边一起丢掉，会得到「文件删了、设置还显示开着」
  /// 或反过来的半清理态。
  Future<int> _platformCall(Future<int> Function() call) async {
    try {
      return await call();
    } catch (error) {
      debugPrint('cleanup: platform call degraded to 0 ($error)');
      return 0;
    }
  }

  /// 三个数据集的 prefs 容器名（`RuleDataset.prefsName()`）。
  static const _datasetContainers = [
    LegacySettings.uiContainer,
    LegacySettings.expressContainer,
    LegacySettings.serverContainer,
  ];

  /// 运行一个动作；异常一律转成 [CleanupResult.failed]。
  ///
  /// 不向上抛：调用点在确认框之后，抛出去只会变成红屏。每个动作都已经二次
  /// 确认过，用户需要的是「为什么没成功」而不是一个 stack trace。
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

  // --------------------------------------------------------------- 运行数据

  /// 四张日志表一起清（`LogMaintenance.clearAllLogs` 同口径）。
  ///
  /// 逐表容错：极速库没有 `http_request_log`（`ExpressRulesDatabase` 明确排除），
  /// 一张表缺失不能让另外三张跟着不清。
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

  /// `TrafficStatsManager.clearAllTrafficStats` + `app_traffic_daily` 清空。
  ///
  /// 只动主库：极速库没有这张表，服务器库更没有（`DnsRulesDatabase` 只含规则）。
  Future<CleanupResult> _clearTraffic() async {
    final db = await _databases.main;
    final removed = db == null ? 0 : await deleteAllRows(db, 'app_traffic_daily');
    return _result(CleanupAction.traffic, removed);
  }

  /// `dns_cache` 落盘快照。
  ///
  /// 引擎自己的内存 LRU 由 `dns_server` 的 `clearCache` 处理，那条路只在服务器
  /// 模式的 service 存活时可调；这里清的是页面显示的那张表。
  Future<CleanupResult> _clearDnsCache() async {
    var removed = 0;
    for (final db in await _databases.runtimeDatabases()) {
      removed += await deleteAllRows(db, 'dns_cache');
    }
    return _result(CleanupAction.dnsCache, removed);
  }

  // --------------------------------------------------------------- 权重数据

  /// `ProviderHealthStore.clearAll` / `BootstrapHealthStore.clearAll`。
  ///
  /// 三个数据集各有一份（`RuleDataset.prefsName()`）：只清一处会让另一个模式
  /// 继续用旧的健康样本。
  CleanupResult _resetWeights(CleanupAction action, String key) {
    var removed = 0;
    for (final container in _datasetContainers) {
      if (_removeKey(container, key)) removed++;
    }
    return _result(action, removed);
  }

  // ----------------------------------------------------------- 规则与订阅

  /// 域名规则：黑名单 / 白名单 / IPv4+IPv6 覆写 / 修饰规则 / 域名订阅。
  ///
  /// 删完立刻重播预设白名单——旧版就是「删 + seed」，只删不播会让保活域名失去
  /// 放行，而界面已经说了「已删除」。
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
        // 覆写表只清 IPv4 / IPv6；CNAME 属于「地址规则」那一档。
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
      // 预设白名单只播主库：旧版对 NORMAL 调 seeder，另外两个数据集分别走
      // `ExpressDefaultsSeeder` 与「不播种」。
      if (preset.isNotEmpty && _databases.isMain(db)) {
        await RuleRepository(db).resetPresetWhitelist(preset);
        _settings.markDefaultWhitelistSeeded(_versionCodeOrFallback);
      }
    }
    return _result(CleanupAction.domainRules, removed);
  }

  /// 地址规则：`go_url_rule` 全部 + `rewrite_rule` 的 CNAME 档。
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

  /// 全部订阅：订阅行、分组、自动更新任务，以及由订阅引入的规则。
  Future<CleanupResult> _clearSubscriptions() async {
    var removed = 0;
    for (final db in await _databases.ruleDatabases()) {
      removed += await db.transaction<int>((txn) async {
        var count = await deleteAllRows(txn, 'subscription');
        count += await deleteAllRows(txn, 'subscription_group');
        count += await deleteAllRows(txn, 'subscription_auto_update_item');
        // 订阅引入的规则：source 形如 `sub_<id>`，`staging_sub_` 是导入中间态。
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

  // --------------------------------------------------------- 应用 / 代理 / 证书

  /// 四份应用名单一起清空（`AppRulesSettingsStore.resetAppControlRules`）。
  ///
  /// 四份必须同时清：留一份而清另外三份会得到「禁止联网为空、但独立放行仍
  /// 指向某个包」的分裂状态，引擎读到的组合与页面显示不一致。
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
    // 抓包开关关掉后 `https_inspection_ready` 也要归零：留着 true 会让下一次
    // 启动隧道以为 CA 仍然可用。
    if (_prefs.read(LegacySettings.uiContainer, 'https_inspection_ready') !=
        null) {
      _settings.setHttpsInspectionReady(false);
      removed++;
    }
    return _result(CleanupAction.appRules, removed);
  }

  /// 出站代理：走原生通道——凭据在 AndroidKeyStore 里，Dart 清不掉。
  Future<CleanupResult> _resetOutboundProxy() async {
    await _outboundProxy.reset();
    return _result(CleanupAction.outboundProxy, 1, detail: '已恢复直连');
  }

  /// HTTPS 抓包根证书：删 `ca.crt` / `ca.key` / 黑名单，并把 ready 置假。
  ///
  /// `inspectCa(regenerate: true)` 是既有通道里唯一会删证书的入口；它删完会顺手
  /// 再生成一份，但新证书没被安装到系统信任库，所以 `installed` 仍为 false，
  /// 与「已重置」一致。
  Future<CleanupResult> _resetCaCertificate() async {
    await _ca.inspect(regenerate: true);
    _settings.setHttpsInspectionReady(false);
    return _result(
      CleanupAction.caCertificate,
      1,
      detail: '需重新生成并导入系统证书',
    );
  }

  // ------------------------------------------------------------- 存储与引导

  /// 自定义壁纸：删缓存文件 + 清三个 prefs 键。
  ///
  /// 原生半边（删位图与标记文件）失败不影响 prefs 那半边：只清设置会让下次启动
  /// 重读一张已不存在的图，只清文件则设置仍显示「已启用壁纸」——两半都要走。
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

  /// 重置引导：清 `settings_guide_acknowledged_ids` 与首启协议标记。
  ///
  /// 还要清 `mode_permission_preferences` 里的「不再提醒」——旧版 O-146 的教训：
  /// 不清它，用户会永久失去一条建议提醒而没有任何入口恢复。
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

  // ------------------------------------------------------------- 全面清理

  /// `DataCleanupManager.clearAllLocalData(dataset = NORMAL)`。
  ///
  /// 顺序照抄旧版：运行数据 → 权重 → 规则与订阅 → 存储与引导。每一步的结果
  /// 单独累计，某一项失败不影响其余步骤（见文件头的语义 3）。
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
    // 旧版这一段还清镜像模板与识别库缓存。
    final db = await _databases.main;
    if (db != null) removed += await deleteAllRows(db, 'mirror_template');
    if (_removeKey('recognition_members', 'members')) removed++;
    return _result(CleanupAction.allData, removed);
  }

  // ------------------------------------------------------------- prefs 工具

  /// 删一个键并返回它原先是否存在。
  ///
  /// 「存在但值为默认值」也算删除成功——用户看到的那条确实没了，报 0 会让人
  /// 以为按钮没生效。
  bool _removeKey(String container, String key) {
    final existed = _prefs.read(container, key) != null;
    if (existed) _prefs.remove(container, key);
    return existed;
  }

  /// 播种标记用的 versionCode；读不到时用当前包版本号（2.0.1 = 20001）。
  int get _versionCodeOrFallback {
    final raw = _prefs.read(LegacySettings.uiContainer, 'app_version_code');
    return raw is int && raw > 0 ? raw : 20001;
  }
}

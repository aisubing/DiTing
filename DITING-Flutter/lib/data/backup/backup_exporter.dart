/// 备份导出：把勾选的分组序列化成一份 JSON。
///
/// ## 数据来源
///
/// | 分组 | 来源 |
/// |---|---|
/// | providers / bootstrap / cache / outbound / appearance / system | prefs（`LegacySettings`） |
/// | subscriptions | `subscription` + `subscription_group` 表 |
/// | domainRules / rewriteDomain / rewriteCname / addressRules | 四张规则表 |
/// | excluded / blocked / allowlist / httpInspection | prefs 里的四份名单 |
///
/// ## 不导出什么
///
/// - **出站代理的账号密码**：旧版页面就写着「不含账号密码」，因为密码由
///   AndroidKeyStore 加密，导出到明文 JSON 等于把凭据写到用户随便能翻的地方。
/// - **日志 / 流量 / 缓存内容**：备份的是配置，不是运行数据。旧版同样不导。
/// - **CA 私钥**：`ca.key` 只在应用私有目录里，导出它等于让任何拿到文件的人
///   能对用户的 HTTPS 流量做中间人。
library;

import 'dart:convert';

import 'package:diting/data/backup/backup_models.dart';
import 'package:diting/data/backup/legacy_backup_writer.dart';
import 'package:diting/data/db/rule_repository.dart';
import 'package:diting/data/db/subscription_models.dart';
import 'package:diting/data/db/subscription_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/data/vpn/provider_store.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// 导出上下文：一个已打开的规则库 + prefs 视图。
class BackupExportSource {
  const BackupExportSource({
    required this.settings,
    required this.database,
    this.onSkip,
  });

  final LegacySettings settings;

  /// 规则/订阅所在的库；`null` 表示全新安装（这些分组导出为空表）。
  final Database? database;

  /// 某张表读取失败时的回调（用于在结果里如实报告跳过了什么）。
  final void Function(String message)? onSkip;
}

/// 一次导出的结果。
class BackupExportResult {
  const BackupExportResult({
    required this.content,
    required this.fileName,
    required this.included,
    required this.counts,
    this.skipped = const [],
  });

  /// 完整 JSON 文本。
  final String content;
  final String fileName;
  final List<BackupGroup> included;

  /// 每个分组导出的条目数，用于在导出后告诉用户「备份里到底有什么」。
  final Map<BackupGroup, int> counts;

  /// 读取失败的项（表缺失、列缺失），如实上报而不是静默当 0。
  final List<String> skipped;

  int get totalItems => counts.values.fold(0, (sum, value) => sum + value);

  bool get isEmpty => totalItems == 0;
}

/// 备份序列化器。
class BackupExporter {
  const BackupExporter();

  static const _encoder = JsonEncoder.withIndent('  ');

  /// 只序列化 [groups] 里的分组；不传表示全部分组。
  Future<BackupExportResult> export(
    BackupExportSource source, {
    Set<BackupGroup>? groups,
  }) async {
    final selected = groups ?? BackupGroup.values.toSet();
    final data = <String, Object?>{};
    final counts = <BackupGroup, int>{};
    final skipped = <String>[];
    final included = <BackupGroup>[];

    for (final group in BackupGroup.values) {
      if (!selected.contains(group)) continue;
      try {
        final value = await _valueOf(group, source);
        data[group.key] = value;
        counts[group] = _countOf(value);
        included.add(group);
      } catch (error) {
        // 单组失败不中断整份备份：其余分组仍然可用，而一个「导出了 12/15 组」
        // 的备份比「导出失败，什么都没有」有用得多。
        debugPrint('backup export skipped ${group.key}: $error');
        skipped.add('${group.title}：$error');
        source.onSkip?.call('${group.title}：$error');
      }
    }

    final now = DateTime.now();
    final payload = <String, Object?>{
      'format': BackupFormat.magic,
      'version': BackupFormat.version,
      'exportedAt': now.millisecondsSinceEpoch,
      'selection': [for (final group in included) group.key],
      'data': data,
      // 同时在根节点平铺一份 1.4.3 认识的字段：同一份文件既能被 2.0 再次
      // 导入，也能直接导回 1.4.3。旧版解析器读不到 `format`/`data` 会忽略
      // 它们，反之亦然，所以两套键共存不会互相干扰。
      ...LegacyBackupWriter.toLegacy(data, source.settings),
    };

    return BackupExportResult(
      content: _encoder.convert(payload),
      fileName:
          '${BackupFormat.fileNamePrefix}-${BackupFormat.stampOf(now)}.json',
      included: included,
      counts: counts,
      skipped: skipped,
    );
  }

  /// 一个分组的 JSON 值。返回 `Map`（结构化配置）或 `List`（规则/订阅行）。
  Future<Object?> _valueOf(
    BackupGroup group,
    BackupExportSource source,
  ) async => switch (group) {
    BackupGroup.providers => _providers(source),
    BackupGroup.bootstrap => _bootstrap(source),
    BackupGroup.cache => _cache(source),
    BackupGroup.outbound => _outbound(source),
    BackupGroup.subscriptions => _subscriptions(source),
    BackupGroup.domainRules => _rules(source, group),
    BackupGroup.rewriteDomain => _rewriteRules(source, const {'IPv4', 'IPv6'}),
    BackupGroup.rewriteCname => _rewriteRules(source, const {'CNAME'}),
    BackupGroup.addressRules => _addressRules(source),
    BackupGroup.excluded => _stringList(source.settings.excludedPackages),
    BackupGroup.blocked => {
      'enabled': source.settings.blockedAppsEnabled,
      'packages': _stringList(source.settings.blockedAppPackages),
    },
    BackupGroup.allowlist => {
      'enabled': source.settings.appAllowlistEnabled,
      'rules': {
        for (final entry in source.settings.appAllowlistRules.entries)
          entry.key: _stringList(entry.value),
      },
    },
    BackupGroup.httpInspection => {
      'enabled': source.settings.httpInspectionEnabled,
      'http3Enabled': source.settings.http3InspectionEnabled,
      'packages': _stringList(source.settings.httpInspectionPackages),
    },
    BackupGroup.appearance => _appearance(source),
    BackupGroup.system => _system(source),
  };

  /// 自定义服务商 + 选择状态。
  ///
  /// 1.4.3 把「选了哪个服务商、用哪种解析模式、各模式的候选列表」平铺在备份
  /// 根节点，2.0 之前的导出只写了 `user_providers_json`，于是这些选择只能靠
  /// 用户重装后再手点一遍。这里把它们一并收进服务商分组。
  Object? _providers(BackupExportSource source) {
    final settings = source.settings;
    final raw = settings.userProvidersJson;
    var items = const <Object?>[];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) items = decoded;
      } on FormatException {
        // 坏 JSON 如实跳过：塞进备份只会把损坏传给下一次恢复。
        throw const BackupFormatException('服务商配置不是合法 JSON');
      }
    }
    return {'items': items, 'selection': _providerSelection(settings)};
  }

  /// 服务商选择状态（对应 1.4.3 的 `selectedProvider` / `resolutionMode` /
  /// 各模式引用列表 / 主页可见性过滤）。
  ///
  /// 引用里带 `name` 与 `protocol`：旧版按 `(name, protocol)` 回退匹配，只有
  /// id 的引用在本机找不到时会整个丢掉。
  Map<String, Object?> _providerSelection(LegacySettings settings) {
    final catalog = _providerCatalog(settings);
    final selectedId = settings.selectedProviderId;
    return {
      'selectedProvider': _refOf(catalog, selectedId),
      'resolutionMode': settings.resolutionModeRaw,
      'presetDnsService': settings.presetDnsServiceRaw,
      'raceTestDomain': settings.raceTestDomain,
      'raceProviderRefs': _providerRefs(catalog, settings.raceProviderIds),
      'smartPredictionProviderRefs': _providerRefs(
        catalog,
        settings.smartPredictionProviderIds,
      ),
      'parallelRaceProviderRefs': _providerRefs(
        catalog,
        settings.parallelRaceProviderIds,
      ),
      'primaryBackupProviderRefs': _providerRefs(
        catalog,
        settings.primaryBackupProviderIds,
      ),
      'latencyTestProviderRefs': _providerRefs(
        catalog,
        settings.latencyTestProviderIds,
      ),
      'homeProviderVisibility': {
        'visibleProtocols': _stringList(settings.homeVisibleProtocols),
        'hiddenProviderRefs': _providerRefs(
          catalog,
          settings.homeHiddenProviderIds,
        ),
        'visibleProviderRefs': _providerRefs(
          catalog,
          settings.homeVisibleProviderIds,
        ),
      },
    };
  }

  /// id → (名称, 协议) 的查表，预设与自定义合并。
  Map<String, ({String name, String protocol})> _providerCatalog(
    LegacySettings settings,
  ) {
    final catalog = <String, ({String name, String protocol})>{};
    for (final provider in defaultDnsProviders) {
      catalog[provider.id] = (
        name: provider.name,
        protocol: provider.protocol.storageValue,
      );
    }
    for (final record in readUserProviders(settings)) {
      catalog[record.id] = (
        name: record.name,
        protocol: record.protocol.storageValue,
      );
    }
    return catalog;
  }

  List<Object?> _providerRefs(
    Map<String, ({String name, String protocol})> catalog,
    Iterable<String> ids,
  ) => [for (final id in ids) _refOf(catalog, id)];

  Map<String, Object?> _refOf(
    Map<String, ({String name, String protocol})> catalog,
    String id,
  ) {
    final entry = catalog[id];
    return {
      'id': id,
      'name': entry?.name ?? id,
      'protocol': entry?.protocol ?? 'DOH',
      'isPreset': id.startsWith('preset_'),
    };
  }

  Object? _bootstrap(BackupExportSource source) {
    final custom = source.settings.bootstrapCustomJson;
    Object? parsed;
    if (custom != null && custom.trim().isNotEmpty) {
      try {
        parsed = jsonDecode(custom);
      } on FormatException {
        throw const BackupFormatException('Bootstrap 配置不是合法 JSON');
      }
    }
    return {
      'enabled': source.settings.bootstrapEnabled,
      'presetIds': source.settings.bootstrapPresetIds,
      'custom': parsed,
    };
  }

  Object? _cache(BackupExportSource source) {
    final settings = source.settings;
    return {
      'enabled': settings.cacheEnabled,
      'mode': settings.cacheModeRaw,
      'maxTtlSeconds': settings.cacheMaxTtlSeconds,
      'fixedTtlSeconds': settings.cacheFixedTtlSeconds,
      'minTtlEnabled': settings.cacheMinTtlEnabled,
      'minTtlSeconds': settings.cacheMinTtlSeconds,
      'staleFallbackEnabled': settings.cacheStaleFallbackEnabled,
      'staleFallbackSeconds': settings.cacheStaleFallbackSeconds,
      'preset': settings.cachePresetRaw,
    };
  }

  /// 出站代理：只导出协议/主机/端口/目标应用，**不含账号密码**。
  Object? _outbound(BackupExportSource source) {
    final settings = source.settings;
    return {
      'enabled': settings.rawValue('outbound_proxy_enabled') == true,
      'protocol': settings.rawValue('outbound_proxy_protocol'),
      'host': settings.rawValue('outbound_proxy_host'),
      'port': settings.rawValue('outbound_proxy_port'),
      'proxyAppPackage': settings.rawValue('outbound_proxy_app'),
      // 明确写进备份：让用户在导入侧看到「这里本来就没有凭据」，
      // 而不是以为导入漏了。
      'credentialsExcluded': true,
    };
  }

  Future<Object?> _subscriptions(BackupExportSource source) async {
    final db = source.database;
    if (db == null) return const [];
    final repository = SubscriptionRepository(db);
    final groups = await repository.groups();
    final rows = await repository.all();
    // 镜像模板表没有仓储层，直接读：订阅行只记名字，模板内容是另一张表。
    // 1.4.x 早期库可能还没有这张表（也没有自定义模板可导），缺表不该让整组
    // 订阅导出失败，所以这里单独兜住。
    var templates = const <Map<String, Object?>>[];
    if (await _hasTable(db, 'mirror_template')) {
      templates = await db.query(
        'mirror_template',
        columns: ['name', 'template'],
        orderBy: 'name',
      );
    }
    return {
      'groups': [
        for (final group in groups)
          {'name': group.name, 'autoUpdateEnabled': group.autoUpdateEnabled},
      ],
      'mirrorTemplates': [
        for (final row in templates)
          {'name': row['name'], 'template': row['template']},
      ],
      'items': [
        for (final row in rows)
          {
            'url': row.url,
            'name': row.name,
            'kind': row.kind.storageValue,
            'scope': 'dns',
            'sourceType': row.sourceType.storageValue,
            'enabled': row.enabled,
            'groupName': _groupNameOf(groups, row.groupId),
            'mirrorTemplate': row.mirrorTemplate,
            'mirrorFallback': row.mirrorFallback,
          },
      ],
    };
  }

  Future<bool> _hasTable(Database db, String name) async {
    final rows = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ? AND name = ?',
      whereArgs: ['table', name],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  String? _groupNameOf(List<SubscriptionGroupRecord> groups, int? groupId) {
    if (groupId == null) return null;
    for (final group in groups) {
      if (group.id == groupId) return group.name;
    }
    return null;
  }

  /// 域名规则：黑白名单放在同一组，用每条规则的 `kind` 区分。
  ///
  /// 2.0 早期的导出只写了 `pattern`/`enabled`/`important`/`group`，把
  /// `appScope`（只对某个应用生效）、`appInverted`（对该应用反选）与
  /// `rawLine`（原始规则行，AdGuard 语法里的 `$app=`、`@@` 都在这里）全丢了，
  /// 于是「只屏蔽某个 App」的规则恢复后会变成全局屏蔽。
  Future<Object?> _rules(BackupExportSource source, BackupGroup group) async {
    final db = source.database;
    if (db == null) return const [];
    final exported = <Object?>[];
    for (final kind in const [RuleKind.block, RuleKind.allow]) {
      final table = kind == RuleKind.block ? 'block_rule' : 'allow_rule';
      final sourceTable = kind == RuleKind.block
          ? 'block_rule_source'
          : 'allow_rule_source';
      final userRuleIds = await _userRuleIds(db, sourceTable);
      final rows = await db.query(table, orderBy: 'id DESC');
      for (final row in rows) {
        // 只导出用户自己加的：预设由应用自带、订阅由订阅链接重建，
        // 备份它们会让恢复时产生重复行。
        if (!userRuleIds.contains(row['id'] as int)) continue;
        exported.add({
          'pattern': row['pattern'],
          'kind': kind == RuleKind.allow ? 'allow' : 'block',
          'enabled': (row['enabled'] as int? ?? 1) == 1,
          'important': (row['important'] as int? ?? 0) == 1,
          'appScope': row['appScope'],
          'appInverted': (row['appInverted'] as int? ?? 0) == 1,
          'rawLine': row['rawLine'],
          'group': row['groupName'],
        });
      }
    }
    return exported;
  }

  /// 用户来源的规则 id 集合（source 表里 `useradd`/`local_import`/`local_hosts`）。
  Future<Set<int>> _userRuleIds(Database db, String sourceTable) async {
    final rows = await db.query(sourceTable, columns: ['ruleId', 'source']);
    return {
      for (final row in rows)
        if (RuleRepository.userSources.contains(row['source']))
          row['ruleId'] as int,
    };
  }

  /// 覆写规则（按 targetType 分两档：IPv4/IPv6 与 CNAME）。
  Future<Object?> _rewriteRules(
    BackupExportSource source,
    Set<String> targetTypes,
  ) async {
    final db = source.database;
    if (db == null) return const [];
    final rows = await db.query('rewrite_rule', orderBy: 'id DESC');
    final userRuleIds = await _userRewriteRuleIds(db);
    return [
      for (final row in rows)
        if (targetTypes.contains(row['targetType']) &&
            userRuleIds.contains(row['id'] as int))
          {
            'pattern': row['pattern'],
            'targetType': row['targetType'],
            'targetValue': row['targetValue'],
            'rawLine': row['rawLine'],
            'enabled': (row['enabled'] as int? ?? 1) == 1,
          },
    ];
  }

  /// 用户来源的覆写规则 id 集合（`rewrite_rule_source.source` 为 `useradd` 等）。
  Future<Set<int>> _userRewriteRuleIds(Database db) async {
    final rows = await db.query(
      'rewrite_rule_source',
      columns: ['ruleId', 'source'],
    );
    return {
      for (final row in rows)
        if (RuleRepository.userSources.contains(row['source']))
          row['ruleId'] as int,
    };
  }

  Object? _addressRules(BackupExportSource source) async {
    final db = source.database;
    if (db == null) return const [];
    final rows = await db.query('go_url_rule', orderBy: 'id DESC');
    final userRuleIds = <int>{};
    final sources = await db.query(
      'go_url_rule_source',
      columns: ['ruleId', 'source'],
    );
    for (final row in sources) {
      if (RuleRepository.userSources.contains(row['source'])) {
        userRuleIds.add(row['ruleId'] as int);
      }
    }
    return [
      for (final row in rows)
        if (userRuleIds.contains(row['id'] as int))
          {
            'pattern': row['pattern'],
            'kind': row['kind'],
            'rawLine': row['rawLine'],
            'enabled': (row['enabled'] as int? ?? 1) == 1,
          },
    ];
  }

  Object? _appearance(BackupExportSource source) {
    final settings = source.settings;
    final sentences = settings.homeSentences;
    return {
      'themeMode': settings.themeModeRaw,
      'palette': settings.paletteRaw,
      'liquidGlassMode': settings.liquidGlassModeRaw,
      'bottomBarStyle': settings.bottomBarStyleRaw,
      'tabTransition': settings.tabTransitionRaw,
      'componentOpacity': _opacity(settings.componentOpacity),
      'hapticEnabled': settings.hapticEnabled,
      'bottomBarIds': settings.bottomBarIds,
      'customBackgroundEnabled': settings.customBackgroundEnabled,
      // 1.4.3 的首页每个组件有自己的透明度，2.0 统一成一个滑块；
      // 备份仍按旧键逐个写出，老版本才认得出这份文件。
      'homePowerButtonOpacity': _opacity(
        settings.homeOpacity('home_power_button_opacity'),
      ),
      'homeProviderSelectorOpacity': _opacity(
        settings.homeOpacity('home_provider_selector_opacity'),
      ),
      'homeModeButtonOpacity': _opacity(
        settings.homeOpacity('home_mode_button_opacity'),
      ),
      'homePoemOpacity': _opacity(settings.homeOpacity('home_poem_opacity')),
      'homeDnsDetailOpacity': _opacity(
        settings.homeOpacity('home_dns_detail_opacity'),
      ),
      'homeSentenceRunning': sentences.running,
      'homeSentenceStopped': sentences.stopped,
      'customBackgroundUri': settings.customBackgroundUri,
    };
  }

  /// 透明度取两位小数再写出。
  ///
  /// 安卓用 Java `float` 存透明度，`0.8` 读回来是 `0.800000011920929`；直接
  /// 写进备份文件既难看，也让「同一份备份再导入」的比较更难对齐。
  double _opacity(double value) => (value * 100).roundToDouble() / 100;

  Object? _system(BackupExportSource source) {
    final settings = source.settings;
    final texts = settings.notificationTexts;
    return {
      'bypassLan': settings.bypassLanEnabled,
      'ipv6Mode': settings.ipv6ModeRaw,
      'logRetentionDays': settings.logRetentionDays,
      'dnsLogMode': settings.dnsLogModeRaw,
      'hideFromRecents': settings.hideFromRecentsEnabled,
      'floatingLogEnabled': settings.floatingLogEnabled,
      'floatingLogPanelSize': settings.rawValue('floating_log_panel_size'),
      'disableStartupUpdateCheck': settings.disableStartupUpdateCheck,
      'appLanguageMode': settings.appLanguageModeRaw,
      'notificationPersistent': settings.notificationPersistent,
      'notificationSpeed': settings.notificationSpeed,
      'customRunningNotificationText': texts.running,
      'customStoppedNotificationText': texts.stopped,
      'domainRulesEnabled': settings.domainRulesEnabled,
      'addressRulesEnabled': settings.addressRulesEnabled,
      'encryptedDnsBlockingEnabled': settings.encryptedDnsBlockingEnabled,
      'blockResponseMode': settings.blockResponseModeRaw,
      'allowEditDefaultWhitelist':
          settings.rawValue('allow_edit_default_whitelist') == true,
      'dynamicBlockResponse': {
        'enabled': settings.dynamicBlockEnabled,
        'requestThreshold': settings.dynamicBlockRequestThreshold,
        'windowSeconds': settings.dynamicBlockWindowSeconds,
        'nxDomainDurationSeconds': settings.dynamicBlockNxDomainDurationSeconds,
      },
      'appTrafficStatsEnabled':
          settings.rawValue('app_traffic_stats_enabled') != false,
      'trafficStatsRetentionDays':
          settings.rawValue('traffic_stats_retention_days') ?? 30,
      'trafficStatsHideSystemApps':
          settings.rawValue('traffic_stats_hide_system_apps') == true,
      'subscriptionAutoUpdateEnabled': settings.subscriptionAutoUpdateEnabled,
      'subscriptionAutoUpdateIntervalHours':
          settings.subscriptionAutoUpdateIntervalHours,
    };
  }

  /// 条数统计：`List` 数元素、`Map` 数键（配置类的「条目数」就是设置项数）。
  static int _countOf(Object? value) => switch (value) {
    null => 0,
    List() => value.length,
    Map() => value.length,
    _ => 1,
  };

  /// `Set<String>` → 排序后的列表；排序让两份等价的备份逐字节相同。
  static List<String> _stringList(Iterable<String> values) =>
      values.toList()..sort();
}

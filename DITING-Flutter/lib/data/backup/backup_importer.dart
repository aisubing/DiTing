/// 备份导入：解析、校验并合并一份备份文件。
///
/// ## 合并语义（照抄 1.4.3 `ConfigImporter` 的分档）
///
/// 每个分组独立决定「新增 / 跳过 / 更新」，并逐项记账：
///
/// | 情形 | 结果 |
/// |---|---|
/// | 本机没有该条目 | **新增** |
/// | 本机已有完全相同 | **跳过** |
/// | 本机已有但内容不同 | **更新**（规则类）/ **跳过**（设置类） |
///
/// 设置项（外观、系统、缓存策略）本机已存在时**一律跳过**而不是覆盖：用户导入
/// 备份通常是想恢复规则与订阅，把当前的界面主题顺手改回去是意外行为。
/// 规则类相反——同名但目标不同的覆写规则必须更新，否则导入等于没导。
///
/// ## 为什么逐组记账而不是只报总数
///
/// 「导入完成」这句话在上一轮是写死的假文案（页面上永远显示「新增 9 项，跳过
/// 3 项」）。用户据此以为恢复成功了。真实结果必须能说清「哪一组新增了几条」，
/// 尤其是**部分失败**时——静默的部分成功比整份失败更难排查。
library;

import 'dart:convert';

import 'package:diting/data/backup/backup_models.dart';
import 'package:diting/data/db/rule_repository.dart';
import 'package:diting/data/db/subscription_models.dart';
import 'package:diting/data/db/subscription_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// 一个分组的导入结果。
class BackupGroupOutcome {
  const BackupGroupOutcome({
    required this.group,
    this.added = 0,
    this.skipped = 0,
    this.updated = 0,
    this.error,
  });

  final BackupGroup group;
  final int added;
  final int skipped;
  final int updated;

  /// 该组整体失败的原因；非空时三个计数都无意义。
  final String? error;

  bool get failed => error != null;

  bool get isNoop => !failed && added == 0 && updated == 0;
}

/// 一次导入的完整结果。
class BackupImportResult {
  const BackupImportResult({
    required this.occurredAt,
    required this.outcomes,
    this.sourceName,
    this.cancelled = false,
    this.fatalError,
    this.subscriptionCount = 0,
  });

  /// 用户取消选择文件：不是失败，什么都不该提示「已导入」。
  const BackupImportResult.cancelled()
    : outcomes = const [],
      sourceName = null,
      cancelled = true,
      fatalError = null,
      occurredAt = null,
      subscriptionCount = 0;

  /// 整份文件无法解析（不是备份文件 / 版本过新 / JSON 损坏）。
  const BackupImportResult.failed(String this.fatalError)
    : outcomes = const [],
      sourceName = null,
      cancelled = false,
      occurredAt = null,
      subscriptionCount = 0;

  final DateTime? occurredAt;
  final List<BackupGroupOutcome> outcomes;
  final String? sourceName;
  final bool cancelled;

  /// 整份失败的原因；非空时 [outcomes] 为空。
  final String? fatalError;

  /// 本次导入涉及的订阅数（用于提示「请进入订阅管理执行规则更新」）。
  final int subscriptionCount;

  bool get failed => fatalError != null;

  int get added => outcomes.fold(0, (sum, item) => sum + item.added);
  int get skipped => outcomes.fold(0, (sum, item) => sum + item.skipped);
  int get updated => outcomes.fold(0, (sum, item) => sum + item.updated);

  /// 有内容变化的分组（用于汇总里只列真正动过的组）。
  List<BackupGroupOutcome> get changed =>
      [for (final outcome in outcomes) if (outcome.added + outcome.updated > 0) outcome];

  List<BackupGroupOutcome> get failedGroups =>
      [for (final outcome in outcomes) if (outcome.failed) outcome];
}

/// 导入目标：一个已打开的规则库 + prefs 写入视图。
class BackupImportTarget {
  const BackupImportTarget({required this.store, required this.database});

  final LegacyPrefsStore store;

  /// `null` 表示全新安装（规则/订阅无法写入，相关分组会如实报失败）。
  final Database? database;

  LegacySettings get settings => LegacySettings(store);
}

/// 备份导入器。
class BackupImporter {
  const BackupImporter();

  /// 解析并合并 [content]。
  ///
  /// 格式错误收成 [BackupImportResult.failed] 而不是抛出：调用点在系统文件选择器
  /// 之后，用户刚挑了一个文件，需要看到「这个文件为什么不能用」，而不是红屏。
  Future<BackupImportResult> import(
    String content,
    BackupImportTarget target, {
    String? sourceName,
  }) async {
    final _ParsedBackup parsed;
    try {
      parsed = _parse(content);
    } on BackupFormatException catch (error) {
      return BackupImportResult.failed(error.message);
    }
    final data = parsed.data;
    final outcomes = <BackupGroupOutcome>[];
    var subscriptionCount = 0;

    for (final group in BackupGroup.values) {
      final value = data[group.key];
      // 没出现在文件里的分组不是错误：用户导出时可能没勾它。
      if (value == null) continue;
      try {
        final outcome = await _applyGroup(group, value, target);
        outcomes.add(outcome);
        if (group == BackupGroup.subscriptions) {
          subscriptionCount = outcome.added;
        }
      } catch (error) {
        debugPrint('backup import failed for ${group.key}: $error');
        outcomes.add(BackupGroupOutcome(group: group, error: '$error'));
      }
    }

    return BackupImportResult(
      occurredAt: parsed.exportedAt,
      outcomes: outcomes,
      sourceName: sourceName,
      subscriptionCount: subscriptionCount,
    );
  }

  // ------------------------------------------------------------------ 解析

  /// 校验并解出 `data` 与 `exportedAt`。
  ///
  /// 三道校验缺一不可：`format` 区分「我的备份」与「随便一个 JSON」，`version`
  /// 挡住新版写的文件（解析不完整比拒绝更危险），`data` 必须是对象。
  _ParsedBackup _parse(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const BackupFormatException('文件内容为空');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException catch (error) {
      throw BackupFormatException('不是合法的 JSON：${error.message}');
    }
    if (decoded is! Map) {
      throw const BackupFormatException('备份文件的根节点必须是 JSON 对象');
    }
    final format = decoded['format'];
    if (format != BackupFormat.magic) {
      throw const BackupFormatException('这不是谛听的备份文件');
    }
    final version = decoded['version'];
    if (version is! int) {
      throw const BackupFormatException('备份文件缺少版本号');
    }
    if (version > BackupFormat.maxReadableVersion) {
      throw BackupFormatException(
        '备份版本 $version 高于本版应用支持的 ${BackupFormat.maxReadableVersion}，'
        '请升级应用后再导入',
      );
    }
    final data = decoded['data'];
    if (data is! Map) {
      throw const BackupFormatException('备份文件缺少 data 段');
    }
    final exportedAt = decoded['exportedAt'];
    return _ParsedBackup(
      data: {for (final entry in data.entries) '${entry.key}': entry.value},
      exportedAt: exportedAt is int
          ? DateTime.fromMillisecondsSinceEpoch(exportedAt)
          : null,
    );
  }

  // ------------------------------------------------------------------ 合并

  Future<BackupGroupOutcome> _applyGroup(
    BackupGroup group,
    Object? value,
    BackupImportTarget target,
  ) async => switch (group) {
    BackupGroup.providers => _importProviders(value, target),
    BackupGroup.bootstrap => _importBootstrap(value, target),
    BackupGroup.cache => _importCache(value, target),
    BackupGroup.outbound => _importOutbound(value, target),
    BackupGroup.subscriptions => await _importSubscriptions(value, target),
    BackupGroup.domainRules => await _importRules(
      value,
      target,
      RuleKind.block,
      group,
    ),
    BackupGroup.rewriteDomain => await _importRewrite(
      value,
      target,
      const {'IPv4', 'IPv6'},
      group,
    ),
    BackupGroup.rewriteCname => await _importRewrite(
      value,
      target,
      const {'CNAME'},
      group,
    ),
    BackupGroup.addressRules => await _importAddressRules(value, target),
    BackupGroup.excluded => _importExcluded(value, target),
    BackupGroup.blocked => _importBlocked(value, target),
    BackupGroup.allowlist => _importAllowlist(value, target),
    BackupGroup.httpInspection => _importHttpInspection(value, target),
    BackupGroup.appearance => _importAppearance(value, target),
    BackupGroup.system => _importSystem(value, target),
  };

  /// 服务商：按名字去重，同名不同配置时更新。
  BackupGroupOutcome _importProviders(Object? value, BackupImportTarget target) {
    if (value is! List) {
      throw const BackupFormatException('服务商分组应为数组');
    }
    final existing = _decodeProviders(target.settings.userProvidersJson);
    final byName = {for (final item in existing) _nameOf(item): item};
    var added = 0;
    var updated = 0;
    var skipped = 0;
    for (final item in value) {
      if (item is! Map) {
        skipped++;
        continue;
      }
      final name = _nameOf(item);
      if (name.isEmpty) {
        skipped++;
        continue;
      }
      final current = byName[name];
      if (current == null) {
        existing.add(item);
        byName[name] = item;
        added++;
      } else if (_encode(current) == _encode(item)) {
        skipped++;
      } else {
        final index = existing.indexOf(current);
        existing[index] = item;
        byName[name] = item;
        updated++;
      }
    }
    if (added > 0 || updated > 0) {
      target.store.putString(
        LegacySettings.uiContainer,
        'user_providers_json',
        jsonEncode(existing),
      );
    }
    return BackupGroupOutcome(
      group: BackupGroup.providers,
      added: added,
      skipped: skipped,
      updated: updated,
    );
  }

  List<Map<Object?, Object?>> _decodeProviders(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map) Map<Object?, Object?>.from(item),
      ];
    } on FormatException {
      return [];
    }
  }

  String _nameOf(Map<Object?, Object?> provider) {
    final name = provider['name'];
    return name is String ? name.trim() : '';
  }

  /// 稳定的字符串形式，用来判断「是否完全相同」。
  String _encode(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => '$key').toList()..sort();
      return '{${keys.map((key) => '$key:${_encode(value[key])}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(_encode).join(',')}]';
    }
    return '$value';
  }

  BackupGroupOutcome _importBootstrap(
    Object? value,
    BackupImportTarget target,
  ) {
    if (value is! Map) {
      throw const BackupFormatException('Bootstrap 分组应为对象');
    }
    final settings = target.settings;
    var added = 0;
    var skipped = 0;

    final enabled = value['enabled'];
    if (enabled is bool) {
      settings.setBootstrapEnabled(enabled);
      added++;
    } else {
      skipped++;
    }

    final presetIds = value['presetIds'];
    if (presetIds is List) {
      settings.setBootstrapPresetIds({
        for (final id in presetIds)
          if (id is String) id,
      });
      added++;
    } else {
      skipped++;
    }

    final custom = value['custom'];
    if (custom != null) {
      // 原样写回它自己的 JSON 编码：这一项本来就是「用户自定义节点的原始文本」。
      settings.setBootstrapCustomJson(jsonEncode(custom));
      added++;
    } else {
      skipped++;
    }

    return BackupGroupOutcome(
      group: BackupGroup.bootstrap,
      added: added,
      skipped: skipped,
    );
  }

  /// 缓存策略：整组原子写入。
  ///
  /// 用 `applyCachePreset` 而不是逐个 setter：九个键必须一起落盘，否则引擎可能
  /// 读到「新模式 + 旧 TTL」的组合（`DnsCacheSettingsStore` 就是为这个原因把九
  /// 个键放在一次提交里）。
  BackupGroupOutcome _importCache(Object? value, BackupImportTarget target) {
    if (value is! Map) {
      throw const BackupFormatException('缓存分组应为对象');
    }
    final settings = target.settings;
    // 备份里缺的键回落到本机当前值，保证写出去的九项是一致的。
    final enabled = value['enabled'];
    final mode = value['mode'];
    final preset = value['preset'];
    final maxTtl = value['maxTtlSeconds'];
    final fixedTtl = value['fixedTtlSeconds'];
    final minTtlEnabled = value['minTtlEnabled'];
    final minTtl = value['minTtlSeconds'];
    final staleEnabled = value['staleFallbackEnabled'];
    final staleSeconds = value['staleFallbackSeconds'];

    settings.applyCachePreset(
      storageValue: preset is String ? preset : (settings.cachePresetRaw ?? ''),
      enabled: enabled is bool ? enabled : settings.cacheEnabled,
      mode: mode is String ? mode : settings.cacheModeRaw,
      maxTtlSeconds: maxTtl is int ? maxTtl : settings.cacheMaxTtlSeconds,
      fixedTtlSeconds: fixedTtl is int
          ? fixedTtl
          : settings.cacheFixedTtlSeconds,
      minTtlEnabled: minTtlEnabled is bool
          ? minTtlEnabled
          : settings.cacheMinTtlEnabled,
      minTtlSeconds: minTtl is int ? minTtl : settings.cacheMinTtlSeconds,
      staleFallbackEnabled: staleEnabled is bool
          ? staleEnabled
          : settings.cacheStaleFallbackEnabled,
      staleFallbackSeconds: staleSeconds is int
          ? staleSeconds
          : settings.cacheStaleFallbackSeconds,
    );
    return const BackupGroupOutcome(
      group: BackupGroup.cache,
      // 九项一起算一条策略：报「9 项」会让汇总看起来像导入了九条规则。
      added: 1,
    );
  }

  /// 出站代理：备份不含凭据，所以只能恢复「非凭据」的那几项。
  ///
  /// 恢复的开关若为真但本机没有凭据，代理会连不上。这里**不**自动把它打开：
  /// 报「已更新」而实际连不上，比明确跳过更糟。
  BackupGroupOutcome _importOutbound(
    Object? value,
    BackupImportTarget target,
  ) {
    if (value is! Map) {
      throw const BackupFormatException('出站代理分组应为对象');
    }
    var restored = 0;
    for (final entry in const {
      'protocol': 'outbound_proxy_protocol',
      'host': 'outbound_proxy_host',
      'proxyAppPackage': 'outbound_proxy_app_package',
    }.entries) {
      final raw = value[entry.key];
      if (raw is String && raw.isNotEmpty) {
        target.store.putString(
          LegacySettings.uiContainer,
          entry.value,
          raw,
        );
        restored++;
      }
    }
    final port = value['port'];
    if (port is int) {
      target.store.putInt(
        LegacySettings.uiContainer,
        'outbound_proxy_port',
        port,
      );
      restored++;
    }
    return BackupGroupOutcome(
      group: BackupGroup.outbound,
      // 账号密码不在备份里，所以「新增」只覆盖地址类字段。
      added: restored,
    );
  }

  Future<BackupGroupOutcome> _importSubscriptions(
    Object? value,
    BackupImportTarget target,
  ) async {
    if (value is! Map) {
      throw const BackupFormatException('订阅分组应为对象');
    }
    final db = target.database;
    if (db == null) {
      throw const BackupFormatException('本机还没有规则库，无法导入订阅');
    }
    final repository = SubscriptionRepository(db);
    final groupsValue = value['groups'];
    final groupIdByName = <String, int>{};
    var added = 0;
    var skipped = 0;
    var updated = 0;

    if (groupsValue is List) {
      for (final item in groupsValue) {
        if (item is! Map) continue;
        final name = item['name'];
        if (name is! String || name.trim().isEmpty) continue;
        final existing = await repository.groupByName(name);
        if (existing == null) {
          final id = await repository.insertGroup(
            name: name,
            autoUpdateEnabled: item['autoUpdateEnabled'] != false,
          );
          groupIdByName[name] = id;
          added++;
        } else {
          groupIdByName[name] = existing.id;
          skipped++;
        }
      }
    }

    final items = value['items'];
    if (items is List) {
      for (final item in items) {
        if (item is! Map) {
          skipped++;
          continue;
        }
        final url = item['url'];
        if (url is! String || url.trim().isEmpty) {
          skipped++;
          continue;
        }
        final kind = SubscriptionKind.normalize(item['kind'] as String?);
        final existing = await repository.byUrlAndKind(url, kind);
        if (existing != null) {
          skipped++;
          continue;
        }
        final groupName = item['groupName'];
        final now = DateTime.now().millisecondsSinceEpoch;
        await repository.insert(
          SubscriptionRecord(
            id: 0,
            url: url,
            name: item['name'] as String? ?? url,
            sourceType: SubscriptionSourceType.fromStorage(
              item['sourceType'] as String?,
            ),
            kind: kind,
            enabled: item['enabled'] != false,
            // 导入的是「订阅地址」而不是它的内容：规则条数与导入时间必须从零
            // 开始，否则界面会显示一个本机并不存在的规则数，且订阅会一直停在
            // 「已是最新」而永不真正下载一次。
            ruleCount: 0,
            lastUpdated: 0,
            addedAt: now,
            importState: SubscriptionImportState.ready,
            lastAttemptAt: 0,
            consecutiveFailureCount: 0,
            mirrorTemplate: item['mirrorTemplate'] as String?,
            mirrorFallback: item['mirrorFallback'] != false,
            groupId: groupName is String ? groupIdByName[groupName] : null,
          ),
        );
        added++;
      }
    }

    return BackupGroupOutcome(
      group: BackupGroup.subscriptions,
      added: added,
      skipped: skipped,
      updated: updated,
    );
  }

  /// 域名规则：按 pattern 去重，已存在即跳过（内容不同也不覆盖）。
  ///
  /// 不覆盖的原因：同一条 domain 在本机可能被用户手工调整过（important /
  /// appScope），备份里的旧副本不该把这些改动冲掉。旧版同样只做「新增」。
  Future<BackupGroupOutcome> _importRules(
    Object? value,
    BackupImportTarget target,
    RuleKind kind,
    BackupGroup group,
  ) async {
    if (value is! List) {
      throw const BackupFormatException('规则分组应为数组');
    }
    final db = target.database;
    if (db == null) {
      throw const BackupFormatException('本机还没有规则库，无法导入规则');
    }
    final repository = RuleRepository(db);
    final existing = {
      for (final rule in await repository.loadKind(kind)) rule.pattern,
    };
    var added = 0;
    var skipped = 0;
    for (final item in value) {
      if (item is! Map) {
        skipped++;
        continue;
      }
      final pattern = item['pattern'];
      if (pattern is! String || pattern.trim().isEmpty) {
        skipped++;
        continue;
      }
      if (!existing.add(pattern.trim())) {
        skipped++;
        continue;
      }
      await repository.add(kind, pattern.trim());
      added++;
    }
    return BackupGroupOutcome(
      group: group,
      added: added,
      skipped: skipped,
    );
  }

  /// 覆写规则：本机同 pattern + targetType 不同目标值时**更新**（见文件头）。
  Future<BackupGroupOutcome> _importRewrite(
    Object? value,
    BackupImportTarget target,
    Set<String> targetTypes,
    BackupGroup group,
  ) async {
    if (value is! List) {
      throw const BackupFormatException('覆写规则分组应为数组');
    }
    final db = target.database;
    if (db == null) {
      throw const BackupFormatException('本机还没有规则库，无法导入覆写规则');
    }
    var added = 0;
    var skipped = 0;
    var updated = 0;
    for (final item in value) {
      if (item is! Map) {
        skipped++;
        continue;
      }
      final pattern = item['pattern'];
      final targetValue = item['targetValue'];
      final targetType = item['targetType'];
      if (pattern is! String ||
          pattern.trim().isEmpty ||
          targetValue is! String ||
          targetType is! String ||
          !targetTypes.contains(targetType)) {
        skipped++;
        continue;
      }
      final existing = await db.query(
        'rewrite_rule',
        columns: ['id', 'targetValue'],
        where: 'pattern = ? AND targetType = ?',
        whereArgs: [pattern.trim(), targetType],
        limit: 1,
      );
      if (existing.isEmpty) {
        await _insertRewrite(db, pattern.trim(), targetType, targetValue);
        added++;
      } else if (existing.first['targetValue'] == targetValue) {
        skipped++;
      } else {
        await db.update(
          'rewrite_rule',
          {
            'targetValue': targetValue,
            'rawLine': '${pattern.trim()} $targetValue',
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
        updated++;
      }
    }
    return BackupGroupOutcome(
      group: group,
      added: added,
      skipped: skipped,
      updated: updated,
    );
  }

  Future<void> _insertRewrite(
    Database db,
    String pattern,
    String targetType,
    String targetValue,
  ) async {
    final id = await db.insert('rewrite_rule', {
      'pattern': pattern,
      'targetType': targetType,
      'targetValue': targetValue,
      'rawLine': '$pattern $targetValue',
      'addedAt': DateTime.now().millisecondsSinceEpoch,
      'enabled': 1,
    });
    await db.insert('rewrite_rule_source', {
      'ruleId': id,
      'source': 'useradd',
      'enabled': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<BackupGroupOutcome> _importAddressRules(
    Object? value,
    BackupImportTarget target,
  ) async {
    if (value is! List) {
      throw const BackupFormatException('地址规则分组应为数组');
    }
    final db = target.database;
    if (db == null) {
      throw const BackupFormatException('本机还没有规则库，无法导入地址规则');
    }
    var added = 0;
    var skipped = 0;
    for (final item in value) {
      if (item is! Map) {
        skipped++;
        continue;
      }
      final pattern = item['pattern'];
      final kind = item['kind'];
      if (pattern is! String ||
          pattern.trim().isEmpty ||
          kind is! String ||
          kind.isEmpty) {
        skipped++;
        continue;
      }
      final existing = await db.query(
        'go_url_rule',
        columns: ['id'],
        where: 'pattern = ? AND kind = ?',
        whereArgs: [pattern.trim(), kind],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        skipped++;
        continue;
      }
      final id = await db.insert('go_url_rule', {
        'pattern': pattern.trim(),
        'kind': kind,
        'rawLine': pattern.trim(),
        'addedAt': DateTime.now().millisecondsSinceEpoch,
        'enabled': item['enabled'] == false ? 0 : 1,
      });
      await db.insert('go_url_rule_source', {
        'ruleId': id,
        'source': 'useradd',
        'enabled': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      added++;
    }
    return BackupGroupOutcome(
      group: BackupGroup.addressRules,
      added: added,
      skipped: skipped,
    );
  }

  // ------------------------------------------------------------- 应用名单

  BackupGroupOutcome _importExcluded(Object? value, BackupImportTarget target) {
    final incoming = _stringSet(value);
    if (incoming.isEmpty) {
      return const BackupGroupOutcome(group: BackupGroup.excluded, skipped: 1);
    }
    final settings = target.settings;
    final merged = {...settings.excludedPackages, ...incoming};
    final added = merged.length - settings.excludedPackages.length;
    settings.setExcludedPackages(merged);
    return BackupGroupOutcome(
      group: BackupGroup.excluded,
      added: added,
      skipped: incoming.length - added,
    );
  }

  BackupGroupOutcome _importBlocked(Object? value, BackupImportTarget target) {
    if (value is! Map) {
      throw const BackupFormatException('禁止联网分组应为对象');
    }
    final incoming = _stringSet(value['packages']);
    final settings = target.settings;
    final merged = {...settings.blockedAppPackages, ...incoming};
    final added = merged.length - settings.blockedAppPackages.length;
    settings.setBlockedApps(
      packages: merged,
      // 开关按「备份或本机任一为真」取并集：用户导入一份开了这项的备份，
      // 却因为本机是关的而整体无效，会让人以为导入没生效。
      enabled: settings.blockedAppsEnabled || value['enabled'] == true,
    );
    return BackupGroupOutcome(
      group: BackupGroup.blocked,
      added: added,
      skipped: incoming.length - added,
    );
  }

  BackupGroupOutcome _importAllowlist(Object? value, BackupImportTarget target) {
    if (value is! Map) {
      throw const BackupFormatException('应用独立规则分组应为对象');
    }
    final rules = value['rules'];
    final settings = target.settings;
    final merged = {
      for (final entry in settings.appAllowlistRules.entries)
        entry.key: {...entry.value},
    };
    var added = 0;
    if (rules is Map) {
      for (final entry in rules.entries) {
        final package = '${entry.key}';
        if (package.trim().isEmpty) continue;
        final domains = _stringSet(entry.value);
        if (domains.isEmpty) continue;
        final existing = merged[package] ?? <String>{};
        final before = existing.length;
        merged[package] = {...existing, ...domains};
        added += merged[package]!.length - before;
      }
    }
    settings.setAppAllowlistRules(merged);
    settings.setAppAllowlistEnabled(
      settings.appAllowlistEnabled || value['enabled'] == true,
    );
    return BackupGroupOutcome(
      group: BackupGroup.allowlist,
      added: added,
      skipped: added == 0 ? 1 : 0,
    );
  }

  BackupGroupOutcome _importHttpInspection(
    Object? value,
    BackupImportTarget target,
  ) {
    if (value is! Map) {
      throw const BackupFormatException('HTTPS 抓包分组应为对象');
    }
    final incoming = _stringSet(value['packages']);
    final settings = target.settings;
    final merged = {...settings.httpInspectionPackages, ...incoming};
    final added = merged.length - settings.httpInspectionPackages.length;
    settings.setHttpInspectionApps(
      packages: merged,
      // 抓包开关**不**从备份打开：`https_inspection_ready` 依赖本机是否装了
      // CA，拿别人的开关来打开本机的抓包会让每个 HTTPS 请求都失败。
      enabled: settings.httpInspectionEnabled,
    );
    return BackupGroupOutcome(
      group: BackupGroup.httpInspection,
      added: added,
      skipped: incoming.length - added,
    );
  }

  // ----------------------------------------------------------------- 设置

  /// 外观：本机已有值的项跳过（见文件头「合并语义」）。
  BackupGroupOutcome _importAppearance(
    Object? value,
    BackupImportTarget target,
  ) {
    if (value is! Map) {
      throw const BackupFormatException('外观分组应为对象');
    }
    final settings = target.settings;
    var added = 0;
    var skipped = 0;

    void applyIfAbsent(String? current, void Function() write) {
      if (current != null && current.isNotEmpty) {
        skipped++;
      } else {
        write();
        added++;
      }
    }

    final themeMode = value['themeMode'];
    if (themeMode is String) {
      applyIfAbsent(settings.themeModeRaw, () => settings.setThemeModeRaw(themeMode));
    }
    final palette = value['palette'];
    if (palette is String) {
      applyIfAbsent(settings.paletteRaw, () => settings.setPaletteRaw(palette));
    }
    final bottomBarIds = value['bottomBarIds'];
    if (bottomBarIds is List) {
      final ids = [for (final id in bottomBarIds) if (id is String) id];
      if (ids.length >= LegacySettings.bottomBarMinCount) {
        settings.setBottomBarIds(ids);
        added++;
      } else {
        skipped++;
      }
    }
    final glass = value['liquidGlassMode'];
    if (glass is String) {
      settings.setLiquidGlassModeRaw(glass);
      added++;
    }
    final haptic = value['hapticEnabled'];
    if (haptic is bool) {
      settings.setHapticEnabled(haptic);
      added++;
    }

    return BackupGroupOutcome(
      group: BackupGroup.appearance,
      added: added,
      skipped: skipped,
    );
  }

  /// 系统设置：同上，本机已有值跳过。
  BackupGroupOutcome _importSystem(Object? value, BackupImportTarget target) {
    if (value is! Map) {
      throw const BackupFormatException('系统设置分组应为对象');
    }
    final settings = target.settings;
    var added = 0;
    var skipped = 0;

    final bypassLan = value['bypassLan'];
    if (bypassLan is bool) {
      settings.setBypassLanEnabled(bypassLan);
      added++;
    }
    final ipv6 = value['ipv6Mode'];
    if (ipv6 is String) {
      settings.setIpv6ModeRaw(ipv6);
      added++;
    }
    final logDays = value['logRetentionDays'];
    if (logDays is int) {
      settings.setLogRetentionDays(logDays);
      added++;
    }
    final logMode = value['dnsLogMode'];
    if (logMode is String) {
      settings.setDnsLogModeRaw(logMode);
      added++;
    }
    final hideFromRecents = value['hideFromRecents'];
    if (hideFromRecents is bool) {
      settings.setHideFromRecentsEnabled(hideFromRecents);
      added++;
    }
    final floatingLog = value['floatingLogEnabled'];
    if (floatingLog is bool) {
      settings.setFloatingLogEnabled(floatingLog);
      added++;
    }
    final updateCheck = value['disableStartupUpdateCheck'];
    if (updateCheck is bool) {
      settings.setDisableStartupUpdateCheck(updateCheck);
      added++;
    }
    final language = value['appLanguageMode'];
    if (language is String) {
      settings.setAppLanguageModeRaw(language);
      added++;
    }
    final persistent = value['notificationPersistent'];
    if (persistent is bool) {
      settings.setNotificationPersistent(persistent);
      added++;
    }
    final speed = value['notificationSpeed'];
    if (speed is bool) {
      settings.setNotificationSpeed(speed);
      added++;
    }
    final autoUpdate = value['subscriptionAutoUpdateEnabled'];
    if (autoUpdate is bool) {
      settings.setSubscriptionAutoUpdateEnabled(autoUpdate);
      added++;
    }
    final interval = value['subscriptionAutoUpdateIntervalHours'];
    if (interval is int) {
      settings.setSubscriptionAutoUpdateIntervalHours(interval);
      added++;
    }

    return BackupGroupOutcome(
      group: BackupGroup.system,
      added: added,
      skipped: skipped == 0 && added == 0 ? 1 : skipped,
    );
  }

  /// JSON 里的字符串集合；接受数组或 `{value: ...}` 形状。
  Set<String> _stringSet(Object? value) {
    if (value is List) {
      return {
        for (final item in value)
          if (item is String && item.trim().isNotEmpty) item.trim(),
      };
    }
    if (value is Map) {
      return {
        for (final entry in value.keys)
          if ('$entry'.trim().isNotEmpty) '$entry'.trim(),
      };
    }
    return const {};
  }
}

/// 解析出来的两段。
class _ParsedBackup {
  const _ParsedBackup({required this.data, required this.exportedAt});

  final Map<String, Object?> data;
  final DateTime? exportedAt;
}

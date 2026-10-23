/// Backup import: parse, validate and merge a backup file.
///
/// Accepts both this app's `{format, version, data}` form and the legacy flat
/// root translated by [LegacyBackupReader]. Missing entries are added, identical
/// ones skipped, and differing ones updated for rules but skipped for settings.
library;

import 'dart:convert';

import 'package:diting/data/backup/backup_models.dart';
import 'package:diting/data/backup/legacy_backup_reader.dart';
import 'package:diting/data/db/rule_repository.dart';
import 'package:diting/data/db/subscription_models.dart';
import 'package:diting/data/db/subscription_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/data/vpn/provider_store.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

part 'backup_import_lists.dart';
part 'backup_import_prefs.dart';
part 'backup_import_rules.dart';
part 'backup_import_settings.dart';

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

  /// Why the whole group failed; when set, the counters are meaningless.
  final String? error;

  bool get failed => error != null;

  bool get isNoop => !failed && added == 0 && updated == 0;
}

class BackupImportResult {
  const BackupImportResult({
    required this.occurredAt,
    required this.outcomes,
    this.sourceName,
    this.cancelled = false,
    this.fatalError,
    this.subscriptionCount = 0,
    this.legacyFormat = false,
  });

  /// The user cancelled file selection; this is not a failure.
  const BackupImportResult.cancelled()
    : outcomes = const [],
      sourceName = null,
      cancelled = true,
      fatalError = null,
      occurredAt = null,
      subscriptionCount = 0,
      legacyFormat = false;

  /// The whole file could not be parsed (not a backup, too new, bad JSON).
  const BackupImportResult.failed(String this.fatalError)
    : outcomes = const [],
      sourceName = null,
      cancelled = false,
      occurredAt = null,
      subscriptionCount = 0,
      legacyFormat = false;

  final DateTime? occurredAt;
  final List<BackupGroupOutcome> outcomes;
  final String? sourceName;
  final bool cancelled;

  /// Why the whole file failed; when set, [outcomes] is empty.
  final String? fatalError;

  /// Number of subscriptions touched, used to prompt a rule refresh.
  final int subscriptionCount;

  /// The file used the legacy flat format; the success message can say so.
  final bool legacyFormat;

  bool get failed => fatalError != null;

  int get added => outcomes.fold(0, (sum, item) => sum + item.added);
  int get skipped => outcomes.fold(0, (sum, item) => sum + item.skipped);
  int get updated => outcomes.fold(0, (sum, item) => sum + item.updated);

  /// Groups that actually changed, for the summary.
  List<BackupGroupOutcome> get changed => [
    for (final outcome in outcomes)
      if (outcome.added + outcome.updated > 0) outcome,
  ];

  List<BackupGroupOutcome> get failedGroups => [
    for (final outcome in outcomes)
      if (outcome.failed) outcome,
  ];
}

class BackupImportTarget {
  const BackupImportTarget({required this.store, required this.database});

  final LegacyPrefsStore store;

  /// Null on a fresh install; rule and subscription groups then report failure.
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

    // 服务商分组里的选择状态（首选服务商、解析模式、各模式候选列表）在
    // 1.4.3 里是独立字段，放在这里统一落盘，避免和「新增/更新」计数纠缠。
    final providers = data[BackupGroup.providers.key];
    if (providers is Map && providers['selection'] is Map) {
      try {
        _applyProviderSelection(providers['selection'], target);
      } catch (error) {
        debugPrint('backup import failed for provider selection: $error');
      }
    }

    return BackupImportResult(
      occurredAt: parsed.exportedAt,
      outcomes: outcomes,
      sourceName: sourceName,
      subscriptionCount: subscriptionCount,
      legacyFormat: parsed.legacyFormat,
    );
  }

  // ------------------------------------------------------------------ 解析

  /// 校验并解出 `data` 与 `exportedAt`。
  ///
  /// 2.0 的文件走 `format` 魔数校验，1.4.3 的文件没有魔数、只有
  /// `formatVersion`，所以先认旧格式再认新格式，两种都不是才拒绝。
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
    final exportedAt = decoded['exportedAt'];
    final timestamp = exportedAt is int
        ? DateTime.fromMillisecondsSinceEpoch(exportedAt)
        : null;
    final format = decoded['format'];
    if (format != BackupFormat.magic) {
      // 旧版备份：平铺根节点，靠 `formatVersion` 标识。
      if (LegacyBackupReader.looksLegacy(decoded)) {
        return _ParsedBackup(
          data: LegacyBackupReader.toGroups(
            decoded,
            providerId: _legacyProviderId,
          ),
          exportedAt: timestamp,
          legacyFormat: true,
        );
      }
      throw const BackupFormatException(
        '这不是谛听的备份文件：既没有 format 标记，也没有 formatVersion 版本号',
      );
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
    return _ParsedBackup(
      data: {for (final entry in data.entries) '${entry.key}': entry.value},
      exportedAt: timestamp,
      legacyFormat: false,
    );
  }

  /// 旧版服务商没有 id，运行期才分配；这里按序号生成，让同一份旧备份反复
  /// 导入时得到同样的 id（否则每次导入都会多出一批「新」服务商）。
  String _legacyProviderId(int index) => 'user_legacy_$index';

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
    BackupGroup.domainRules => await _importRules(value, target, group),
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
}

/// 解析出来的两段。
class _ParsedBackup {
  const _ParsedBackup({
    required this.data,
    required this.exportedAt,
    required this.legacyFormat,
  });

  final Map<String, Object?> data;
  final DateTime? exportedAt;
  final bool legacyFormat;
}

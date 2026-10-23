part of 'backup_importer.dart';

/// 订阅与四类规则（域名、覆写、地址）的合并。
///
/// 这些分组都直接写规则库：库打不开时只能如实报失败，而不是静默跳过——
/// 用户看到的「本机还没有规则库，无法导入订阅」就是这一层抛出来的。
extension _BackupImportRules on BackupImporter {
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

    await _importMirrorTemplates(db, value['mirrorTemplates']);

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

  /// 镜像模板：按 name 去重，已存在即跳过（同 1.4.3 `RuleConfigImporter`）。
  ///
  /// 直接写表而不是绕 `SubscriptionRepository`：那张表没有增量写入口，
  /// 而 `mirror_template.name` 上有唯一索引，`ignore` 冲突即可完成去重。
  Future<void> _importMirrorTemplates(Database db, Object? value) async {
    if (value is! List) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final item in value) {
      if (item is! Map) continue;
      final name = item['name'];
      final template = item['template'];
      if (name is! String || name.trim().isEmpty) continue;
      if (template is! String || template.trim().isEmpty) continue;
      await db.insert('mirror_template', {
        'name': name.trim(),
        'template': template.trim(),
        'addedAt': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}

/// 域名规则、覆写规则与地址规则的合并。
extension _BackupImportRuleTables on BackupImporter {
  /// 域名规则：黑白名单混在同一组里，用每条规则的 `kind` 分流。
  ///
  /// 按 `pattern` 去重，已存在即跳过（内容不同也不覆盖）：同一条 domain 在本机
  /// 可能被用户手工调整过 `important`/`appScope`，备份里的旧副本不该把这些改动
  /// 冲掉。旧版 `RuleConfigImporter` 同样只做「新增」。
  ///
  /// 但**新增时必须保留原字段**：早期 2.0 走 `RuleRepository.add()`，把
  /// `appScope`（只对某个 App 生效）、`appInverted`、`important` 和
  /// `rawLine` 全丢了，于是「只屏蔽某个 App」的规则恢复后变成全局屏蔽。
  Future<BackupGroupOutcome> _importRules(
    Object? value,
    BackupImportTarget target,
    BackupGroup group,
  ) async {
    if (value is! List) {
      throw const BackupFormatException('规则分组应为数组');
    }
    final db = target.database;
    if (db == null) {
      throw const BackupFormatException('本机还没有规则库，无法导入规则');
    }
    final existing = {
      'block': <String>{},
      'allow': <String>{},
    };
    final repository = RuleRepository(db);
    for (final entry in existing.entries) {
      final kind = entry.key == 'allow' ? RuleKind.allow : RuleKind.block;
      for (final rule in await repository.loadKind(kind)) {
        entry.value.add(_ruleKey(rule.pattern, rule.important, rule.appScope));
      }
    }
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
      final isAllow = item['kind'] == 'allow';
      final table = isAllow ? 'allow_rule' : 'block_rule';
      final important = item['important'] == true;
      final appScope = _text(item['appScope']);
      final key = _ruleKey(pattern.trim(), important, appScope);
      if (!existing[isAllow ? 'allow' : 'block']!.add(key)) {
        skipped++;
        continue;
      }
      await _insertDomainRule(db, table, item, pattern.trim());
      added++;
    }
    return BackupGroupOutcome(group: group, added: added, skipped: skipped);
  }

  /// 去重键：与 1.4.3 `block_rule`/`allow_rule` 的唯一索引
  /// `(pattern, important, appScope, appInverted, dnsType, isRegex)` 对齐。
  String _ruleKey(String pattern, bool important, String? appScope) =>
      '$pattern\u0000${important ? 1 : 0}\u0000${appScope ?? ''}';

  String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// 直接写表 + `useradd` 来源，保留备份里的原始字段。
  Future<void> _insertDomainRule(
    Database db,
    String table,
    Map item,
    String pattern,
  ) async {
    final rawLine = _text(item['rawLine']) ?? pattern;
    final appScope = _text(item['appScope']);
    await db.insert(table, {
      'pattern': pattern,
      'rawLine': rawLine,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
      'enabled': item['enabled'] == false ? 0 : 1,
      'groupName': _text(item['group']),
      'important': item['important'] == true ? 1 : 0,
      'appScope': appScope,
      'appInverted': item['appInverted'] == true ? 1 : 0,
      'isWildcard': pattern.contains('*') ? 1 : 0,
      'denyallow': null,
      'isRegex': 0,
      'dnsType': null,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    // whereArgs 不接受 null，appScope 为空时必须写成 `IS NULL`。
    final rows = await db.query(
      table,
      columns: ['id'],
      where: appScope == null
          ? 'pattern = ? AND important = ? AND appScope IS NULL'
          : 'pattern = ? AND important = ? AND appScope = ?',
      whereArgs: [
        pattern,
        item['important'] == true ? 1 : 0,
        ?appScope,
      ],
      limit: 1,
    );
    if (rows.isEmpty) return;
    await db.insert('${table}_source', {
      'ruleId': rows.first['id'],
      'source': 'useradd',
      'enabled': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
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
        await _insertRewrite(db, item, pattern.trim(), targetType, targetValue);
        added++;
      } else if (existing.first['targetValue'] == targetValue) {
        skipped++;
      } else {
        await db.update(
          'rewrite_rule',
          {
            'targetValue': targetValue,
            'rawLine':
                _text(item['rawLine']) ?? '${pattern.trim()} $targetValue',
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
    Map item,
    String pattern,
    String targetType,
    String targetValue,
  ) async {
    final id = await db.insert('rewrite_rule', {
      'pattern': pattern,
      'targetType': targetType,
      'targetValue': targetValue,
      'rawLine': _text(item['rawLine']) ?? '$pattern $targetValue',
      'addedAt': DateTime.now().millisecondsSinceEpoch,
      'enabled': item['enabled'] == false ? 0 : 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    if (id == 0) return;
    await db.insert('rewrite_rule_source', {
      'ruleId': id,
      'source': 'useradd',
      'enabled': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// 地址（URL/CNAME）规则：按 `pattern` + `kind` 去重，只新增。
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
        'rawLine': _text(item['rawLine']) ?? pattern.trim(),
        'addedAt': DateTime.now().millisecondsSinceEpoch,
        'enabled': item['enabled'] == false ? 0 : 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (id != 0) {
        await db.insert('go_url_rule_source', {
          'ruleId': id,
          'source': 'useradd',
          'enabled': 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      added++;
    }
    return BackupGroupOutcome(
      group: BackupGroup.addressRules,
      added: added,
      skipped: skipped,
    );
  }
}

/// 读写 1.4.3 的 `subscription` / `subscription_group` / `subscription_auto_update_item`
/// 三张表。
///
/// SQL 逐条转写自 `data/dao/SubscriptionDao.kt`(141 行) 与
/// `data/dao/SubscriptionGroupDao.kt`(43 行)：列名、`ORDER BY`、`consecutiveFailureCount
/// = consecutiveFailureCount + 1` 这类累加都必须与 Room 一致，否则升级用户的
/// 行读出来会「看着对、口径不同」。
///
/// 本仓库只操作既有 schema，**不建表、不改 version**（表由 1.4.3 的 Room 建好，
/// 由 `LegacyDatabase.open()` 原文件打开）。
library;

import 'package:diting/data/db/subscription_models.dart';
import 'package:sqflite/sqflite.dart';

/// 一条写操作完成后要执行的回调（provider 层用它自增 revision）。
typedef SubscriptionWriteHook = void Function();

class SubscriptionRepository {
  SubscriptionRepository(this._db, {this.onChanged});

  final Database _db;

  /// 写操作完成后调用；provider 层用它自增 revision，让所有读订阅表的
  /// provider 一起重建。
  final SubscriptionWriteHook? onChanged;

  void _changed() => onChanged?.call();

  // ------------------------------------------------------------------- 读取

  /// `SELECT * FROM subscription ORDER BY addedAt DESC`
  Future<List<SubscriptionRecord>> all() async => _records(
    await _db.query('subscription', orderBy: 'addedAt DESC'),
  );

  /// `SELECT * FROM subscription WHERE sourceType = 'remote' ORDER BY addedAt DESC`
  Future<List<SubscriptionRecord>> allRemote() async => _records(
    await _db.query(
      'subscription',
      where: "sourceType = 'remote'",
      orderBy: 'addedAt DESC',
    ),
  );

  /// 自动更新的候选：远程 + 已启用 +（无分组 或 分组开启自动更新）。
  ///
  /// SQL 照抄 `SubscriptionDao.allAutoUpdatableRemote`，`LEFT JOIN` 用于放行
  /// `groupId IS NULL` 的订阅。
  Future<List<SubscriptionRecord>> allAutoUpdatableRemote() async => _records(
    await _db.rawQuery(
      'SELECT sub.* FROM subscription sub '
      'LEFT JOIN subscription_group grp ON grp.id = sub.groupId '
      "WHERE sub.sourceType = 'remote' AND sub.enabled = 1 "
      'AND (sub.groupId IS NULL OR grp.autoUpdateEnabled = 1) '
      'ORDER BY sub.addedAt DESC',
    ),
  );

  /// `SELECT * FROM subscription WHERE kind = :kind ORDER BY addedAt DESC`
  Future<List<SubscriptionRecord>> byKind(SubscriptionKind kind) async =>
      _records(
        await _db.query(
          'subscription',
          where: 'kind = ?',
          whereArgs: [kind.storageValue],
          orderBy: 'addedAt DESC',
        ),
      );

  /// `SELECT * FROM subscription WHERE sourceType = 'remote' AND kind = :kind
  /// ORDER BY addedAt DESC`
  Future<List<SubscriptionRecord>> remoteByKind(SubscriptionKind kind) async =>
      _records(
        await _db.query(
          'subscription',
          where: "sourceType = 'remote' AND kind = ?",
          whereArgs: [kind.storageValue],
          orderBy: 'addedAt DESC',
        ),
      );

  /// `SELECT * FROM subscription WHERE id = :id`
  Future<SubscriptionRecord?> byId(int id) async =>
      _first(await _db.query('subscription', where: 'id = ?', whereArgs: [id]));

  /// `SELECT * FROM subscription WHERE url = :url AND kind = :kind LIMIT 1`
  ///
  /// 这是 `(url, kind)` 唯一索引对应的查询：同址不同 kind 允许共存。
  Future<SubscriptionRecord?> byUrlAndKind(
    String url,
    SubscriptionKind kind,
  ) async => _first(
    await _db.query(
      'subscription',
      where: 'url = ? AND kind = ?',
      whereArgs: [url, kind.storageValue],
      limit: 1,
    ),
  );

  /// `SELECT * FROM subscription WHERE groupId = :groupId ORDER BY addedAt DESC`
  Future<List<SubscriptionRecord>> byGroupId(int groupId) async => _records(
    await _db.query(
      'subscription',
      where: 'groupId = ?',
      whereArgs: [groupId],
      orderBy: 'addedAt DESC',
    ),
  );

  /// `SELECT * FROM subscription_group ORDER BY addedAt ASC, name COLLATE NOCASE ASC`
  ///
  /// 排序两条子句都要保留：`addedAt` 相同的分组（同一批导入）靠
  /// `NOCASE` 的名字序稳定下来，否则 chip 行每次重建都可能换顺序。
  Future<List<SubscriptionGroupRecord>> groups() async {
    final rows = await _db.query(
      'subscription_group',
      orderBy: 'addedAt ASC, name COLLATE NOCASE ASC',
    );
    return [for (final row in rows) SubscriptionGroupRecord.fromRow(row)];
  }

  /// `SELECT * FROM subscription_group WHERE name = :name COLLATE NOCASE LIMIT 1`
  Future<SubscriptionGroupRecord?> groupByName(String name) async =>
      _firstGroup(
        await _db.query(
          'subscription_group',
          where: 'name = ? COLLATE NOCASE',
          whereArgs: [name],
          limit: 1,
        ),
      );

  /// `SELECT * FROM subscription_auto_update_item WHERE batchId = :batchId`
  Future<List<SubscriptionAutoUpdateItemRecord>> autoUpdateItems(
    String batchId,
  ) async {
    final rows = await _db.query(
      'subscription_auto_update_item',
      where: 'batchId = ?',
      whereArgs: [batchId],
    );
    return [
      for (final row in rows) SubscriptionAutoUpdateItemRecord.fromRow(row),
    ];
  }

  // ------------------------------------------------------------------- 写入

  /// 插入一条订阅，`(url, kind)` 冲突时返回已存在行的 id。
  ///
  /// Room 的 `@Insert(ABORT)` 会让冲突抛异常；Dart 侧改成「先查再插」，
  /// 因为调用方（添加订阅面板）要能把「该订阅链接已作为 hosts 规则存在」
  /// 这类提示准确指向已有的那一行，而不是只报一个 UNIQUE 约束。
  Future<int> insert(SubscriptionRecord record) async {
    final existing = await byUrlAndKind(record.url, record.kind);
    if (existing != null) {
      return existing.id;
    }
    final id = await _db.insert('subscription', {
      'url': record.url,
      'name': record.name,
      'sourceType': record.sourceType.storageValue,
      'kind': record.kind.storageValue,
      'enabled': record.enabled ? 1 : 0,
      'ruleCount': record.ruleCount,
      'lastUpdated': record.lastUpdated,
      'addedAt': record.addedAt,
      'importState': record.importState.storageValue,
      'importError': record.importError,
      'httpEtag': record.httpEtag,
      'httpLastModified': record.httpLastModified,
      'ruleSetHash': record.ruleSetHash,
      'lastAttemptAt': record.lastAttemptAt,
      'consecutiveFailureCount': record.consecutiveFailureCount,
      'mirrorTemplate': record.mirrorTemplate,
      'mirrorFallback': record.mirrorFallback ? 1 : 0,
      'groupId': record.groupId,
    });
    _changed();
    return id;
  }

  /// `UPDATE subscription SET enabled = :enabled WHERE id = :id`
  Future<void> setEnabled(int id, bool enabled) async {
    await _db.update(
      'subscription',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
  }

  /// `UPDATE subscription SET name = :name WHERE id = :id`
  Future<void> setName(int id, String name) async {
    await _db.update(
      'subscription',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
  }

  /// `UPDATE subscription SET groupId = NULL WHERE groupId = :groupId`
  Future<void> clearGroup(int groupId) async {
    await _db.update(
      'subscription',
      {'groupId': null},
      where: 'groupId = ?',
      whereArgs: [groupId],
    );
    _changed();
  }

  /// `UPDATE subscription SET name = :name, url = :url, ruleCount = :ruleCount,
  /// lastUpdated = :lastUpdated WHERE id = :id`
  Future<void> setDetails(
    int id, {
    required String name,
    required String url,
    required int ruleCount,
    required int lastUpdated,
  }) async {
    await _db.update(
      'subscription',
      {
        'name': name,
        'url': url,
        'ruleCount': ruleCount,
        'lastUpdated': lastUpdated,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
  }

  /// `UPDATE subscription SET importState = :state, importError = :error WHERE id = :id`
  Future<void> setImportState(
    int id,
    SubscriptionImportState state, {
    String? error,
  }) async {
    await _db.update(
      'subscription',
      {'importState': state.storageValue, 'importError': error},
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
  }

  /// 成功导入后的落盘：条数、时间、校验符、状态与连续失败计数一起更新。
  ///
  /// 对应 `SubscriptionManager` 里 `subscription.copy(...)` + `update()` 的那一组
  /// 字段（`ruleSetHash` 恒为 null，上游也没有算它）。
  Future<void> markImported(
    int id, {
    required int ruleCount,
    required int lastUpdated,
    required String? etag,
    required String? lastModified,
  }) async {
    await _db.update(
      'subscription',
      {
        'ruleCount': ruleCount,
        'lastUpdated': lastUpdated,
        'importState': SubscriptionImportState.ready.storageValue,
        'importError': null,
        'httpEtag': etag,
        'httpLastModified': lastModified,
        'ruleSetHash': null,
        'lastAttemptAt': lastUpdated,
        'consecutiveFailureCount': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
  }

  /// `UPDATE subscription SET importState = :state, importError = NULL,
  /// lastAttemptAt = :attemptedAt, consecutiveFailureCount = 0,
  /// httpEtag = :etag, httpLastModified = :lastModified WHERE id = :id`
  ///
  /// 304 不清 `ruleCount` / `lastUpdated`：内容没变，上次的条数仍然成立。
  Future<void> markNotModified(
    int id, {
    required int attemptedAt,
    String? etag,
    String? lastModified,
  }) async {
    await _db.update(
      'subscription',
      {
        'importState': SubscriptionImportState.ready.storageValue,
        'importError': null,
        'lastAttemptAt': attemptedAt,
        'consecutiveFailureCount': 0,
        'httpEtag': etag,
        'httpLastModified': lastModified,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
  }

  /// `UPDATE subscription SET importState = :state, importError = :error,
  /// lastAttemptAt = :attemptedAt,
  /// consecutiveFailureCount = consecutiveFailureCount + 1 WHERE id = :id`
  ///
  /// 累加而不是置 1：连续失败次数是重试退避的输入，置 1 会让「连续失败 5 次」
  /// 永远显示 1。
  Future<void> markUpdateFailed(
    int id, {
    required String error,
    required int attemptedAt,
  }) async {
    await _db.rawUpdate(
      'UPDATE subscription SET importState = ?, importError = ?, '
      'lastAttemptAt = ?, '
      'consecutiveFailureCount = consecutiveFailureCount + 1 WHERE id = ?',
      [SubscriptionImportState.failed.storageValue, error, attemptedAt, id],
    );
    _changed();
  }

  /// `UPDATE subscription SET ruleCount = 0, lastUpdated = 0, httpEtag = NULL,
  /// httpLastModified = NULL, ruleSetHash = NULL`
  ///
  /// 规则表被清空后，订阅行上的条数与校验符都失效，必须整表归零；否则下一次
  /// 更新会带 `If-None-Match` 拿到 304，界面显示「有 48213 条规则」而库里一条
  /// 都没有。
  Future<void> resetAfterRuleCleanup() async {
    await _db.update('subscription', {
      'ruleCount': 0,
      'lastUpdated': 0,
      'httpEtag': null,
      'httpLastModified': null,
      'ruleSetHash': null,
    });
    _changed();
  }

  /// `DELETE FROM subscription WHERE id = :id`
  ///
  /// `subscription_auto_update_item` 上的外键是 `ON DELETE CASCADE`，级联删除
  /// 依赖 `PRAGMA foreign_keys = ON`（`LegacyDatabase.open()` 已在 onConfigure
  /// 里打开）。
  Future<void> deleteById(int id) async {
    await _db.delete('subscription', where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  /// `DELETE FROM subscription WHERE kind = :kind`
  Future<void> deleteByKind(SubscriptionKind kind) async {
    await _db.delete(
      'subscription',
      where: 'kind = ?',
      whereArgs: [kind.storageValue],
    );
    _changed();
  }

  // --------------------------------------------------------------- 分组写入

  /// 新建分组。同名（`COLLATE NOCASE`）已存在时返回已有行的 id。
  Future<int> insertGroup({
    required String name,
    bool autoUpdateEnabled = true,
    int? addedAt,
  }) async {
    final existing = await groupByName(name);
    if (existing != null) {
      return existing.id;
    }
    final id = await _db.insert('subscription_group', {
      'name': name,
      'autoUpdateEnabled': autoUpdateEnabled ? 1 : 0,
      'addedAt': addedAt ?? DateTime.now().millisecondsSinceEpoch,
    });
    _changed();
    return id;
  }

  /// `UPDATE subscription_group SET name = :name WHERE id = :id`
  Future<void> setGroupName(int id, String name) async {
    await _db.update(
      'subscription_group',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
  }

  /// `UPDATE subscription_group SET autoUpdateEnabled = :enabled WHERE id = :id`
  Future<void> setGroupAutoUpdateEnabled(int id, bool enabled) async {
    await _db.update(
      'subscription_group',
      {'autoUpdateEnabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
  }

  /// 解散分组：组内订阅移到「未分组」，分组行删除，订阅本身保留。
  ///
  /// 两条语句必须同一事务：中途失败会留下「分组没了但订阅还挂在旧 groupId 上」
  /// 的孤儿行，`byGroupId` 之后再也查不到它们。
  Future<void> dissolveGroup(int id) async {
    await _db.transaction((txn) async {
      await txn.update(
        'subscription',
        {'groupId': null},
        where: 'groupId = ?',
        whereArgs: [id],
      );
      await txn.delete('subscription_group', where: 'id = ?', whereArgs: [id]);
    });
    _changed();
  }

  /// `DELETE FROM subscription_group WHERE id = :id`（不处理组内订阅）。
  Future<void> deleteGroupById(int id) async {
    await _db.delete('subscription_group', where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  // ----------------------------------------------------------------- 内部

  static List<SubscriptionRecord> _records(List<Map<String, Object?>> rows) => [
    for (final row in rows) SubscriptionRecord.fromRow(row),
  ];

  static SubscriptionRecord? _first(List<Map<String, Object?>> rows) =>
      rows.isEmpty ? null : SubscriptionRecord.fromRow(rows.first);

  static SubscriptionGroupRecord? _firstGroup(List<Map<String, Object?>> rows) =>
      rows.isEmpty ? null : SubscriptionGroupRecord.fromRow(rows.first);
}

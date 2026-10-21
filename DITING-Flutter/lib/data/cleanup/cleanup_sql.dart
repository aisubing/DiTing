/// 数据清理用到的 SQLite 与 prefs 原语。
///
/// 抽出来的原因：16 个清理动作里每一处都要「删表、删条件行、删孤儿行」，
/// 各写一份 try/catch 就会出现「某张表缺失时整批中断」与「不同表的异常文案」
/// 两套行为。所有原语**不抛异常**——表不存在（极速库没有 `http_request_log`、
/// 服务器库没有日志表）是合法情形，不是清理失败。
library;

import 'package:diting/data/db/legacy_database.dart';
import 'package:diting/data/db/preset_whitelist.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

/// 一次清理会话里共享的 sqlite 句柄。
///
/// 同一份库文件只打开一次：`LegacyDatabase.open` 每次都会走一遍
/// `databaseExists` + `openDatabase`，而「清理全部本地数据」会连续调用十几个
/// 动作，逐个打开会让同一个文件被反复 open。
class CleanupDatabases {
  CleanupDatabases(this._open);

  final Future<Database?> Function(String fileName) _open;
  final Map<String, Database?> _cache = {};

  Future<Database?> of(String fileName) async =>
      _cache.containsKey(fileName) ? _cache[fileName] : (_cache[fileName] = await _open(fileName));

  Future<Database?> get main => of(LegacyDatabase.mainFile);

  Future<Database?> get express => of(LegacyDatabase.expressFile);

  Future<Database?> get server => of(LegacyDatabase.serverFile);

  /// 三个规则库中实际存在的那些。
  ///
  /// 顺序固定（普通 → 极速 → 服务器）：确认框上写的是「全部」，用户预期三份都
  /// 清掉，而字典遍历顺序不稳定会让测试间歇性失败。
  Future<List<Database>> ruleDatabases() async {
    final databases = <Database>[];
    for (final fileName in _ruleFiles) {
      final db = await of(fileName);
      if (db != null) databases.add(db);
    }
    return databases;
  }

  /// 只含运行数据表（日志 / 缓存）的库：普通与极速。服务器库没有这些表。
  Future<List<Database>> runtimeDatabases() async {
    final databases = <Database>[];
    for (final fileName in [LegacyDatabase.mainFile, LegacyDatabase.expressFile]) {
      final db = await of(fileName);
      if (db != null) databases.add(db);
    }
    return databases;
  }

  bool isMain(Database db) => db.path == _cache[LegacyDatabase.mainFile]?.path;

  static const _ruleFiles = [
    LegacyDatabase.mainFile,
    LegacyDatabase.expressFile,
    LegacyDatabase.serverFile,
  ];
}

/// `DELETE FROM <table>`；表不存在时返回 0 并把原因记进日志。
Future<int> deleteAllRows(DatabaseExecutor db, String table) => _guard(
  () => db.delete(table),
  'delete $table',
);

/// `DELETE FROM <table> WHERE <where>`；表或列不存在时返回 0。
Future<int> deleteRowsWhere(
  DatabaseExecutor db,
  String table,
  String where,
) => _guard(() => db.delete(table, where: where), 'delete $table ($where)');

/// 删掉没有任何来源引用的规则行（各 DAO 的 `deleteOrphans`）。
///
/// 与旧版同名查询逐字一致：`NOT EXISTS (SELECT 1 FROM 来源表 s WHERE
/// s.ruleId = 规则表.id)`。不用 `LEFT JOIN … IS NULL`——两者在空表上的行为
/// 相同，但 `NOT EXISTS` 与旧版 SQL 一致，便于对照。
Future<int> deleteOrphanRows(
  DatabaseExecutor db,
  String ruleTable,
  String sourceTable,
) => deleteRowsWhere(
  db,
  ruleTable,
  'NOT EXISTS (SELECT 1 FROM $sourceTable s WHERE s.ruleId = $ruleTable.id)',
);

/// 订阅行的导入元数据归零（`SubscriptionDao.resetAfterRuleCleanup`）。
///
/// 不清的后果：`ruleCount` / `lastUpdated` / ETag 仍指向已被删掉的规则，下一次
/// 自动更新会拿旧 ETag 请求、被服务端判「未修改」，于是永远不重新导入。
Future<void> resetSubscriptionImportState(DatabaseExecutor db) async {
  try {
    await db.update('subscription', {
      'ruleCount': 0,
      'lastUpdated': 0,
      'httpEtag': null,
      'httpLastModified': null,
      'ruleSetHash': null,
    });
  } on DatabaseException catch (error) {
    debugPrint('cleanup: subscription reset skipped ($error)');
  }
}

/// 删掉指向已不存在订阅的自动更新任务（`SubscriptionAutoUpdateDao.deleteOrphans`）。
Future<void> deleteOrphanAutoUpdateItems(DatabaseExecutor db) async {
  try {
    await db.delete(
      'subscription_auto_update_item',
      where: 'subscriptionId NOT IN (SELECT id FROM subscription)',
    );
  } on DatabaseException catch (error) {
    debugPrint('cleanup: auto-update orphans skipped ($error)');
  }
}

/// 读预设白名单资产。读不到时返回空表，调用方据此**跳过播种**而不是清空。
///
/// 这个顺序是旧版踩过的坑：先删预设行再读资产，一旦资产缺失就会「清空了预设
/// 白名单、什么也没插入」，而播种标记照样被写成「已完成」，空状态从此永久化。
Future<List<({String domain, String group})>> loadPresetEntries({
  Future<String> Function()? load,
}) async {
  final asset = load ?? (() => rootBundle.loadString('assets/https_passthrough.txt'));
  try {
    return parsePresetWhitelist(await asset());
  } on FlutterError catch (error) {
    debugPrint('cleanup: preset whitelist asset unavailable ($error)');
    return const [];
  }
}

Future<int> _guard(Future<int> Function() action, String label) async {
  try {
    return await action();
  } on DatabaseException catch (error) {
    debugPrint('cleanup: $label ignored ($error)');
    return 0;
  }
}

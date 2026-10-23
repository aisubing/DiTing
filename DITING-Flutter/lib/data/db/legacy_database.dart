/// 打开（必要时创建）1.4.3 用的三个 SQLite 库。
///
/// ## 两个方向
///
/// - **升级**：文件由 1.4.3 的 Room 建好，这里按原文件打开，列名与
///   `user_version` 都已就位，什么都不用改。
/// - **全新安装 / 数据清理之后**：文件不存在。旧实现直接返回 `null`，于是
///   `ruleRepositoryProvider` 恒为 null——导入备份时每一组规则都报「本机还没有
///   规则库」，订阅也永远加不进去。现在改成按 `LegacySchema` 建出来。
///
/// 两种情况的库对上层完全等价：列相同、版本相同、唯一索引相同。
library;

import 'package:diting/data/db/legacy_schema.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LegacyDatabase {
  LegacyDatabase._();

  /// Normal (full tunnel) database, `AppDatabase`, version 3.
  static const mainFile = 'diting_database';

  /// Express-mode database, version 2.
  static const expressFile = 'diting_express';

  /// Server-mode rules database, version 3.
  static const serverFile = 'diting_dns_rules';

  /// 打开 [fileName]；文件不存在时按 1.4.3 的 schema 创建。
  ///
  /// 只有「创建也失败」时才返回 `null`——例如磁盘满、目录不可写。这种情况下
  /// 上层仍然按「没有规则库」降级，而不是把整个应用卡在启动。
  static Future<Database?> open(String fileName, {bool create = true}) async {
    final path = p.join(await getDatabasesPath(), fileName);
    if (!await databaseExists(path)) {
      if (!create) return null;
      return _create(path, fileName);
    }
    try {
      return await openDatabase(path, onConfigure: _configure);
    } on DatabaseException catch (error) {
      debugPrint('legacy database open failed: $fileName ($error)');
      return null;
    }
  }

  /// `PRAGMA foreign_keys` 必须在每次连接时单独打开：它是连接级设置，
  /// 库里不存。漏了它，删主规则时 `*_source` 的级联删除不会发生。
  static Future<void> _configure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<Database?> _create(String path, String fileName) async {
    final statements = LegacySchema.statementsFor(fileName);
    try {
      return await openDatabase(
        path,
        version: LegacySchema.versionOf(fileName),
        onConfigure: _configure,
        onCreate: (db, version) async {
          for (final statement in statements) {
            await db.execute(statement);
          }
        },
        onUpgrade: (db, from, to) async {
          // 走到这里说明文件存在但 `user_version` 低于预期——只可能是一份
          // 损坏或被外部工具改过的库。补齐缺的表/索引比让用户重装轻。
          await _createIfMissing(db, statements);
        },
      );
    } on DatabaseException catch (error) {
      debugPrint('legacy database create failed: $fileName ($error)');
      // 建表失败时删掉半成品，否则下次启动会打开一个缺表的库并一直报
      // 「no such column」。
      try {
        await deleteDatabase(path);
      } on DatabaseException catch (cleanupError) {
        debugPrint('legacy database cleanup failed: $fileName ($cleanupError)');
      }
      return null;
    }
  }

  /// 只补建缺失的表/索引，已有的跳过。
  ///
  /// `IF NOT EXISTS` 对「同名但列不同」的表无能为力，那种情况本函数无效——
  /// 但它只会出现在被外部工具破坏过的库上，此时能读出多少算多少。
  static Future<void> _createIfMissing(
    Database db,
    List<String> statements,
  ) async {
    for (final statement in statements) {
      try {
        await db.execute(_withIfNotExists(statement));
      } on DatabaseException catch (error) {
        debugPrint('legacy schema patch skipped: $error');
      }
    }
  }

  /// 把 `CREATE TABLE x` / `CREATE INDEX x` 改写成 `CREATE ... IF NOT EXISTS x`。
  static String _withIfNotExists(String statement) {
    if (statement.startsWith('CREATE UNIQUE INDEX ')) {
      return statement.replaceFirst(
        'CREATE UNIQUE INDEX ',
        'CREATE UNIQUE INDEX IF NOT EXISTS ',
      );
    }
    if (statement.startsWith('CREATE INDEX ')) {
      return statement.replaceFirst(
        'CREATE INDEX ',
        'CREATE INDEX IF NOT EXISTS ',
      );
    }
    return statement.replaceFirst(
      'CREATE TABLE ',
      'CREATE TABLE IF NOT EXISTS ',
    );
  }
}

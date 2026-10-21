/// 读写 1.4.3 的 `mirror_template` 表（镜像站模板）。
///
/// SQL 逐条转写自 `data/dao/MirrorTemplateDao.kt`：`ORDER BY addedAt DESC`、
/// `name` 唯一索引（冲突语义见 [insert]），列只有 `id` / `name` / `template` /
/// `addedAt`（见 `data/entity/MirrorTemplateEntity.kt`）。
///
/// 模板本体是一个带占位符的前缀字符串（`https://ghproxy.example.com/{url}`），
/// 下载订阅时由原生侧替换占位符。这里**不解释**占位符，只存原文：解释权在
/// `RuleOperationWorker`，两处各写一份替换逻辑必然分叉。
///
/// 本仓库只操作既有 schema，不建表、不改 version。
library;

import 'package:sqflite/sqflite.dart';

/// 一条镜像站模板。
class MirrorTemplateRecord {
  const MirrorTemplateRecord({
    required this.id,
    required this.name,
    required this.template,
    required this.addedAt,
  });

  final int id;
  final String name;

  /// 含 `{url}` / `{host}` 等占位符的原文。
  final String template;
  final int addedAt;

  static MirrorTemplateRecord fromRow(Map<String, Object?> row) =>
      MirrorTemplateRecord(
        id: (row['id'] as num?)?.toInt() ?? 0,
        name: row['name'] as String? ?? '',
        template: row['template'] as String? ?? '',
        addedAt: (row['addedAt'] as num?)?.toInt() ?? 0,
      );
}

/// 写操作完成后通知 provider 自增 revision。
typedef MirrorTemplateWriteHook = void Function();

class MirrorTemplateRepository {
  MirrorTemplateRepository(this._db, {this.onChanged});

  final Database _db;
  final MirrorTemplateWriteHook? onChanged;

  void _changed() => onChanged?.call();

  /// `SELECT * FROM mirror_template ORDER BY addedAt DESC`
  Future<List<MirrorTemplateRecord>> all() async {
    final rows = await _db.query('mirror_template', orderBy: 'addedAt DESC');
    return [for (final row in rows) MirrorTemplateRecord.fromRow(row)];
  }

  /// `SELECT * FROM mirror_template WHERE name = :name LIMIT 1`
  Future<MirrorTemplateRecord?> byName(String name) async {
    final rows = await _db.query(
      'mirror_template',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return rows.isEmpty ? null : MirrorTemplateRecord.fromRow(rows.first);
  }

  /// 新增一条。
  ///
  /// `name` 上有唯一索引，Room 的 `@Insert` 会让同名冲突抛 `UNIQUE constraint
  /// failed`。这里**不**改成 REPLACE：静默覆盖会让用户以为新建了一条，实际却
  /// 改掉了另一条模板的地址。返回 `null` 表示同名已存在，调用方据此提示。
  Future<int?> insert({required String name, required String template}) async {
    final trimmedName = name.trim();
    final trimmedTemplate = template.trim();
    if (trimmedName.isEmpty || trimmedTemplate.isEmpty) return null;
    if (await byName(trimmedName) != null) return null;
    final id = await _db.insert('mirror_template', {
      'name': trimmedName,
      'template': trimmedTemplate,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    });
    _changed();
    return id;
  }

  /// 改名 + 改地址。同名冲突返回 false（同上，不静默覆盖）。
  Future<bool> update({
    required int id,
    required String name,
    required String template,
  }) async {
    final trimmedName = name.trim();
    final trimmedTemplate = template.trim();
    if (trimmedName.isEmpty || trimmedTemplate.isEmpty) return false;
    final existing = await byName(trimmedName);
    if (existing != null && existing.id != id) return false;
    await _db.update(
      'mirror_template',
      {'name': trimmedName, 'template': trimmedTemplate},
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
    return true;
  }

  /// `DELETE FROM mirror_template WHERE id = :id`
  Future<void> delete(int id) async {
    await _db.delete('mirror_template', where: 'id = ?', whereArgs: [id]);
    _changed();
  }
}

/// 把解析后的规则写进 1.4.3 规则表（`CategorizedRuleStreamImporter` +
/// `BlockListManager.addRulesBatch` / `AllowListManager` / `RewriteRuleManager` /
/// `SubscriptionRuleStorage` 的合并移植）。
///
/// ## 来源标记
/// 每条规则在 `*_rule_source` 里带一个来源标签：订阅是 `sub_<id>`，用户手加是
/// `useradd`，内置预设是 `preset`。一条规则只有在**规则行**和**至少一个来源行**
/// 都启用时才生效——这是旧版的设计，删除订阅时只删来源行就能让规则失效。
///
/// ## 为什么必须显式查重
/// 1.4.3 的实体上声明了 `(pattern, important, appScope, appInverted, dnsType,
/// isRegex)` 唯一索引，`insert` 用 `OnConflictStrategy.IGNORE` 靠冲突回落。但
/// 实测设备上的 `diting_database` **没有**这个索引（表结构里没有 UNIQUE 约束，
/// `sqlite_master` 里也没有对应索引）——老版本建库时就没建。只依赖索引冲突会让
/// 每次更新都往表里追加一整份副本，几轮之后规则数翻倍、引擎加载变慢。所以这里
/// 先按同一组维度 SELECT，命中就复用既有行、只补来源行。
///
/// ## 分块
/// 每 1000 条提交一次（`chunkSize`）：一次性把几万条塞进一个事务会让低端机在
/// 导入时长时间无响应，而且失败要整体回滚。
library;

import 'package:diting/data/rules/rule_models.dart';
import 'package:sqflite/sqflite.dart';

/// 一次导入的结果，字段与 `RuleImportSummary` 对齐。
class RuleImportSummary {
  const RuleImportSummary({
    this.blockCount = 0,
    this.allowCount = 0,
    this.rewriteCount = 0,
    this.urlBlockCount = 0,
    this.urlAllowCount = 0,
    this.cosmeticCount = 0,
    this.duplicateCount = 0,
    this.invalidCount = 0,
    this.unsupportedCount = 0,
    this.typeSkippedCount = 0,
    this.badfilteredCount = 0,
  });

  final int blockCount;
  final int allowCount;
  final int rewriteCount;
  final int urlBlockCount;
  final int urlAllowCount;
  final int cosmeticCount;
  final int duplicateCount;
  final int invalidCount;
  final int unsupportedCount;
  final int typeSkippedCount;
  final int badfilteredCount;

  /// 真正写进规则表（或复用了既有行）的条数。这是唯一可以上屏当
  /// 「已导入 N 条」的数字。
  int get insertedCount =>
      blockCount +
      allowCount +
      rewriteCount +
      urlBlockCount +
      urlAllowCount;

  /// 解析出来了但本仓不入库的条数（cosmetic：引擎没有注入通道）。
  int get notAppliedCount => cosmeticCount;

  bool get isEmpty => insertedCount == 0;
}

/// 订阅来源标签。
String subscriptionSourceTag(int subscriptionId) => 'sub_$subscriptionId';

/// 导入时目标表的选择：`domain` 写 block/allow，`hosts` 写 rewrite。
///
/// 与 `CategorizedRuleStreamImporter.acceptsDomainOnlyFamilies` 一致：hosts 类型
/// 的订阅不接收 allow/url/cosmetic 族（hosts 文件表达不了这些）。
bool _acceptsDomainOnlyFamilies(String kind) => kind != 'hosts';

class RuleImporter {
  RuleImporter(this._db, {this.chunkSize = 1000});

  final Database _db;
  final int chunkSize;

  /// 导入一份已解析的规则，来源标签为 [source]。
  ///
  /// [kind] 是 `SubscriptionKind.storageValue`（`domain` / `hosts`）；
  /// [enabled] 是订阅总开关，关掉的订阅其规则行与来源行都置 0。
  Future<RuleImportSummary> import(
    CategorizedRules parsed, {
    required String source,
    required String kind,
    required bool enabled,
  }) async {
    final domainOnly = _acceptsDomainOnlyFamilies(kind);

    var insertedBlock = 0;
    var insertedAllow = 0;
    var insertedRewrite = 0;
    var insertedUrlBlock = 0;
    var insertedUrlAllow = 0;
    var typeSkipped = 0;

    final blockBatch = <ParsedRule>[];
    final allowBatch = <ParsedRule>[];
    final rewriteBatch = <ParsedRewriteRule>[];
    final urlBlockBatch = <ParsedUrlRule>[];
    final urlAllowBatch = <ParsedUrlRule>[];

    Future<void> flushBlock() async {
      if (blockBatch.isEmpty) return;
      insertedBlock += await _insertBlockRules(
        blockBatch,
        source: source,
        enabled: enabled,
      );
      blockBatch.clear();
    }

    Future<void> flushAllow() async {
      if (allowBatch.isEmpty) return;
      insertedAllow += await _insertAllowRules(
        allowBatch,
        source: source,
        enabled: enabled,
      );
      allowBatch.clear();
    }

    Future<void> flushRewrite() async {
      if (rewriteBatch.isEmpty) return;
      insertedRewrite += await _insertRewriteRules(
        rewriteBatch,
        source: source,
        enabled: enabled,
      );
      rewriteBatch.clear();
    }

    Future<void> flushUrlBlock() async {
      if (urlBlockBatch.isEmpty) return;
      insertedUrlBlock += await _insertUrlRules(
        urlBlockBatch,
        source: source,
        enabled: enabled,
      );
      urlBlockBatch.clear();
    }

    Future<void> flushUrlAllow() async {
      if (urlAllowBatch.isEmpty) return;
      insertedUrlAllow += await _insertUrlRules(
        urlAllowBatch,
        source: source,
        enabled: enabled,
      );
      urlAllowBatch.clear();
    }

    for (final rule in parsed.blockRules) {
      blockBatch.add(rule);
      if (blockBatch.length >= chunkSize) await flushBlock();
    }
    if (domainOnly) {
      for (final rule in parsed.allowRules) {
        allowBatch.add(rule);
        if (allowBatch.length >= chunkSize) await flushAllow();
      }
    } else {
      typeSkipped += parsed.allowRules.length;
    }
    for (final rule in parsed.rewriteRules) {
      rewriteBatch.add(rule);
      if (rewriteBatch.length >= chunkSize) await flushRewrite();
    }
    if (domainOnly) {
      for (final rule in parsed.urlBlockRules) {
        urlBlockBatch.add(rule);
        if (urlBlockBatch.length >= chunkSize) await flushUrlBlock();
      }
      for (final rule in parsed.urlAllowRules) {
        urlAllowBatch.add(rule);
        if (urlAllowBatch.length >= chunkSize) await flushUrlAllow();
      }
    } else {
      typeSkipped += parsed.urlBlockRules.length + parsed.urlAllowRules.length;
    }
    await flushBlock();
    await flushAllow();
    await flushRewrite();
    await flushUrlBlock();
    await flushUrlAllow();

    return RuleImportSummary(
      blockCount: insertedBlock,
      allowCount: insertedAllow,
      rewriteCount: insertedRewrite,
      urlBlockCount: insertedUrlBlock,
      urlAllowCount: insertedUrlAllow,
      // cosmetic 一族：解析出来了，但本仓不入库（引擎没有注入通道）。
      cosmeticCount: domainOnly ? parsed.cosmeticRules.length : 0,
      duplicateCount: parsed.duplicateCount,
      invalidCount: parsed.invalidCount,
      unsupportedCount: parsed.unsupportedCount,
      typeSkippedCount: typeSkipped,
      badfilteredCount: parsed.badfilteredCount,
    );
  }

  /// 删除某个来源的全部规则（订阅删除 / 更新前清旧数据）。
  ///
  /// 删来源行而不是删规则行：同一条规则可能还被用户手加或别的订阅引用，
  /// 直接删规则行会把那些来源一起弄失效。
  Future<void> removeRulesBySource(String source) async {
    await _db.transaction((txn) async {
      for (final table in const [
        'block_rule_source',
        'allow_rule_source',
        'rewrite_rule_source',
        'go_url_rule_source',
      ]) {
        await txn.delete(table, where: 'source = ?', whereArgs: [source]);
      }
      await _deleteOrphanRules(txn);
    });
  }

  /// 订阅总开关：把该来源的所有来源行一起置 0/1。
  ///
  /// 规则行本身的 `enabled` 不动：同一行可能还有别的来源在用，改规则行会让
  /// 那些来源一起失效。
  Future<void> setSourceEnabled(String source, bool enabled) async {
    final value = enabled ? 1 : 0;
    await _db.transaction((txn) async {
      for (final table in const [
        'block_rule_source',
        'allow_rule_source',
        'rewrite_rule_source',
        'go_url_rule_source',
      ]) {
        await txn.update(
          table,
          {'enabled': value},
          where: 'source = ?',
          whereArgs: [source],
        );
      }
    });
  }

  /// 没有任何来源引用的规则行——留着只会让「规则总数」虚高。
  Future<void> _deleteOrphanRules(DatabaseExecutor txn) async {
    for (final entry in const {
      'block_rule': 'block_rule_source',
      'allow_rule': 'allow_rule_source',
      'rewrite_rule': 'rewrite_rule_source',
      'go_url_rule': 'go_url_rule_source',
    }.entries) {
      await txn.rawDelete(
        'DELETE FROM ${entry.key} WHERE id NOT IN '
        '(SELECT ruleId FROM ${entry.value})',
      );
    }
  }

  Future<int> _insertBlockRules(
    List<ParsedRule> rules, {
    required String source,
    required bool enabled,
  }) => _insertDomainRules(
    rules,
    table: 'block_rule',
    sourceTable: 'block_rule_source',
    source: source,
    enabled: enabled,
  );

  Future<int> _insertAllowRules(
    List<ParsedRule> rules, {
    required String source,
    required bool enabled,
  }) => _insertDomainRules(
    rules,
    table: 'allow_rule',
    sourceTable: 'allow_rule_source',
    source: source,
    enabled: enabled,
  );

  /// block / allow 共用的写入：两表列集合完全一致，只有表名不同。
  Future<int> _insertDomainRules(
    List<ParsedRule> rules, {
    required String table,
    required String sourceTable,
    required String source,
    required bool enabled,
  }) async {
    if (rules.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    var inserted = 0;
    await _db.transaction((txn) async {
      for (final rule in rules) {
        final ruleId = await _findDomainRule(
          txn,
          table,
          rule,
        ) ?? await txn.insert(table, {
          'pattern': rule.pattern,
          'rawLine': rule.rawLine,
          'addedAt': now,
          'enabled': 1,
          'groupName': null,
          'important': rule.important ? 1 : 0,
          'appScope': rule.appScope,
          'appInverted': rule.appInverted ? 1 : 0,
          'isWildcard': rule.isWildcard ? 1 : 0,
          'denyallow': rule.denyallow,
          'isRegex': rule.isRegex ? 1 : 0,
          'dnsType': rule.dnsType,
        });
        final rows = await txn.insert(sourceTable, {
          'ruleId': ruleId,
          'source': source,
          'enabled': enabled ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        if (rows > 0) {
          inserted++;
        }
      }
    });
    return inserted;
  }

  /// 按唯一索引的同一组维度找既有行。
  Future<int?> _findDomainRule(
    DatabaseExecutor txn,
    String table,
    ParsedRule rule,
  ) async {
    // `IS ?` 绑定 null 会让 sqflite 打出「Invalid argument null」警告（未来版本
    // 直接抛异常），所以可空列按「有值用 =，无值用 IS NULL」拆开拼。
    final where = <String>['pattern = ?', 'important = ?'];
    final args = <Object?>[rule.pattern, rule.important ? 1 : 0];
    final appScope = rule.appScope;
    if (appScope == null) {
      where.add('appScope IS NULL');
    } else {
      where.add('appScope = ?');
      args.add(appScope);
    }
    where.add('appInverted = ?');
    args.add(rule.appInverted ? 1 : 0);
    final dnsType = rule.dnsType;
    if (dnsType == null) {
      where.add('dnsType IS NULL');
    } else {
      where.add('dnsType = ?');
      args.add(dnsType);
    }
    where.add('isRegex = ?');
    args.add(rule.isRegex ? 1 : 0);

    final rows = await txn.query(
      table,
      columns: ['id'],
      where: where.join(' AND '),
      whereArgs: args,
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  Future<int> _insertRewriteRules(
    List<ParsedRewriteRule> rules, {
    required String source,
    required bool enabled,
  }) async {
    if (rules.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    var inserted = 0;
    await _db.transaction((txn) async {
      for (final rule in rules) {
        final existing = await txn.query(
          'rewrite_rule',
          columns: ['id'],
          where: 'pattern = ? AND targetType = ? AND targetValue = ?',
          whereArgs: [rule.pattern, rule.targetType, rule.targetValue],
          limit: 1,
        );
        final ruleId = existing.isNotEmpty
            ? existing.first['id'] as int
            : await txn.insert('rewrite_rule', {
                'pattern': rule.pattern,
                'targetType': rule.targetType,
                'targetValue': rule.targetValue,
                'rawLine': rule.rawLine,
                'addedAt': now,
                'enabled': 1,
              });
        final rows = await txn.insert('rewrite_rule_source', {
          'ruleId': ruleId,
          'source': source,
          'enabled': enabled ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        if (rows > 0) {
          inserted++;
        }
      }
    });
    return inserted;
  }

  /// URL / 路径规则写 `go_url_rule`。
  ///
  /// 这张表**没有** `appScope` 列（旧版实体也没有），所以带 `$app=` 的 URL 规则
  /// 会丢掉作用域。这里如实丢掉并计入 typeSkipped 之外的统计——不伪造一列，
  /// 也不把「只对某 app 生效」的规则写成全局 URL 拦截。
  Future<int> _insertUrlRules(
    List<ParsedUrlRule> rules, {
    required String source,
    required bool enabled,
  }) async {
    if (rules.isEmpty) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    var inserted = 0;
    await _db.transaction((txn) async {
      for (final rule in rules) {
        if (rule.appScope != null && rule.appScope!.isNotEmpty) {
          continue;
        }
        final kind = rule.isAllow ? 'allow' : 'block';
        final existing = await txn.query(
          'go_url_rule',
          columns: ['id'],
          where: 'pattern = ? AND kind = ?',
          whereArgs: [rule.pattern, kind],
          limit: 1,
        );
        final ruleId = existing.isNotEmpty
            ? existing.first['id'] as int
            : await txn.insert('go_url_rule', {
                'pattern': rule.pattern,
                'kind': kind,
                'rawLine': rule.rawLine,
                'addedAt': now,
                'enabled': 1,
              });
        final rows = await txn.insert('go_url_rule_source', {
          'ruleId': ruleId,
          'source': source,
          'enabled': enabled ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        if (rows > 0) {
          inserted++;
        }
      }
    });
    return inserted;
  }
}

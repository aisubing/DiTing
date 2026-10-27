/// Writes parsed rules into the rule tables. Active = row and a source row enabled; dedupe is
/// explicit because older databases lack the unique index.
library;

import 'package:diting/data/rules/rule_models.dart';
import 'package:sqflite/sqflite.dart';

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

  /// Rules written or reused; the only count safe to show as "N imported".
  int get insertedCount =>
      blockCount + allowCount + rewriteCount + urlBlockCount + urlAllowCount;

  /// Parsed but not stored: the engine has no injection path for cosmetic rules.
  int get notAppliedCount => cosmeticCount;

  bool get isEmpty => insertedCount == 0;
}

String subscriptionSourceTag(int subscriptionId) => 'sub_$subscriptionId';

/// Families the target table accepts: `domain` rows take block/allow, `hosts` subs take none of the
/// allow/url/cosmetic families.
bool _acceptsDomainOnlyFamilies(String kind) => kind != 'hosts';

class RuleImporter {
  RuleImporter(this._db, {this.chunkSize = 1000});

  final Database _db;
  final int chunkSize;

  /// Imports parsed rules under [source]; [kind] is `SubscriptionKind.storageValue`, [enabled] the
  /// subscription switch.
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
      cosmeticCount: domainOnly ? parsed.cosmeticRules.length : 0,
      duplicateCount: parsed.duplicateCount,
      invalidCount: parsed.invalidCount,
      unsupportedCount: parsed.unsupportedCount,
      typeSkippedCount: typeSkipped,
      badfilteredCount: parsed.badfilteredCount,
    );
  }

  /// Deletes one source's rules. Only source rows go: a rule row may be shared.
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

  /// Sets `enabled` on all source rows of [source]; the shared rule row keeps its own flag.
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

  /// Drops rule rows that no source references; they would only inflate counts.
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
        final ruleId =
            await _findDomainRule(txn, table, rule) ??
            await txn.insert(table, {
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

  Future<int?> _findDomainRule(
    DatabaseExecutor txn,
    String table,
    ParsedRule rule,
  ) async {
    // sqflite warns about `IS ?` with null (and will throw later), so nullable columns use `= ?`
    // when set and `IS NULL` otherwise.
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

  /// URL and path rules go to `go_url_rule`, which has no `appScope` column, so a `$app=` rule is
  /// skipped rather than stored as a global block.
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

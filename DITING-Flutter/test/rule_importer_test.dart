import 'package:diting/data/db/rule_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/rules/rule_importer.dart';
import 'package:diting/data/rules/rule_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Runs the importer against the real 1.4.3 tables: rules land in `*_rule` with a `sub_<id>`
/// source row, re-imports do not duplicate, and deleting a subscription drops orphan rules
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE block_rule (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, '
      'pattern TEXT NOT NULL, rawLine TEXT NOT NULL, addedAt INTEGER NOT NULL, '
      'enabled INTEGER NOT NULL, groupName TEXT, important INTEGER NOT NULL, '
      'appScope TEXT, appInverted INTEGER NOT NULL, isWildcard INTEGER NOT NULL, '
      'denyallow TEXT, isRegex INTEGER NOT NULL, dnsType TEXT)',
    );
    await db.execute(
      'CREATE TABLE block_rule_source (ruleId INTEGER NOT NULL, source TEXT NOT NULL, '
      'enabled INTEGER NOT NULL, PRIMARY KEY(ruleId, source), '
      'FOREIGN KEY(ruleId) REFERENCES block_rule(id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE allow_rule (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, '
      'pattern TEXT NOT NULL, rawLine TEXT NOT NULL, addedAt INTEGER NOT NULL, '
      'enabled INTEGER NOT NULL, groupName TEXT, appScope TEXT, '
      'appInverted INTEGER NOT NULL, isWildcard INTEGER NOT NULL, '
      'important INTEGER NOT NULL, denyallow TEXT, isRegex INTEGER NOT NULL, '
      'dnsType TEXT)',
    );
    await db.execute(
      'CREATE TABLE allow_rule_source (ruleId INTEGER NOT NULL, source TEXT NOT NULL, '
      'enabled INTEGER NOT NULL, PRIMARY KEY(ruleId, source), '
      'FOREIGN KEY(ruleId) REFERENCES allow_rule(id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE rewrite_rule (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, '
      'pattern TEXT NOT NULL, targetType TEXT NOT NULL, targetValue TEXT NOT NULL, '
      'rawLine TEXT NOT NULL, addedAt INTEGER NOT NULL, enabled INTEGER NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE rewrite_rule_source (ruleId INTEGER NOT NULL, source TEXT NOT NULL, '
      'enabled INTEGER NOT NULL, PRIMARY KEY(ruleId, source), '
      'FOREIGN KEY(ruleId) REFERENCES rewrite_rule(id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE go_url_rule (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, '
      'pattern TEXT NOT NULL, kind TEXT NOT NULL, rawLine TEXT NOT NULL, '
      'addedAt INTEGER NOT NULL, enabled INTEGER NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE go_url_rule_source (ruleId INTEGER NOT NULL, source TEXT NOT NULL, '
      'enabled INTEGER NOT NULL, PRIMARY KEY(ruleId, source), '
      'FOREIGN KEY(ruleId) REFERENCES go_url_rule(id) ON DELETE CASCADE)',
    );
    await db.execute(
      'CREATE TABLE subscription (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, '
      'url TEXT NOT NULL, name TEXT NOT NULL)',
    );
  });

  tearDown(() => db.close());

  Future<int> count(String table) async =>
      Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $table'),
      ) ??
      0;

  test('block / allow / rewrite / url 四族分别落到对应表', () async {
    const text = '||ads.example.com^\n'
        '@@||safe.example.com^\n'
        '||rewrite.example.com^' r'$dnsrewrite=1.2.3.4' '\n'
        '||tracker.example.com/pixel.js\n';
    final parsed = parseCategorized(text);
    final importer = RuleImporter(db);

    final summary = await importer.import(
      parsed,
      source: subscriptionSourceTag(7),
      kind: 'domain',
      enabled: true,
    );

    expect(summary.blockCount, 1);
    expect(summary.allowCount, 1);
    expect(summary.rewriteCount, 1);
    expect(summary.urlBlockCount, 1);
    expect(summary.insertedCount, 4);

    expect(await count('block_rule'), 1);
    expect(await count('allow_rule'), 1);
    expect(await count('rewrite_rule'), 1);
    expect(await count('go_url_rule'), 1);

    final sources = await db.query('block_rule_source');
    expect(sources.single['source'], 'sub_7');
    expect(sources.single['enabled'], 1);
  });

  test('重复导入不新增行，只补来源', () async {
    const text = '||dup.example.com^\n||dup.example.com^';
    final parsed = parseCategorized(text);
    final importer = RuleImporter(db);

    final first = await importer.import(
      parsed,
      source: subscriptionSourceTag(1),
      kind: 'domain',
      enabled: true,
    );
    expect(first.blockCount, 1);
    expect(await count('block_rule'), 1);

    final second = await importer.import(
      parsed,
      source: subscriptionSourceTag(1),
      kind: 'domain',
      enabled: true,
    );
    // Same source again: the source row exists, so the insert is ignored.
    expect(second.blockCount, 0);
    expect(await count('block_rule'), 1, reason: '设备库没有唯一索引，必须靠查重复用');

    // Another subscription with the same pattern reuses the rule row.
    final other = await importer.import(
      parsed,
      source: subscriptionSourceTag(2),
      kind: 'domain',
      enabled: true,
    );
    expect(other.blockCount, 1);
    expect(await count('block_rule'), 1);
    expect(await count('block_rule_source'), 2);
  });

  test('hosts 类型不接收 allow / url 族', () async {
    const text = '||ads.example.com^\n@@||safe.example.com^\n';
    final parsed = parseCategorized(text);
    final importer = RuleImporter(db);

    final summary = await importer.import(
      parsed,
      source: subscriptionSourceTag(3),
      kind: 'hosts',
      enabled: true,
    );

    expect(summary.blockCount, 1);
    expect(summary.allowCount, 0);
    expect(summary.typeSkippedCount, 1);
    expect(await count('allow_rule'), 0);
  });

  test('删除来源后规则行被清掉，不留孤儿', () async {
    final importer = RuleImporter(db);
    await importer.import(
      parseCategorized('||gone.example.com^'),
      source: subscriptionSourceTag(5),
      kind: 'domain',
      enabled: true,
    );
    expect(await count('block_rule'), 1);

    await importer.removeRulesBySource(subscriptionSourceTag(5));
    expect(await count('block_rule_source'), 0);
    expect(await count('block_rule'), 0, reason: '无来源引用的规则行必须删掉');
  });

  test('删除一个订阅不影响另一个订阅的同一 pattern', () async {
    final importer = RuleImporter(db);
    const text = '||shared.example.com^';
    await importer.import(
      parseCategorized(text),
      source: subscriptionSourceTag(1),
      kind: 'domain',
      enabled: true,
    );
    await importer.import(
      parseCategorized(text),
      source: subscriptionSourceTag(2),
      kind: 'domain',
      enabled: true,
    );
    expect(await count('block_rule_source'), 2);

    await importer.removeRulesBySource(subscriptionSourceTag(1));
    expect(await count('block_rule'), 1, reason: 'sub_2 还在引用，规则行必须留着');
    expect(await count('block_rule_source'), 1);
  });

  test('关掉订阅后来源行置 0，规则行本身不动', () async {
    final importer = RuleImporter(db);
    await importer.import(
      parseCategorized('||off.example.com^'),
      source: subscriptionSourceTag(9),
      kind: 'domain',
      enabled: true,
    );

    await importer.setSourceEnabled(subscriptionSourceTag(9), false);
    var source = (await db.query('block_rule_source')).single;
    expect(source['enabled'], 0);
    // The rule row stays: other sources may reference it.
    final rule = (await db.query('block_rule')).single;
    expect(rule['enabled'], 1);

    await importer.setSourceEnabled(subscriptionSourceTag(9), true);
    source = (await db.query('block_rule_source')).single;
    expect(source['enabled'], 1);
  });

  test('cosmetic 解析出来但不入库，并单独计数', () async {
    final parsed = parseCategorized('example.com##.ad-banner');
    final importer = RuleImporter(db);
    final summary = await importer.import(
      parsed,
      source: subscriptionSourceTag(4),
      kind: 'domain',
      enabled: true,
    );
    expect(summary.insertedCount, 0);
    expect(summary.notAppliedCount, 1);
    expect(await count('block_rule'), 0);
  });

  test('入库后的规则能被 RuleRepository 读出来并进快照', () async {
    final importer = RuleImporter(db);
    await importer.import(
      parseCategorized('||snapshot.example.com^'),
      source: subscriptionSourceTag(11),
      kind: 'domain',
      enabled: true,
    );

    final rules = await RuleRepository(db).loadAll();
    final block = rules[RuleKind.block]!;
    expect(block, hasLength(1));
    expect(block.single.pattern, 'snapshot.example.com');
    expect(block.single.source, RuleSource.subscription);
    expect(block.single.enabled, isTrue);
  });

  test('带 app 作用域的 URL 规则不入 go_url_rule（该表没有 appScope 列）', () async {
    const text = '||ads.example.com/banner.js' r'$app=com.foo' '\n';
    final parsed = parseCategorized(text);
    expect(parsed.urlBlockRules.single.appScope, 'com.foo');

    final importer = RuleImporter(db);
    final summary = await importer.import(
      parsed,
      source: subscriptionSourceTag(12),
      kind: 'domain',
      enabled: true,
    );
    // Dropping the scope would turn it into a global URL block, so skip the rule.
    expect(summary.urlBlockCount, 0);
    expect(await count('go_url_rule'), 0);
  });
}

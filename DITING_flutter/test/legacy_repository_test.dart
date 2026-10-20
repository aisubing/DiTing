import 'package:diting/data/db/app_traffic_repository.dart';
import 'package:diting/data/db/dns_query_repository.dart';
import 'package:diting/data/db/http_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/legacy_schema.dart';

/// Exercises the SQL against the exact 1.4.3 table layout read off the device
/// (`sqlite3 .schema`), so column names and filter semantics cannot drift.
///
/// The schema lives in `support/legacy_schema.dart` because all three
/// observability repositories share it. Anything wrong there would let a bad
/// column name pass in memory and fail on a device only.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await createLegacySchema(db);
  });

  tearDown(() => db.close());

  Future<int> insertHttp({
    required int timestamp,
    required String outcome,
    String packageName = 'com.example.app',
    String? authority,
    String protocol = 'h2',
    String? matchedRule,
    int? blockSubscriptionId,
  }) => insertHttpRow(
    db,
    timestamp: timestamp,
    outcome: outcome,
    packageName: packageName,
    authority: authority,
    protocol: protocol,
    matchedRule: matchedRule,
    blockSubscriptionId: blockSubscriptionId,
  );

  Future<int> insertDns({
    required int timestamp,
    required String queryName,
    required String result,
    int queryType = 1,
    String? message,
    bool cached = false,
    String? packageName,
  }) => insertDnsRow(
    db,
    timestamp: timestamp,
    queryName: queryName,
    result: result,
    queryType: queryType,
    message: message,
    cached: cached,
    packageName: packageName,
  );

  Future<int> insertTraffic(
    String date,
    String packageName, {
    required int tx,
    required int rx,
    String appName = '',
    int updatedAt = 1,
  }) => insertTrafficRow(
    db,
    date,
    packageName,
    tx: tx,
    rx: rx,
    appName: appName,
    updatedAt: updatedAt,
  );

  group('http_request_log 五档筛选', () {
    /// One row per outcome the engine can write, plus an unknown one. The
    /// unknown value is the important case: 1.4.3's `else -> ERROR` branch is
    /// what keeps a newly added outcome from silently disappearing.
    const outcomes = <String>[
      'allowed',
      'rewritten',
      'blocked',
      'invalid',
      'passthrough',
      'bypassed',
      'unsupported_protocol',
      'resource_bypass',
      'decryption_failed',
    ];

    setUp(() async {
      for (final (index, outcome) in outcomes.indexed) {
        await insertHttp(
          timestamp: 1000 + index,
          outcome: outcome,
          authority: 'host$index.example',
        );
      }
    });

    test('每档的 outcome 集合与旧版 where 子句一致', () async {
      final repository = HttpRequestRepository(db);

      Future<Set<String>> outcomesOf(RequestStatus status) async {
        final rows = await repository.recent(status: status);
        return {for (final row in rows) row.outcome};
      }

      expect(await outcomesOf(RequestStatus.passed), {'allowed'});
      expect(await outcomesOf(RequestStatus.rewritten), {'rewritten'});
      expect(await outcomesOf(RequestStatus.blocked), {'blocked', 'invalid'});
      expect(await outcomesOf(RequestStatus.bypassed), {
        'passthrough',
        'bypassed',
        'unsupported_protocol',
        'resource_bypass',
      });
      // `NOT IN` 兜底：任何旧版没有列举的 outcome 都归到「失败」，
      // 而不是落进某个「已通过」的桶里。
      expect(await outcomesOf(RequestStatus.error), {'decryption_failed'});
    });

    test('五档互斥且并集等于全部', () async {
      final repository = HttpRequestRepository(db);
      final buckets = <RequestStatus, Set<int>>{};
      for (final status in RequestStatus.values) {
        if (status == RequestStatus.all) continue;
        buckets[status] = {
          for (final row in await repository.recent(status: status)) row.id,
        };
      }

      final union = <int>{};
      var sum = 0;
      for (final entry in buckets.entries) {
        sum += entry.value.length;
        union.addAll(entry.value);
      }
      final all = await repository.recent();

      expect(union.length, all.length, reason: '并集应覆盖全部行');
      expect(sum, all.length, reason: '各档条数之和应等于总数（互斥）');
    });

    test('statusOfOutcome 与 SQL 分档一致', () async {
      final all = await HttpRequestRepository(db).recent();
      for (final status in RequestStatus.values) {
        if (status == RequestStatus.all) continue;
        final bySql = {
          for (final row in await HttpRequestRepository(db).recent(
            status: status,
          ))
            row.id,
        };
        final byReader = {
          for (final row in all)
            if (row.status == status) row.id,
        };
        expect(bySql, byReader, reason: '${status.label} 的 SQL 与 Dart 判定不一致');
      }
    });

    test('关键词匹配 authority / packageName / matchedRule', () async {
      await insertHttp(
        timestamp: 2000,
        outcome: 'blocked',
        authority: 'ads.tracker.example',
        packageName: 'com.game.big',
        matchedRule: 'RULE-SET,广告拦截',
      );
      final repository = HttpRequestRepository(db);

      expect(
        (await repository.recent(query: 'tracker')).map((row) => row.outcome),
        contains('blocked'),
      );
      expect(
        (await repository.recent(query: 'com.game')).single.packageName,
        'com.game.big',
      );
      // 中文关键词：`LIKE` 对非 ASCII 是大小写敏感的，lowercase 不影响匹配，
      // 但这里要确认中文规则名能被命中。
      expect(
        (await repository.recent(query: '广告拦截')).single.matchedRule,
        'RULE-SET,广告拦截',
      );
    });

    test('按 timestamp 倒序且尊重 limit', () async {
      final rows = await HttpRequestRepository(db).recent(limit: 3);
      expect(rows, hasLength(3));
      expect(rows.first.timestamp, greaterThan(rows.last.timestamp));
      expect(rows.first.timestamp, 1000 + outcomes.length - 1);
    });

    test('dailyStats 按 outcome 分组并给出总数', () async {
      final stats = await HttpRequestRepository(
        db,
      ).dailyStats(since: DateTime.fromMillisecondsSinceEpoch(0));

      expect(stats.total, outcomes.length);
      expect(stats.byOutcome['allowed'], 1);
      expect(stats.byOutcome['blocked'], 1);
      expect(stats.countFor(RequestStatus.blocked), 2);
      expect(stats.countFor(RequestStatus.all), outcomes.length);
      // 落在 `NOT IN` 兜底里的行也要计入「失败」档。
      expect(stats.countFor(RequestStatus.error), 1);
    });

    test('dailyStats 的窗口过滤掉更早的行', () async {
      final stats = await HttpRequestRepository(
        db,
      ).dailyStats(since: DateTime.fromMillisecondsSinceEpoch(1000 + 4));
      expect(stats.total, outcomes.length - 4);
    });

    test('clearAll 清空整表', () async {
      expect(await HttpRequestRepository(db).clearAll(), outcomes.length);
      expect(await db.query('http_request_log'), isEmpty);
    });
  });

  group('dns_log 六档筛选', () {
    setUp(() async {
      // 普通放行。
      await insertDns(
        timestamp: 100,
        queryName: 'api.github.com',
        result: 'PASSED',
        packageName: 'com.example.browser',
        message: 'app=com.example.browser, resolved=140.82.113.6, '
            'elapsed=28ms',
      );
      // 连接日志：`TCP ` 前缀 + queryType 0，旧版归旁路。
      await insertDns(
        timestamp: 101,
        queryName: 'TCP 1.1.1.1:443',
        result: 'PASSED',
        queryType: 0,
        message: 'app=com.example.app, resolved=1.1.1.1',
      );
      // 连接日志的另一种写法：只有 blocked_by=connection。
      await insertDns(
        timestamp: 102,
        queryName: 'UDP 8.8.8.8:53',
        result: 'PASSED',
        queryType: 0,
        message: 'blocked_by=connection',
      );
      // 规则拦截。
      await insertDns(
        timestamp: 103,
        queryName: 'ads.example.com',
        result: 'BLOCKED',
        message: 'blocked_by=firewall:ads, elapsed=1ms',
      );
      // 覆写：结果列本身。
      await insertDns(
        timestamp: 104,
        queryName: 'rewrite-column.example',
        result: 'REWRITTEN',
        message: 'blocked_by=rewrite=1.2.3.4',
      );
      // 覆写：只靠 message 里的中文标记。
      await insertDns(
        timestamp: 105,
        queryName: 'rewrite-chinese.example',
        result: 'PASSED',
        message: '命中覆写规则 matched rewrite rule elapsed=4ms',
      );
      // 失败。
      await insertDns(
        timestamp: 106,
        queryName: 'broken.example',
        result: 'ERROR',
        message: 'error=timeout elapsed=2000ms',
      );
    });

    test('PASSED 排除 TCP / UDP 前缀行与 blocked_by=connection', () async {
      final rows = await DnsQueryRepository(
        db,
      ).recent(status: RequestStatus.passed);
      final names = {for (final row in rows) row.queryName};

      expect(names, contains('api.github.com'));
      expect(names, isNot(contains('TCP 1.1.1.1:443')));
      expect(names, isNot(contains('UDP 8.8.8.8:53')));
      // 有明确覆写标记的行不能算「通过」。
      expect(names, isNot(contains('rewrite-column.example')));
      expect(names, isNot(contains('rewrite-chinese.example')));
    });

    test('REWRITTEN 命中结果列、英文短语与中文「覆写」', () async {
      final rows = await DnsQueryRepository(
        db,
      ).recent(status: RequestStatus.rewritten);
      final names = {for (final row in rows) row.queryName};

      expect(names, contains('rewrite-column.example'));
      expect(names, contains('rewrite-chinese.example'));
      expect(names, isNot(contains('api.github.com')));
      // 覆写档同样排除连接行。
      expect(names, isNot(contains('TCP 1.1.1.1:443')));
    });

    test('BLOCKED 命中结果列与 blocked_by=firewall:', () async {
      final rows = await DnsQueryRepository(
        db,
      ).recent(status: RequestStatus.blocked);
      final names = {for (final row in rows) row.queryName};

      expect(names, contains('ads.example.com'));
      expect(names, isNot(contains('api.github.com')));
      // 被覆写的行不能同时算拦截。
      expect(names, isNot(contains('rewrite-column.example')));
    });

    test('ERROR 只取 result = ERROR', () async {
      final rows = await DnsQueryRepository(
        db,
      ).recent(status: RequestStatus.error);
      expect(rows.single.queryName, 'broken.example');
    });

    test('BYPASSED 命中 queryType = 0 与 TCP / UDP 前缀行', () async {
      final rows = await DnsQueryRepository(
        db,
      ).recent(status: RequestStatus.bypassed);
      final names = {for (final row in rows) row.queryName};

      expect(names, contains('TCP 1.1.1.1:443'));
      expect(names, contains('UDP 8.8.8.8:53'));
      // 普通域名查询不是旁路。
      expect(names, isNot(contains('api.github.com')));
      expect(names, isNot(contains('broken.example')));
    });

    test('五档互斥且并集等于全部', () async {
      final repository = DnsQueryRepository(db);
      final all = await repository.recent();
      final union = <int>{};
      var sum = 0;
      for (final status in RequestStatus.values) {
        if (status == RequestStatus.all) continue;
        final ids = {
          for (final row in await repository.recent(status: status)) row.id,
        };
        sum += ids.length;
        union.addAll(ids);
      }

      expect(union.length, all.length, reason: '并集应覆盖全部行');
      expect(sum, all.length, reason: '各档条数之和应等于总数（互斥）');
    });

    test('关键词匹配 queryName / packageName / message', () async {
      final repository = DnsQueryRepository(db);

      expect(
        (await repository.recent(query: 'github')).single.queryName,
        'api.github.com',
      );
      expect(
        (await repository.recent(query: 'com.example.browser')).single.id,
        isNotNull,
      );
      // message 里的中文标记也能命中；这里顺带覆盖 `LIKE` 对中文的行为。
      expect(
        (await repository.recent(query: '覆写')).single.queryName,
        'rewrite-chinese.example',
      );
    });

    test('DnsLogRow.status 与 SQL 分档一致', () async {
      final all = await DnsQueryRepository(db).recent();
      for (final status in RequestStatus.values) {
        if (status == RequestStatus.all) continue;
        final bySql = {
          for (final row in await DnsQueryRepository(db).recent(
            status: status,
          ))
            row.id,
        };
        final byReader = {
          for (final row in all)
            if (row.status == status) row.id,
        };
        expect(bySql, byReader, reason: '${status.label} 的 SQL 与 Dart 判定不一致');
      }
    });

    test('DnsLogMessage 拆解 app / resolved / blocked_by / error / elapsed', () {
      final parsed = DnsLogMessage.parse(
        'app=com.example.app, resolved=1.1.1.1, blocked_by=firewall:ads, '
        'error=boom, elapsed=42ms',
      );

      expect(parsed.app, 'com.example.app');
      expect(parsed.resolved, '1.1.1.1');
      expect(parsed.blockedBy, 'firewall:ads');
      expect(parsed.error, 'boom');
      expect(parsed.elapsedMs, 42);
    });

    test('DnsLogMessage 对空值 / 缺失字段容错', () {
      expect(DnsLogMessage.parse(null).elapsedMs, isNull);
      expect(DnsLogMessage.parse('').app, isNull);
      // 没有 `=` 的 token 被丢弃，而不是当成 key 塞进去。
      expect(DnsLogMessage.parse('garbage, app=x').app, 'x');
      // 值里带 `=` 时按第一个 `=` 切分。
      expect(DnsLogMessage.parse('error=a=b').error, 'a=b');
      // 非数字的 elapsed 不应该把解析搞崩。
      expect(DnsLogMessage.parse('elapsed=fast').elapsedMs, isNull);
    });
  });

  group('app_traffic_daily', () {
    setUp(() async {
      // 总量刻意不相等：`com.a` 当天 100、`com.b` 120。若两行总量相同，
      // `ORDER BY (tx_bytes + rx_bytes) DESC` 就是并列，返回顺序不保证，
      // 断言排序的用例会变成随机通过/失败。
      await insertTraffic('2026-10-19', 'com.a', tx: 10, rx: 90, appName: '甲');
      await insertTraffic('2026-10-19', 'com.b', tx: 70, rx: 50, appName: '乙');
      await insertTraffic('2026-10-20', 'com.a', tx: 20, rx: 80, appName: '甲');
      await insertTraffic('2026-10-18', 'com.c', tx: 1, rx: 9, appName: '丙');
    });

    test('byDate 按总量降序', () async {
      final rows = await AppTrafficRepository(db).byDate('2026-10-19');

      expect(rows.map((row) => row.packageName), ['com.b', 'com.a']);
      expect(rows.first.totalBytes, 120);
      expect(rows.last.rxBytes, 90);
    });

    test('dateRange 按包名求和并取最早日期', () async {
      final rows = await AppTrafficRepository(
        db,
      ).dateRange('2026-10-19', '2026-10-20');

      expect(rows, hasLength(2));
      final a = rows.firstWhere((row) => row.packageName == 'com.a');
      expect(a.txBytes, 30, reason: '两天相加');
      expect(a.rxBytes, 170);
      expect(a.totalBytes, 200);
      expect(a.date, '2026-10-19', reason: '旧版 min(date)');
      expect(a.appName, '甲');
      // `com.b` 只有一天（120），`com.a` 两天合计 200，故 a 排在前面。
      expect(rows.first.packageName, 'com.a');
    });

    test('dateRange 的边界包含首尾两天', () async {
      final onlyFirst = await AppTrafficRepository(
        db,
      ).dateRange('2026-10-18', '2026-10-18');
      expect(onlyFirst.single.packageName, 'com.c');
    });

    test('allHistory 汇总全部日期', () async {
      final rows = await AppTrafficRepository(db).allHistory();

      expect(rows, hasLength(3));
      expect(rows.first.packageName, 'com.a');
      expect(rows.first.totalBytes, 200);
      expect(rows.first.date, '2026-10-19');
    });

    test('shareOf 对零总量返回 0 而不是除零', () {
      const row = AppTrafficDaily(
        date: '2026-10-20',
        packageName: 'com.a',
        appName: '甲',
        txBytes: 1,
        rxBytes: 1,
        updatedAt: 0,
      );
      expect(row.shareOf(0), 0);
      expect(row.shareOf(4), 0.5);
    });

    test('today 用本地时区的 yyyy-MM-dd', () async {
      final key = AppTrafficRepository.todayKey();
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key), isTrue);

      await insertTraffic(key, 'com.today', tx: 5, rx: 5, appName: '今');
      final rows = await AppTrafficRepository(db).today();
      expect(rows.map((row) => row.packageName), contains('com.today'));
    });

    test('dateKey 补零', () {
      expect(AppTrafficRepository.dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('空库', () {
    test('三个仓储的空查询返回空列表而不是抛错', () async {
      expect(await HttpRequestRepository(db).recent(), isEmpty);
      expect(
        await HttpRequestRepository(db).dailyStats(
          since: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        isA<HttpRequestDailyStats>().having((stats) => stats.total, 'total', 0),
      );
      expect(await DnsQueryRepository(db).recent(), isEmpty);
      for (final status in RequestStatus.values) {
        expect(await DnsQueryRepository(db).recent(status: status), isEmpty);
        expect(await HttpRequestRepository(db).recent(status: status), isEmpty);
      }
      expect(await AppTrafficRepository(db).byDate('2026-10-20'), isEmpty);
      expect(await AppTrafficRepository(db).allHistory(), isEmpty);
      expect(
        await AppTrafficRepository(db).dateRange('2026-01-01', '2026-12-31'),
        isEmpty,
      );
    });
  });
}

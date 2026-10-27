// Dashboard numbers come from the log tables the native writers keep
// filling; these pin the 1.4.3 counting rules behind every card.

import 'package:diting/data/dashboard_models.dart';
import 'package:diting/data/db/dns_log_repository.dart';
import 'package:diting/data/db/http_request_repository.dart';
import 'package:diting/data/db/race_log_repository.dart';
import 'package:diting/data/log_dashboard_models.dart';
import 'package:diting/data/log_dashboard_rows.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/data/site_latency_categories.dart';
import 'package:diting/data/site_latency_targets.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/log_race_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('行映射与速率序列', _realDataMapping);
  group('日志统计口径', _dnsLogStats);
  group('竞速统计', _raceStats);
  group('站点目录', _siteLatencyCatalog);
}

void _realDataMapping() {
  group('行映射：DNS', () {
    test('连接行按 queryType / 前缀 / message 三种线索识别', () {
      expect(isConnectionLog(queryType: 0, queryName: 'anything'), isTrue);
      expect(
        isConnectionLog(queryType: 1, queryName: 'TCP 1.1.1.1:443'),
        isTrue,
      );
      expect(
        isConnectionLog(queryType: 1, queryName: 'UDP 1.1.1.1:53'),
        isTrue,
      );
      expect(
        isConnectionLog(
          queryType: 1,
          queryName: 'example.com',
          message: 'blocked_by=connection',
        ),
        isTrue,
      );
      expect(isConnectionLog(queryType: 1, queryName: 'example.com'), isFalse);
    });

    test('结果文案：连接行的 PASSED 是「旁路」，域名查询是「通过」', () {
      expect(dnsResultLabelOf('PASSED', isConnection: true), '旁路');
      expect(dnsResultLabelOf('PASSED', isConnection: false), '通过');
      expect(dnsResultLabelOf('REWRITTEN', isConnection: false), '覆写');
      expect(dnsResultLabelOf('BLOCKED', isConnection: false), '过滤');
      expect(dnsResultLabelOf('ERROR', isConnection: false), '失败');
      // Unknown results render as is; mapping them to passed belongs to the view layer
      expect(
        dnsResultLabelOf('SOMETHING_NEW', isConnection: false),
        'SOMETHING_NEW',
      );
    });

    test('结果档位：覆写归通过、连接归旁路、缓存单列', () {
      expect(
        dnsRowStatusOf('PASSED', isConnection: false, cached: false),
        LogRowStatus.passed,
      );
      expect(
        dnsRowStatusOf('PASSED', isConnection: false, cached: true),
        LogRowStatus.cached,
      );
      expect(
        dnsRowStatusOf('REWRITTEN', isConnection: false, cached: false),
        LogRowStatus.passed,
      );
      expect(
        dnsRowStatusOf('BLOCKED', isConnection: false, cached: false),
        LogRowStatus.filtered,
      );
      expect(
        dnsRowStatusOf('ERROR', isConnection: false, cached: false),
        LogRowStatus.failed,
      );
      expect(
        dnsRowStatusOf('PASSED', isConnection: true, cached: false),
        LogRowStatus.bypassed,
      );
    });

    test('时间戳缺失给 --:--:--，不拿当前时钟冒充', () {
      expect(dashboardClockOf(0), '--:--:--');
      expect(dashboardClockOf(-1), '--:--:--');
      expect(
        dashboardClockOf(DateTime(2026, 1, 2, 3, 4, 5).millisecondsSinceEpoch),
        '03:04:05',
      );
    });
  });

  group('行映射：HTTPS', () {
    test('四档映射与「仅拦截与错误」筛选一致', () {
      expect(httpRowStatusOf('allowed'), LogRowStatus.passed);
      expect(httpRowStatusOf('rewritten'), LogRowStatus.passed);
      expect(httpRowStatusOf('blocked'), LogRowStatus.filtered);
      expect(httpRowStatusOf('invalid'), LogRowStatus.filtered);
      for (final outcome in [
        'passthrough',
        'bypassed',
        'unsupported_protocol',
        'resource_bypass',
      ]) {
        expect(httpRowStatusOf(outcome), LogRowStatus.bypassed);
      }
      expect(httpRowStatusOf('whatever'), LogRowStatus.failed);

      expect(httpOutcomeIsPassed('allowed'), isTrue);
      expect(httpOutcomeIsPassed('passthrough'), isFalse);
      expect(httpOutcomeIsPassed('blocked'), isFalse);
    });

    test('authority 为空时显示「未取得 authority」，不渲染空行', () {
      final row = logRecentRequestOfHttp(
        HttpRequestRecord(
          id: 1,
          timestamp: DateTime(2026, 10, 20, 13, 41).millisecondsSinceEpoch,
          packageName: 'com.example.ads',
          protocol: 'http/1.1',
          outcome: 'blocked',
          matchedRule: 'RULE-SET,广告拦截',
        ),
      );
      expect(row.name, '未取得 authority');
      expect(row.source, 'HTTPS');
      expect(row.resultLabel, '过滤');
      expect(row.meta, 'http/1.1 · com.example.ads · RULE-SET,广告拦截');
    });
  });

  group('速率序列（SpeedSeries）', () {
    test('数据源缺失与「采样到 0」互不混淆', () {
      const series = SpeedSeries(
        samples: [SpeedSample(up: 0, down: 0)],
        revision: 3,
        source: SpeedSource.noNativeChannel,
      );
      expect(series.unsupported, isTrue);
      expect(series.last.isZero, isTrue);
      expect(series.hasTraffic, isFalse);
    });
  });

  group('订阅自动更新设置（数据集 prefs）', () {
    test('默认关闭、24 小时，越界值回落到默认', () {
      final store = MemoryLegacyPrefsStore();
      final settings = LegacySettings(store);
      expect(settings.subscriptionAutoUpdateEnabled, isFalse);
      expect(
        settings.subscriptionAutoUpdateIntervalHours,
        LegacySettings.defaultSubscriptionAutoUpdateIntervalHours,
      );

      store.putInt(
        'dns_vpn_prefs',
        LegacySettings.subscriptionAutoUpdateIntervalKey,
        500,
      );
      expect(
        LegacySettings(store).subscriptionAutoUpdateIntervalHours,
        LegacySettings.defaultSubscriptionAutoUpdateIntervalHours,
      );
    });

    test('写入口 clamp 到 1–168，且落在数据集容器里', () {
      final store = MemoryLegacyPrefsStore();
      final settings = LegacySettings(store);
      settings.setSubscriptionAutoUpdateIntervalHours(0);
      expect(
        store.read(
          'dns_vpn_prefs',
          LegacySettings.subscriptionAutoUpdateIntervalKey,
        ),
        1,
      );
      settings.setSubscriptionAutoUpdateIntervalHours(9999);
      expect(
        store.read(
          'dns_vpn_prefs',
          LegacySettings.subscriptionAutoUpdateIntervalKey,
        ),
        168,
      );
      settings.setSubscriptionAutoUpdateEnabled(true);
      expect(
        store.read(
          'dns_vpn_prefs',
          LegacySettings.subscriptionAutoUpdateEnabledKey,
        ),
        isTrue,
      );
      expect(settings.forExpress().subscriptionAutoUpdateEnabled, isFalse);
    });
  });
}

/// Pins the dashboard header: one day window for every number, hit ratio hits / (hits + misses)

void _dnsLogStats() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    // Subset of `dns_log` that `DnsLogRepository.dailyStats` reads
    await db.execute(
      'CREATE TABLE dns_log (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, '
      'timestamp INTEGER NOT NULL, queryName TEXT NOT NULL, '
      'queryType INTEGER NOT NULL, result TEXT NOT NULL, message TEXT, '
      'cached INTEGER NOT NULL)',
    );
  });

  tearDown(() => db.close());

  Future<void> insert({
    required String result,
    required bool cached,
    String? message,
    int? timestamp,
  }) => db.insert('dns_log', {
    'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
    'queryName': 'example.com',
    'queryType': 1,
    'result': result,
    'message': message,
    'cached': cached ? 1 : 0,
  });

  group('elapsedMsOf', () {
    test('从 message 里取出毫秒数', () {
      expect(DnsLogRepository.elapsedMsOf('app=x, elapsed=42ms'), 42);
      expect(DnsLogRepository.elapsedMsOf('elapsed=7ms'), 7);
    });
  });

  group('dailyStats', () {
    test('四个桶互斥，缓存在放行桶内单独计数', () async {
      await insert(result: 'PASSED', cached: false, message: 'elapsed=10ms');
      await insert(result: 'PASSED', cached: true, message: 'elapsed=2ms');
      await insert(result: 'REWRITTEN', cached: false, message: 'elapsed=1ms');
      await insert(result: 'BLOCKED', cached: false);
      await insert(result: 'ERROR', cached: false, message: 'elapsed=900ms');

      final stats = await DnsLogRepository(db).dailyStats();
      expect(stats.total, 5);
      expect(stats.passed, 3, reason: 'PASSED + REWRITTEN');
      expect(stats.blocked, 1);
      expect(stats.error, 1);
      expect(stats.cached, 1);
    });

    test('命中率分母含上游失败，不含被规则拦截', () async {
      // 1 hit + 1 miss + 1 upstream failure -> hits / (hits + misses).
      await insert(result: 'PASSED', cached: true);
      await insert(result: 'PASSED', cached: false);
      await insert(result: 'ERROR', cached: false);
      // Blocked rows never reach the cache, so they stay out of the denominator.
      await insert(result: 'BLOCKED', cached: false);

      final stats = await DnsLogRepository(db).dailyStats();
      expect(stats.cacheHitRate, closeTo(1 / 3, 1e-9));
    });

    test('平均延迟只用当天带计时的行，且与顶栏同窗口', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await insert(result: 'PASSED', cached: false, message: 'elapsed=10ms');
      await insert(result: 'PASSED', cached: false, message: 'elapsed=30ms');
      await insert(result: 'BLOCKED', cached: false);
      // Yesterday's row must not enter today's average or count.
      await insert(
        result: 'PASSED',
        cached: false,
        message: 'elapsed=5000ms',
        timestamp: now - const Duration(days: 2).inMilliseconds,
      );

      final stats = await DnsLogRepository(db).dailyStats();
      expect(stats.total, 3);
      expect(stats.latencySamples, 2);
      expect(stats.averageLatencyMs, 20);
    });

    test('空库时为全零且 latencySamples 为 0（UI 显示破折号）', () async {
      final stats = await DnsLogRepository(db).dailyStats();
      expect(stats.total, 0);
      expect(stats.cacheHitRate, 0);
      expect(stats.averageLatencyMs, 0);
      expect(stats.latencySamples, 0);
      expect(const DnsLogDailyStats.empty().latencySamples, 0);
    });
  });
}

/// Pins 1.4.3 `RaceLogDao.strategyStats`: `primaryWins` needs the primary to win and succeed,
/// `selectedSuccesses` excludes fallback rescues, and `since` filters on `timestamp`

void _raceStats() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE dns_race_log ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, '
      'timestamp INTEGER NOT NULL, queryName TEXT NOT NULL, '
      'strategy TEXT NOT NULL, providerCount INTEGER NOT NULL, '
      'success INTEGER NOT NULL, elapsedMs INTEGER NOT NULL, '
      'selectedProviderId TEXT, selectedElapsedMs INTEGER, '
      'winnerProviderId TEXT, winnerElapsedMs INTEGER, '
      'fallbackUsed INTEGER NOT NULL DEFAULT 0, '
      'fallbackSuccess INTEGER NOT NULL DEFAULT 0, message TEXT)',
    );
  });

  tearDown(() => db.close());

  int now() => DateTime.now().millisecondsSinceEpoch;

  Future<void> insert({
    required String strategy,
    required bool success,
    String? selected,
    String? winner,
    int elapsedMs = 20,
    bool fallbackUsed = false,
    bool fallbackSuccess = false,
    int? timestamp,
  }) => db.insert('dns_race_log', {
    'timestamp': timestamp ?? now(),
    'queryName': 'x.example',
    'strategy': strategy,
    'providerCount': 2,
    'success': success ? 1 : 0,
    'elapsedMs': elapsedMs,
    'selectedProviderId': selected,
    'selectedElapsedMs': selected == null ? null : elapsedMs,
    'winnerProviderId': winner,
    'winnerElapsedMs': winner == null ? null : elapsedMs,
    'fallbackUsed': fallbackUsed ? 1 : 0,
    'fallbackSuccess': fallbackSuccess ? 1 : 0,
  });

  group('strategyStats', () {
    test('按策略分组，primaryWins 只算「首选即胜出且成功」', () async {
      await insert(
        strategy: 'smart_prediction',
        success: true,
        selected: 'a',
        winner: 'a',
      );
      await insert(
        strategy: 'smart_prediction',
        success: true,
        selected: 'a',
        winner: 'b',
        fallbackUsed: true,
        fallbackSuccess: true,
      );
      await insert(strategy: 'smart_prediction', success: false, selected: 'a');
      await insert(strategy: 'parallel_race', success: true, winner: 'c');

      final rows = await RaceLogRepository(db).strategyStats();
      final smart = rows.firstWhere((r) => r.strategy == 'smart_prediction');
      expect(smart.requests, 3);
      expect(smart.successes, 2);
      expect(smart.failures, 1);
      expect(smart.primaryWins, 1, reason: '只有首选即胜出的那一次算');
      expect(smart.fallbackUses, 1);
      expect(smart.primaryWinRate, closeTo(1 / 3, 1e-9));

      final parallel = rows.firstWhere((r) => r.strategy == 'parallel_race');
      expect(parallel.primaryWins, 0);
      expect(parallel.successRate, 1);
    });

    test('窗口过滤：更早的行不进今日聚合', () async {
      final yesterday = now() - const Duration(days: 1).inMilliseconds;
      await insert(
        strategy: 'smart_prediction',
        success: true,
        selected: 'a',
        winner: 'a',
        timestamp: yesterday,
      );
      final since = DateTime.now().subtract(const Duration(hours: 1));
      final rows = await RaceLogRepository(db)
          .strategyStats(since: since.millisecondsSinceEpoch);
      expect(rows, isEmpty);
    });
  });

  group('smartSelectionStats', () {
    test('selectedSuccesses 排除兜底救回，且只统计智能选择', () async {
      await insert(
        strategy: 'smart_prediction',
        success: true,
        selected: 'a',
        winner: 'a',
      );
      await insert(
        strategy: 'smart_prediction',
        success: true,
        selected: 'a',
        winner: 'b',
        fallbackUsed: true,
        fallbackSuccess: true,
      );
      await insert(
        strategy: 'primary_backup',
        success: true,
        selected: 'a',
        winner: 'a',
      );

      final rows = await RaceLogRepository(db).smartSelectionStats();
      expect(rows, hasLength(1));
      final a = rows.single;
      expect(a.providerId, 'a');
      expect(a.selectedCount, 2);
      expect(a.selectedSuccesses, 1);
      expect(a.selectedSuccessRate, closeTo(0.5, 1e-9));
    });
  });

  group('raceStrategyLabel', () {
    test('历史别名与落盘值都翻成中文，未知值原样返回', () {
      expect(raceStrategyLabel('brute_force_parallel'), '最快响应');
      expect(raceStrategyLabel('race'), '最快响应');
      expect(raceStrategyLabel('parallel_race'), '最快响应');
      expect(raceStrategyLabel('smart_prediction'), '智能选择');
      expect(raceStrategyLabel('prediction'), '智能选择');
      expect(raceStrategyLabel('primary_backup'), '依次尝试');
      expect(raceStrategyLabel('single'), '单服务商');
      expect(raceStrategyLabel('weird'), 'weird');
    });
  });
}

/// Guards real-data wiring in the database: no bucket counted as passed, no demo fallback

void _siteLatencyCatalog() {
  test('id 与 host 都不重复', () {
    final ids = [for (final target in siteLatencyTargets) target.id];
    final hosts = [for (final target in siteLatencyTargets) target.host];
    expect(ids.toSet().length, ids.length);
    expect(hosts.toSet().length, hosts.length);
  });

  test('站点大幅扩充且每个分类都有站点', () {
    expect(siteLatencyTargets.length, greaterThanOrEqualTo(44));
    for (final category in SiteCategory.values) {
      expect(
        siteLatencyInCategory(category),
        isNotEmpty,
        reason: '${category.label} 分类为空',
      );
    }
    final grouped = [
      for (final category in SiteCategory.values)
        ...siteLatencyInCategory(category),
    ];
    expect(grouped.length, siteLatencyTargets.length);
  });

  test('默认四个站点都在目录里', () {
    for (final id in defaultDashboardSiteIds) {
      expect(siteLatencyById(id), isNotNull, reason: id);
    }
    expect(defaultDashboardSiteIds.length, dashboardSiteCount);
  });

  test('解析出的仪表盘站点总是四个且不重复', () {
    expect(resolveDashboardSites(const []), hasLength(dashboardSiteCount));
    expect(
      resolveDashboardSites(const ['no_such_site']),
      hasLength(dashboardSiteCount),
    );
    final picked = resolveDashboardSites(const [
      'github',
      'github',
      'steam',
      'netflix',
      'spotify',
    ]);
    expect(picked.map((target) => target.id), [
      'github',
      'steam',
      'netflix',
      'spotify',
    ]);
  });
}

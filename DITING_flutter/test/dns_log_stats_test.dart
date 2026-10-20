import 'package:diting/data/db/dns_log_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pins the dashboard header contract: every number must come from the same
/// day window, and the hit ratio denominator must match the Go engine's
/// `hitRatio` = hits / (hits + misses) rather than "passed rows only".
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    // Subset of `dns_log` that the dashboard reads: result/cached/message are
    // the only columns `DnsLogRepository.dailyStats` touches.
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

    test('没有计时或非法内容时返回 null，不伪造 0ms', () {
      expect(DnsLogRepository.elapsedMsOf(null), isNull);
      expect(DnsLogRepository.elapsedMsOf(''), isNull);
      expect(DnsLogRepository.elapsedMsOf('blocked_by=important'), isNull);
      expect(DnsLogRepository.elapsedMsOf('elapsed=abcms'), isNull);
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
      // 1 hit + 1 miss + 1 upstream failure → 引擎口径 hits/(hits+misses)。
      await insert(result: 'PASSED', cached: true);
      await insert(result: 'PASSED', cached: false);
      await insert(result: 'ERROR', cached: false);
      // 被规则拦截的行从不查缓存，不能进分母。
      await insert(result: 'BLOCKED', cached: false);

      final stats = await DnsLogRepository(db).dailyStats();
      expect(stats.cacheHitRate, closeTo(1 / 3, 1e-9));
    });

    test('平均延迟只用当天带计时的行，且与顶栏同窗口', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await insert(result: 'PASSED', cached: false, message: 'elapsed=10ms');
      await insert(result: 'PASSED', cached: false, message: 'elapsed=30ms');
      await insert(result: 'BLOCKED', cached: false);
      // 昨天的一行：不得进入今日平均，也不得进入计数。
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

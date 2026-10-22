import 'package:diting/data/db/race_log_repository.dart';
import 'package:diting/state/log_race_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pins the two race-stat groups the page gained:「策略概览」与「智能选择首选」。
///
/// 这两组的 SQL 逐字移植自 1.4.3 `RaceLogDao.strategyStats` /
/// `smartSelectionStats`。回归点不是「能不能查」，而是三个口径：
/// 1. `primaryWins` 必须是「首选即胜出且成功」，不是「只要成功」；
/// 2. `selectedSuccesses` 必须排除兜底救回（`fallbackUsed = 1`）的查询；
/// 3. 时间窗口（`since`）要按 `timestamp` 过滤，否则「今日」档会混进历史行。
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    // 只建本文件用到的列：策略聚合只需要这几项（与 1.4.3 `dns_race_log` 同名）。
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
      // 智能选择：一次首选命中（首选 = 胜出，成功）。
      await insert(
        strategy: 'smart_prediction',
        success: true,
        selected: 'a',
        winner: 'a',
      );
      // 智能选择：一次兜底（首选 a 失败，胜出 b）——不计 primaryWin。
      await insert(
        strategy: 'smart_prediction',
        success: true,
        selected: 'a',
        winner: 'b',
        fallbackUsed: true,
        fallbackSuccess: true,
      );
      // 智能选择：一次失败。
      await insert(strategy: 'smart_prediction', success: false, selected: 'a');
      // 并行竞速：没有 selectedProviderId，primaryWins 必为 0。
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
      final rows = await RaceLogRepository(
        db,
      ).strategyStats(since: since.millisecondsSinceEpoch);
      expect(rows, isEmpty);
    });
  });

  group('smartSelectionStats', () {
    test('selectedSuccesses 排除兜底救回，且只统计智能选择', () async {
      // 首选即胜出：计入 selectedSuccesses。
      await insert(
        strategy: 'smart_prediction',
        success: true,
        selected: 'a',
        winner: 'a',
      );
      // 兜底救回：selectedCount +1，但 selectedSuccesses 不加。
      await insert(
        strategy: 'smart_prediction',
        success: true,
        selected: 'a',
        winner: 'b',
        fallbackUsed: true,
        fallbackSuccess: true,
      );
      // 别的策略即便有 selectedProviderId 也不进这张表。
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

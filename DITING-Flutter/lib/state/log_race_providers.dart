/// 日志下钻页里**竞速**这一块的数据层（真实表 `dns_race_log`）。
///
/// 从 `log_dashboard_providers.dart` 拆出来：那个文件同时承载 Bootstrap、缓存、
/// 订阅拦截三块，加上竞速的四组聚合后逼近 600 行上限。竞速的模型、窗口与聚合
/// 自成一域（旧版 `RaceStatsViewModel` + `RaceLogRepository`），单独成文件后
/// 两边都读得清。跨文件复用的只有 `activeLogDatabaseProvider` /
/// `dnsLogRevisionProvider`（`log_providers.dart`）与提供者目录。
library;

import 'package:diting/data/db/race_log_repository.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/state/log_dashboard_providers.dart' show LogStatsRange;
import 'package:diting/state/log_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// 页面上当前选中的竞速窗口。
class RaceStatsRangeNotifier extends Notifier<LogStatsRange> {
  @override
  LogStatsRange build() => LogStatsRange.today;

  void select(LogStatsRange range) {
    if (state == range) return;
    state = range;
  }
}

final raceStatsRangeProvider =
    NotifierProvider<RaceStatsRangeNotifier, LogStatsRange>(
      RaceStatsRangeNotifier.new,
    );

/// 竞速策略落盘值 → 中文显示名（旧版 `RaceModeStrategy`）。
///
/// 旧版 `RaceModeStrategy.fromStorageValue` 还认几个历史别名（`race` /
/// `prediction`），Go 引擎写库前已归一成三个落盘值，但历史库里可能留着别名，
/// 这里一并认掉，避免页面上出现一行裸英文。
String raceStrategyLabel(String strategy) => switch (strategy) {
  'parallel_race' || 'race' || 'brute_force_parallel' => '最快响应',
  'smart_prediction' || 'prediction' => '智能选择',
  'primary_backup' => '依次尝试',
  'single' => '单服务商',
  _ => strategy,
};

// ---------------------------------------------------------------------------
// 下钻页：竞速（真实表 dns_race_log）
// ---------------------------------------------------------------------------

/// 竞速统计（按窗口聚合）。
///
/// 为什么不用 `raceRankingProvider`：那个 provider 对整张表聚合，而竞速页有
/// 「今日 / 7 天 / 全部」三档选择器——把它直接摆上去会让选择器点了没反应。
/// 这里沿用 `RaceLogRepository` 的同一条 SQL，只多一个 `timestamp >= ?`。
/// 一条按策略聚合的展示行（旧版 `RaceStrategyStats` 的展示形态）。
class RaceStrategyDisplay {
  const RaceStrategyDisplay({
    required this.strategy,
    required this.label,
    required this.requests,
    required this.successes,
    required this.failures,
    required this.averageElapsedMs,
    required this.fallbackUses,
    required this.primaryWins,
  });

  /// 落盘值（`brute_force_parallel` / `smart_prediction` / `primary_backup` …）。
  final String strategy;

  /// 中文显示名；未知策略回落到落盘值本身，不丢行。
  final String label;
  final int requests;
  final int successes;
  final int failures;
  final double averageElapsedMs;

  /// 走了兜底（换下一个服务商）的次数与其中成功次数。
  final int fallbackUses;
  final int primaryWins;

  double get successRate => requests == 0 ? 0 : successes / requests;

  /// 首选命中率：只有智能选择有分母意义，其余策略为 0。
  double get primaryWinRate => requests == 0 ? 0 : primaryWins / requests;
}

/// 一条智能选择首选服务商的展示行。
class RaceSmartSelectionDisplay {
  const RaceSmartSelectionDisplay({
    required this.name,
    required this.selectedCount,
    required this.selectedSuccesses,
    required this.averageElapsedMs,
  });

  final String name;
  final int selectedCount;
  final int selectedSuccesses;
  final double averageElapsedMs;

  double get selectedSuccessRate =>
      selectedCount == 0 ? 0 : selectedSuccesses / selectedCount;
}

class RaceStatsSnapshot {
  const RaceStatsSnapshot({
    required this.summary,
    required this.entries,
    this.strategyStats = const [],
    this.smartSelections = const [],
  });

  const RaceStatsSnapshot.empty()
    : summary = const RaceLogSummary.empty(),
      entries = const [],
      strategyStats = const [],
      smartSelections = const [];

  final RaceLogSummary summary;

  /// 服务商胜出排行，已把 provider id 换成显示名。
  final List<({String name, int wins, int averageLatencyMs})> entries;

  /// 策略概览（旧版「策略概览」组）。
  final List<RaceStrategyDisplay> strategyStats;

  /// 智能选择首选（旧版「智能选择首选」组），已换成显示名。
  final List<RaceSmartSelectionDisplay> smartSelections;
}

final raceStatsProvider = FutureProvider<RaceStatsSnapshot>((ref) async {
  ref.watch(dnsLogRevisionProvider);
  final range = ref.watch(raceStatsRangeProvider);
  final db = await ref.watch(activeLogDatabaseProvider.future);
  if (db == null) return const RaceStatsSnapshot.empty();
  final since = range.startOf(DateTime.now())?.millisecondsSinceEpoch;

  final summaryRows = await db.rawQuery(
    'SELECT COUNT(*) AS requests, '
    'COALESCE(SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END), 0) AS successes, '
    'COALESCE(SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END), 0) AS failures, '
    'AVG(elapsedMs) AS avgElapsed FROM dns_race_log'
    '${since == null ? '' : ' WHERE timestamp >= ?'}',
    [?since],
  );
  final summaryRow = summaryRows.isEmpty ? null : summaryRows.first;
  final summary = RaceLogSummary(
    requests: (summaryRow?['requests'] as num?)?.toInt() ?? 0,
    successes: (summaryRow?['successes'] as num?)?.toInt() ?? 0,
    failures: (summaryRow?['failures'] as num?)?.toInt() ?? 0,
    averageLatencyMs: ((summaryRow?['avgElapsed'] as num?) ?? 0).round(),
  );

  final rankingRows = await db.rawQuery(
    'SELECT winnerProviderId AS providerId, COUNT(*) AS wins, '
    'AVG(CASE WHEN winnerElapsedMs IS NOT NULL THEN winnerElapsedMs END) '
    'AS avgElapsed FROM dns_race_log '
    'WHERE success = 1 AND winnerProviderId IS NOT NULL'
    '${since == null ? '' : ' AND timestamp >= ?'} '
    'GROUP BY winnerProviderId ORDER BY wins DESC, avgElapsed ASC LIMIT 20',
    [?since],
  );

  // 名称解析与 `raceRankingProvider` 用同一份目录（预设 + 用户自定义），
  // 否则同一服务商在两个页面上会显示成两个名字。
  final settings = ref.watch(legacySettingsProvider);
  final names = {
    for (final provider in [
      ...defaultDnsProviders,
      ...parseUserProviders(settings.userProvidersJson),
    ])
      provider.id: provider.name,
  };

  // 策略概览 / 智能选择首选依赖 `fallbackUsed` / `selectedProviderId` 等列。
  // 真正的 1.4.3 库一定有，但更旧的库或残缺库可能没有；这时不能整页报错——
  // 「概览」与「胜出服务商」用的列一直存在，仍应正常显示，只把这两组留空。
  final repository = RaceLogRepository(db);
  var strategyRows = const <RaceStrategyStatRow>[];
  var smartRows = const <RaceSmartSelectionRow>[];
  try {
    strategyRows = await repository.strategyStats(since: since);
    smartRows = await repository.smartSelectionStats(since: since);
  } on DatabaseException catch (error) {
    if (!error.toString().contains('no such column')) rethrow;
  }

  return RaceStatsSnapshot(
    summary: summary,
    entries: [
      for (final row in rankingRows)
        if ((row['providerId'] as String?)?.isNotEmpty == true)
          (
            name: names[row['providerId']] ?? row['providerId']! as String,
            wins: (row['wins'] as num?)?.toInt() ?? 0,
            averageLatencyMs: ((row['avgElapsed'] as num?) ?? 0).round(),
          ),
    ],
    strategyStats: [
      for (final row in strategyRows)
        RaceStrategyDisplay(
          strategy: row.strategy,
          label: raceStrategyLabel(row.strategy),
          requests: row.requests,
          successes: row.successes,
          failures: row.failures,
          averageElapsedMs: row.averageElapsedMs,
          fallbackUses: row.fallbackUses,
          primaryWins: row.primaryWins,
        ),
    ],
    smartSelections: [
      for (final row in smartRows)
        RaceSmartSelectionDisplay(
          name: names[row.providerId] ?? row.providerId,
          selectedCount: row.selectedCount,
          selectedSuccesses: row.selectedSuccesses,
          averageElapsedMs: row.averageElapsedMs,
        ),
    ],
  );
});
/// 日志仪表盘的数据层。
///
/// 两类数据刻意分开：
/// - **概览块**（首页 / 日志页的统计卡）用 [logDashboardProvider] 的固定演示值：
///   它们的形状要与旧版 `ModernLogDashboardModeViews.kt` 逐块对齐，而真实表的
///   密度不足以撑满布局（全新安装时几乎全空），演示值让「有数据长什么样」可见；
/// - **四个下钻页**读真实表：竞速 `dns_race_log`、Bootstrap `bootstrap_log`、
///   缓存 `dns_cache`（`dnsCacheProvider`）、订阅拦截 `dns_log` /
///   `http_request_log` 的 `blockSubscriptionId` 列。库空 → 空状态，缺列 →
///   空状态 + 说明，绝不拿演示值冒充。
library;

import 'package:diting/data/db/bootstrap_log_repository.dart';
import 'package:diting/data/db/race_log_repository.dart';
import 'package:diting/data/mock_log_dashboard.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/state/log_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

// ---------------------------------------------------------------------------
// 概览块（演示值）
// ---------------------------------------------------------------------------

/// 一次渲染所需的全部概览数据。
///
/// 打包成一个不可变对象而不是十几个 provider：这些数字来自旧版**同一次**
/// `buildDashboardState()` 扫描，分成十几个 provider 后各自重建，
/// 「今日请求」与「今日流量结构」就会短暂不一致。
class LogDashboardSnapshot {
  const LogDashboardSnapshot({
    required this.breakdown,
    required this.race,
    required this.bootstrap,
    required this.offMode,
    required this.recentRequests,
    required this.cacheHotspots,
    required this.raceWinners,
    required this.bootstrapIps,
    required this.subscriptionBlocks,
  });

  const LogDashboardSnapshot.mock()
    : breakdown = mockLogTrafficBreakdown,
      race = mockLogRaceSummary,
      bootstrap = mockLogBootstrapSummary,
      offMode = mockLogOffModeStats,
      recentRequests = mockRecentRequests,
      cacheHotspots = mockCacheHotspots,
      raceWinners = mockRaceWinners,
      bootstrapIps = mockBootstrapIps,
      subscriptionBlocks = mockSubscriptionBlocks;

  final LogTrafficBreakdown breakdown;
  final LogRaceSummary race;
  final LogBootstrapSummary bootstrap;
  final LogOffModeStats offMode;
  final List<LogRecentRequest> recentRequests;
  final List<LogCacheHotspot> cacheHotspots;
  final List<LogRaceWinner> raceWinners;
  final List<LogBootstrapIp> bootstrapIps;
  final List<LogSubscriptionBlock> subscriptionBlocks;

  /// 「重点记录」四格：重点记录 / 过滤拦截 / 异常失败 / 旁路直连。
  ///
  /// 旧版 `FilteredModeDashboard` 里 `重点记录` 的取自 `stats.total`，
  /// 而 `total` 在 filtered 模式下已经只含拦截与错误（Demo 数据里
  /// `total` 仍是全部，因此这里按「过滤 + 失败」求和，与卡片语义一致）。
  int get highlightedTotal => breakdown.blocked + breakdown.error;
}

/// 概览数据。演示值：形状固定、数值可复现。
final logDashboardProvider = Provider<LogDashboardSnapshot>(
  (ref) => const LogDashboardSnapshot.mock(),
);

// ---------------------------------------------------------------------------
// 下钻页：时间范围
// ---------------------------------------------------------------------------

/// 竞速 / Bootstrap 页的时间范围（旧版 `RaceStatsRange` 与
/// `BootstrapStatsRange` 同形：今日 / 7 天 / 全部）。
enum LogStatsRange {
  today('今日'),
  sevenDays('7 天'),
  all('全部');

  const LogStatsRange(this.label);

  final String label;

  /// 窗口起点。`null` 表示不设下限（全部）。
  DateTime? startOf(DateTime now) {
    final dayStart = DateTime(now.year, now.month, now.day);
    return switch (this) {
      LogStatsRange.today => dayStart,
      LogStatsRange.sevenDays => dayStart.subtract(const Duration(days: 6)),
      LogStatsRange.all => null,
    };
  }
}

/// 订阅拦截页的时间范围（旧版 `SubscriptionInterceptionStatsRange`：今日 /
/// 近 7 天 / 全部，文案与旧版逐字一致）。
enum SubscriptionStatsRange {
  today('今日'),
  sevenDays('近 7 天'),
  all('全部');

  const SubscriptionStatsRange(this.label);

  final String label;

  DateTime? startOf(DateTime now) {
    final dayStart = DateTime(now.year, now.month, now.day);
    return switch (this) {
      SubscriptionStatsRange.today => dayStart,
      SubscriptionStatsRange.sevenDays => dayStart.subtract(
        const Duration(days: 6),
      ),
      SubscriptionStatsRange.all => null,
    };
  }
}

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

/// 页面上当前选中的 Bootstrap 窗口。
class BootstrapStatsRangeNotifier extends Notifier<LogStatsRange> {
  @override
  LogStatsRange build() => LogStatsRange.today;

  void select(LogStatsRange range) {
    if (state == range) return;
    state = range;
  }
}

final bootstrapStatsRangeProvider =
    NotifierProvider<BootstrapStatsRangeNotifier, LogStatsRange>(
      BootstrapStatsRangeNotifier.new,
    );

/// 页面上当前选中的订阅拦截窗口。
class SubscriptionStatsRangeNotifier extends Notifier<SubscriptionStatsRange> {
  @override
  SubscriptionStatsRange build() => SubscriptionStatsRange.today;

  void select(SubscriptionStatsRange range) {
    if (state == range) return;
    state = range;
  }
}

final subscriptionStatsRangeProvider =
    NotifierProvider<SubscriptionStatsRangeNotifier, SubscriptionStatsRange>(
      SubscriptionStatsRangeNotifier.new,
    );

// ---------------------------------------------------------------------------
// 下钻页：缓存表的「最后命中」
// ---------------------------------------------------------------------------

/// `dns_cache.lastHitAt` 的一列补充查询。
///
/// 为什么不在 `DnsCacheRepository` 里加：那个文件不是本域的写作用域。这里单独
/// 查一列，条件与 `DnsCacheRepository.entries` 完全一致（`expiresAt > now`），
/// 因此两次查询取到的是同一批行；键是 `domain|queryType`，与列表行一一对应。
///
/// 值为 `null` 表示这一行**从没被命中过**（旧库该列可为 NULL），页面上显示
/// 「尚未命中」，而不是拿 `now` 冒充时间。
final cacheLastHitProvider = FutureProvider<Map<String, int?>>((ref) async {
  ref.watch(dnsLogRevisionProvider);
  final db = await ref.watch(activeLogDatabaseProvider.future);
  if (db == null) return const {};
  final now = DateTime.now().millisecondsSinceEpoch;
  final rows = await db.query(
    'dns_cache',
    columns: ['queryName', 'queryType', 'lastHitAt'],
    where: 'expiresAt > ?',
    whereArgs: [now],
    orderBy: 'hitCount DESC, expiresAt DESC',
    limit: 200,
  );
  return {
    for (final row in rows)
      '${row['queryName'] as String? ?? ''}|'
              '${(row['queryType'] as num?)?.toInt() ?? 1}':
          (row['lastHitAt'] as num?)?.toInt(),
  };
});

// ---------------------------------------------------------------------------
// 下钻页：竞速（真实表 dns_race_log）
// ---------------------------------------------------------------------------

/// 竞速统计（按窗口聚合）。
///
/// 为什么不用 `raceRankingProvider`：那个 provider 对整张表聚合，而竞速页有
/// 「今日 / 7 天 / 全部」三档选择器——把它直接摆上去会让选择器点了没反应。
/// 这里沿用 `RaceLogRepository` 的同一条 SQL，只多一个 `timestamp >= ?`。
class RaceStatsSnapshot {
  const RaceStatsSnapshot({required this.summary, required this.entries});

  const RaceStatsSnapshot.empty()
    : summary = const RaceLogSummary.empty(),
      entries = const [];

  final RaceLogSummary summary;

  /// 服务商胜出排行，已把 provider id 换成显示名。
  final List<({String name, int wins, int averageLatencyMs})> entries;
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
  );
});

// ---------------------------------------------------------------------------
// 下钻页：Bootstrap（真实表 bootstrap_log）
// ---------------------------------------------------------------------------

/// Bootstrap 24 小时聚合里的一个节点。
class BootstrapStatsSnapshot {
  const BootstrapStatsSnapshot({
    required this.attempts,
    required this.successes,
    required this.failures,
    required this.averageElapsedMs,
    required this.ips,
  });

  const BootstrapStatsSnapshot.empty()
    : attempts = 0,
      successes = 0,
      failures = 0,
      averageElapsedMs = 0,
      ips = const [];

  final int attempts;
  final int successes;
  final int failures;

  /// 各节点按尝试次数加权后的平均耗时；没有样本时为 0。
  final double averageElapsedMs;
  final List<BootstrapIpStat> ips;

  double get successRate => attempts == 0 ? 0 : successes / attempts;
}

final bootstrapStatsProvider = FutureProvider<BootstrapStatsSnapshot>((
  ref,
) async {
  ref.watch(dnsLogRevisionProvider);
  final range = ref.watch(bootstrapStatsRangeProvider);
  final db = await ref.watch(activeLogDatabaseProvider.future);
  if (db == null) return const BootstrapStatsSnapshot.empty();

  // `BootstrapLogRepository.recentStats` 只接受「窗口长度」：把「今日」翻译成
  // 「从今天零点到现在的时长」，正好等价于旧版 `statsRangeStartMillis(TODAY)`。
  final now = DateTime.now();
  final start = range.startOf(now);
  final window = start == null
      ? const Duration(days: 3650)
      : now.difference(start);
  final ips = await BootstrapLogRepository(db).recentStats(window: window);

  var attempts = 0;
  var successes = 0;
  var failures = 0;
  var weighted = 0.0;
  for (final ip in ips) {
    attempts += ip.attempts;
    successes += ip.successes;
    failures += ip.failures;
    weighted += (ip.averageElapsedMs ?? 0) * ip.attempts;
  }
  return BootstrapStatsSnapshot(
    attempts: attempts,
    successes: successes,
    failures: failures,
    averageElapsedMs: attempts == 0 ? 0 : weighted / attempts,
    ips: ips,
  );
});

// ---------------------------------------------------------------------------
// 下钻页：订阅拦截（真实表 dns_log / http_request_log）
// ---------------------------------------------------------------------------

/// 一条订阅的拦截统计。
class SubscriptionInterceptionItem {
  const SubscriptionInterceptionItem({
    required this.id,
    required this.name,
    required this.enabled,
    required this.deleted,
    required this.hits,
    required this.rate,
  });

  final int id;
  final String name;
  final bool enabled;

  /// 订阅已从 `subscription` 表删掉，但日志里还留着它的命中。
  final bool deleted;
  final int hits;

  /// 占全部已记录请求的比例（0..1）。
  final double rate;

  String get statusLabel {
    if (deleted) return '已删除';
    return enabled ? '已启用' : '已禁用';
  }
}

/// 订阅拦截统计的整体结果。
class SubscriptionInterceptionSnapshot {
  const SubscriptionInterceptionSnapshot({
    required this.totalRequests,
    required this.items,
    this.missingColumn = false,
  });

  const SubscriptionInterceptionSnapshot.empty()
    : totalRequests = 0,
      items = const [],
      missingColumn = false;

  /// 窗口内 DNS + HTTPS 的全部已记录请求数（拦截率的分母）。
  final int totalRequests;
  final List<SubscriptionInterceptionItem> items;

  /// 旧库缺 `blockSubscriptionId` 列（未升级到 1.4.3 的库版本）。
  /// 这时不能算出任何拦截率，页面必须走空状态并说明，而不是显示 0%。
  final bool missingColumn;
}

/// 订阅拦截统计。
///
/// SQL 与旧版 `DnsLogDao.subscriptionInterceptionStats` /
/// `HttpRequestLogDao.subscriptionInterceptionStats` 同口径：
/// 分母是两张表的全部行数，分子只统计 `result = BLOCKED` 且
/// `blockSubscriptionId` 非空的行。
final subscriptionInterceptionProvider =
    FutureProvider<SubscriptionInterceptionSnapshot>((ref) async {
      ref.watch(dnsLogRevisionProvider);
      final range = ref.watch(subscriptionStatsRangeProvider);
      final db = await ref.watch(activeLogDatabaseProvider.future);
      if (db == null) return const SubscriptionInterceptionSnapshot.empty();
      final since = range.startOf(DateTime.now())?.millisecondsSinceEpoch;

      try {
        final hits = <int, int>{};
        var total = 0;

        final dnsTotal = await db.rawQuery(
          'SELECT COUNT(*) AS n FROM dns_log'
          '${since == null ? '' : ' WHERE timestamp >= ?'}',
          [?since],
        );
        total += (dnsTotal.first['n'] as num?)?.toInt() ?? 0;

        final dnsHits = await db.rawQuery(
          'SELECT blockSubscriptionId AS id, COUNT(*) AS hits FROM dns_log '
          "WHERE result = 'BLOCKED' AND blockSubscriptionId IS NOT NULL"
          '${since == null ? '' : ' AND timestamp >= ?'} '
          'GROUP BY blockSubscriptionId',
          [?since],
        );
        for (final row in dnsHits) {
          final id = (row['id'] as num?)?.toInt();
          if (id == null) continue;
          hits[id] = (hits[id] ?? 0) + ((row['hits'] as num?)?.toInt() ?? 0);
        }

        // 极速模式没有 `http_request_log` 表：查它会抛 `no such table`，
        // 这里捕获后按「没有 HTTPS 记录」处理，不影响 DNS 侧的统计。
        var httpsAvailable = true;
        try {
          final httpsTotal = await db.rawQuery(
            'SELECT COUNT(*) AS n FROM http_request_log'
            '${since == null ? '' : ' WHERE timestamp >= ?'}',
            [?since],
          );
          total += (httpsTotal.first['n'] as num?)?.toInt() ?? 0;

          final httpsHits = await db.rawQuery(
            'SELECT blockSubscriptionId AS id, COUNT(*) AS hits '
            'FROM http_request_log '
            "WHERE outcome IN ('blocked', 'invalid') "
            'AND blockSubscriptionId IS NOT NULL'
            '${since == null ? '' : ' AND timestamp >= ?'} '
            'GROUP BY blockSubscriptionId',
            [?since],
          );
          for (final row in httpsHits) {
            final id = (row['id'] as num?)?.toInt();
            if (id == null) continue;
            hits[id] = (hits[id] ?? 0) + ((row['hits'] as num?)?.toInt() ?? 0);
          }
        } on DatabaseException {
          httpsAvailable = false;
        }

        if (!httpsAvailable && total == 0) {
          return const SubscriptionInterceptionSnapshot.empty();
        }

        // 订阅名与会话状态从 `subscription` 表取；命中里有、表里没有的 id
        // 就是「已删除订阅」，旧版同样保留并标灰。
        final subscriptions = await db.query(
          'subscription',
          columns: ['id', 'name', 'enabled'],
        );
        final byId = {
          for (final row in subscriptions)
            (row['id'] as num?)?.toInt() ?? 0: (
              name: row['name'] as String? ?? '',
              enabled: (row['enabled'] as num?)?.toInt() == 1,
            ),
        };

        final ids = {...byId.keys, ...hits.keys}.toList()..sort();
        final items =
            [
              for (final id in ids)
                () {
                  final subscription = byId[id];
                  final count = hits[id] ?? 0;
                  return SubscriptionInterceptionItem(
                    id: id,
                    name: subscription?.name ?? '已删除订阅 #$id',
                    enabled: subscription?.enabled ?? false,
                    deleted: subscription == null,
                    hits: count,
                    rate: total == 0 ? 0 : count / total,
                  );
                }(),
            ]..sort((a, b) {
              final byHits = b.hits.compareTo(a.hits);
              return byHits != 0 ? byHits : a.name.compareTo(b.name);
            });

        return SubscriptionInterceptionSnapshot(
          totalRequests: total,
          items: items,
        );
      } on DatabaseException catch (error) {
        // 旧库版本偏旧时这两列不存在（`subscriptionId` 是 1.4.3 才加的）。
        // 页面上要如实说明「当前库没有这一列」，而不是显示一张全 0 的表。
        if (error.toString().contains('no such column')) {
          return const SubscriptionInterceptionSnapshot(
            totalRequests: 0,
            items: [],
            missingColumn: true,
          );
        }
        rethrow;
      }
    });

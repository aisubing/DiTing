/// 日志仪表盘**概览块**的真实聚合（首页与 `/logs` 顶部那些统计卡）。
///
/// ## 口径来源
/// 逐条转写自 `Android/.../ui/ModernLogDashboardViewModel.kt` 的
/// `buildDashboardState()`：
/// - 今日请求 = `dns_log` 当日四档 + `http_request_log` 当日四档；
/// - 「仅拦截与错误」模式下 DNS 侧的 `passed` / `cached` 归零、HTTPS 侧只保留
///   非通过行（旧版 `it.copy(passed = 0, cached = 0)` 与那个 `filter`）；
/// - 「关闭日志」模式下不读 `dns_log` / `http_request_log` 的当日统计，只保留
///   缓存、竞速、Bootstrap 三项仍在跑的计数；
/// - 竞速与 Bootstrap 一律取**今日**窗口，不是整表；
/// - 订阅拦截的分子只算 `result = BLOCKED` / `outcome ∈ (blocked, invalid)` 且
///   `blockSubscriptionId` 非空的行，分母是两张表的当日全部行数。
///
/// ## 为什么仍然是一个 snapshot
/// 这些数字来自旧版**同一次** `buildDashboardState()` 扫描。拆成十几个 provider
/// 后各自重建，「今日请求」与「今日流量结构」会短暂不一致——同一个屏幕上两个
/// 数字互相矛盾，比数字慢一拍难解释得多。
///
/// ## 极速模式
/// `diting_express` 没有 `http_request_log`（`ExpressRulesDatabase` 明确排除），
/// 查它会抛 `no such table`。这里按「没有 HTTPS 记录」处理，而不是让整块概览
/// 进 error 态。
library;

import 'package:diting/data/db/bootstrap_log_repository.dart';
import 'package:diting/data/db/dns_cache_repository.dart';
import 'package:diting/data/db/dns_log_repository.dart';
import 'package:diting/data/db/http_request_repository.dart';
import 'package:diting/data/dns_type_name.dart';
import 'package:diting/data/log_dashboard_models.dart';
import 'package:diting/data/log_dashboard_rows.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/observability_providers.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// 旧版 `RECENT_LOG_LIMIT` / `RECENT_CACHE_LIMIT` / `TOP_LIST_LIMIT` /
/// `SUBSCRIPTION_LIST_LIMIT`。
const _recentLogLimit = 5;
const _recentCacheLimit = 5;
const _topListLimit = 8;
const _subscriptionListLimit = 5;

/// 一次渲染所需的全部概览数据。
class LogDashboardSnapshot {
  const LogDashboardSnapshot({
    required this.breakdown,
    required this.quality,
    required this.race,
    required this.bootstrap,
    required this.offMode,
    required this.recentRequests,
    required this.cacheHotspots,
    required this.raceWinners,
    required this.bootstrapIps,
    required this.subscriptionBlocks,
  });

  /// 没有旧库（全新安装）时的空快照：所有计数为 0、所有列表为空。
  ///
  /// 卡片据此渲染「0」与空态文案。这是真实的「今天还没有请求」，不是占位符；
  /// 加载中/读取失败则由调用方看 `AsyncValue` 自行显示破折号。
  const LogDashboardSnapshot.empty()
    : breakdown = const LogTrafficBreakdown.empty(),
      quality = const LogDnsQuality.empty(),
      race = const LogRaceSummary.empty(),
      bootstrap = const LogBootstrapSummary.empty(),
      offMode = const LogOffModeStats.empty(),
      recentRequests = const [],
      cacheHotspots = const [],
      raceWinners = const [],
      bootstrapIps = const [],
      subscriptionBlocks = const [];

  final LogTrafficBreakdown breakdown;

  /// DNS 解析质量（平均延迟 / 缓存命中率），读同一批 `dns_log` 当日行。
  final LogDnsQuality quality;
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
  /// 旧版 `FilteredModeDashboard` 里 `重点记录` 取自 `stats.total`，而
  /// `total` 在 filtered 模式下已经只含拦截与错误，因此这里按「过滤 + 失败」
  /// 求和，与卡片语义一致。
  int get highlightedTotal => breakdown.blocked + breakdown.error;
}

/// 今日零点的毫秒时间戳（本地时区，与旧版 `dayStartMillis()` 同口径）。
int _dayStartMillis() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
}

/// 概览数据。真实表为空时给 [LogDashboardSnapshot.empty]，绝不回退演示值。
final logDashboardProvider = FutureProvider<LogDashboardSnapshot>((ref) async {
  // 刷新按钮与「清空日志」都 bump 这个计数器：概览必须与列表一起重建，
  // 否则清空之后顶部还挂着旧数字。
  ref.watch(dnsLogRevisionProvider);
  final mode = ref.watch(logModeProvider);
  final express = ref.watch(workModeProvider) == AppWorkMode.express;
  final off = mode == LegacyLogMode.off;
  final filteredMode = mode == LegacyLogMode.blockedAndErrors;
  final since = DateTime.fromMillisecondsSinceEpoch(_dayStartMillis());

  final db = await ref.watch(activeLogDatabaseProvider.future);
  if (db == null) return const LogDashboardSnapshot.empty();

  final dnsDaily = off
      ? null
      : await DnsLogRepository(db).dailyStats(since: since);

  // 极速模式与「关闭日志」都不产生 HTTPS 记录。主库缺失或旧版本没有这张表
  // （`no such table`）同样按「没有 HTTPS 记录」处理。
  var httpStats = const HttpRequestDailyStats.empty();
  if (!off && !express) {
    final mainDb = await ref.watch(mainLogDatabaseProvider.future);
    if (mainDb != null) {
      try {
        httpStats = await HttpRequestRepository(mainDb).dailyStats(since: since);
      } on DatabaseException {
        httpStats = const HttpRequestDailyStats.empty();
      }
    }
  }

  var httpPassed = 0;
  var httpBlocked = 0;
  var httpError = 0;
  var httpBypassed = 0;
  for (final entry in httpStats.byOutcome.entries) {
    if (filteredMode && httpOutcomeIsPassed(entry.key)) continue;
    switch (httpRowStatusOf(entry.key)) {
      case LogRowStatus.passed:
        httpPassed += entry.value;
      case LogRowStatus.filtered:
        httpBlocked += entry.value;
      case LogRowStatus.bypassed:
        httpBypassed += entry.value;
      case LogRowStatus.failed:
      case LogRowStatus.cached:
        httpError += entry.value;
    }
  }

  // 「仅拦截与错误」模式下旧版把 DNS 侧的 `passed` / `cached` 直接归零
  // （`it.copy(passed = 0, cached = 0)`），因为那一档的日志里本来就只有拦截与
  // 错误行——不归零会让「重点流量结构」把通过数也画进环形图，两个数字互相矛盾。
  final dnsPassed = filteredMode ? 0 : (dnsDaily?.passed ?? 0);
  final dnsCached = filteredMode ? 0 : (dnsDaily?.cached ?? 0);
  final passed = dnsPassed + httpPassed;
  final blocked = (dnsDaily?.blocked ?? 0) + httpBlocked;
  final error = (dnsDaily?.error ?? 0) + httpError;

  final race = await _loadRace(ref, db, since);
  final bootstrap = await _loadBootstrap(db, since);
  final cache = DnsCacheRepository(db);
  final offMode = LogOffModeStats(
    cacheEntries: await cache.countUnexpired(),
    cacheHits: await cache.totalHitCount(),
    raceRequests: race.summary.requests,
    bootstrapAttempts: bootstrap.summary.attempts,
  );

  return LogDashboardSnapshot(
    breakdown: LogTrafficBreakdown(
      total: passed + blocked + error + httpBypassed,
      passed: passed,
      blocked: blocked,
      error: error,
      bypassed: httpBypassed,
      cached: dnsCached,
    ),
    // 平均延迟在没有计时样本时给 null（页面显示破折号）；命中率分母是
    // `passed + error`，与 `DnsLogDailyStats.cacheHitRate` 同一口径。
    // 过滤模式把通过数归零后，命中率必须跟着重算：直接用
    // `dnsDaily.cacheHitRate` 会留下一个「通过 0 但命中率 40%」的自相矛盾。
    quality: dnsDaily == null
        ? const LogDnsQuality.empty()
        : LogDnsQuality(
            averageLatencyMs: dnsDaily.latencySamples == 0
                ? null
                : dnsDaily.averageLatencyMs.toDouble(),
            latencySamples: dnsDaily.latencySamples,
            cacheHitRate: filteredMode
                ? 0
                : dnsDaily.cacheHitRate,
          ),
    race: race.summary,
    bootstrap: bootstrap.summary,
    offMode: offMode,
    recentRequests: off
        ? const []
        : await _loadRecentRequests(ref, db, express: express, filtered: filteredMode),
    cacheHotspots: await _loadCacheHotspots(cache),
    raceWinners: race.winners,
    bootstrapIps: bootstrap.ips,
    subscriptionBlocks: off
        ? const []
        : await _loadSubscriptionBlocks(db, since, express: express),
  );
});

// ---------------------------------------------------------------------------
// 竞速（dns_race_log，今日窗口）
// ---------------------------------------------------------------------------

class _RaceSlice {
  const _RaceSlice({required this.summary, required this.winners});

  final LogRaceSummary summary;
  final List<LogRaceWinner> winners;
}

Future<_RaceSlice> _loadRace(Ref ref, Database db, DateTime since) async {
  final start = since.millisecondsSinceEpoch;
  final rows = await db.rawQuery(
    'SELECT COUNT(*) AS requests, '
    'COALESCE(SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END), 0) AS successes, '
    'AVG(elapsedMs) AS avgElapsed FROM dns_race_log WHERE timestamp >= ?',
    [start],
  );
  final row = rows.isEmpty ? null : rows.first;
  final summary = LogRaceSummary(
    requests: (row?['requests'] as num?)?.toInt() ?? 0,
    successes: (row?['successes'] as num?)?.toInt() ?? 0,
    averageElapsedMs: ((row?['avgElapsed'] as num?) ?? 0).toDouble(),
  );

  final ranking = await db.rawQuery(
    'SELECT winnerProviderId AS providerId, COUNT(*) AS wins, '
    'AVG(CASE WHEN winnerElapsedMs IS NOT NULL THEN winnerElapsedMs END) '
    'AS avgElapsed FROM dns_race_log '
    'WHERE success = 1 AND winnerProviderId IS NOT NULL AND timestamp >= ? '
    'GROUP BY winnerProviderId ORDER BY wins DESC, avgElapsed ASC LIMIT ?',
    [start, _topListLimit],
  );

  // 名称解析与竞速页共用同一份目录（预设 + 用户自定义），否则同一服务商在
  // 概览与下钻页会显示成两个名字。
  final settings = ref.watch(legacySettingsProvider);
  final names = {
    for (final provider in [
      ...defaultDnsProviders,
      ...parseUserProviders(settings.userProvidersJson),
    ])
      provider.id: provider.name,
  };

  return _RaceSlice(
    summary: summary,
    winners: [
      for (final entry in ranking)
        if ((entry['providerId'] as String?)?.isNotEmpty == true)
          LogRaceWinner(
            name: names[entry['providerId']] ?? entry['providerId']! as String,
            wins: (entry['wins'] as num?)?.toInt() ?? 0,
            averageElapsedMs: ((entry['avgElapsed'] as num?) ?? 0).toDouble(),
          ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Bootstrap（bootstrap_log，今日窗口）
// ---------------------------------------------------------------------------

class _BootstrapSlice {
  const _BootstrapSlice({required this.summary, required this.ips});

  final LogBootstrapSummary summary;
  final List<LogBootstrapIp> ips;
}

Future<_BootstrapSlice> _loadBootstrap(Database db, DateTime since) async {
  // `BootstrapLogRepository.recentStats` 只接受窗口长度：把「今日」翻译成
  // 「从今天零点到现在的时长」，与旧版 `statsRangeStartMillis(TODAY)` 等价。
  final window = DateTime.now().difference(since);
  final stats = await BootstrapLogRepository(
    db,
  ).recentStats(window: window < Duration.zero ? Duration.zero : window);

  var attempts = 0;
  var successes = 0;
  var weighted = 0.0;
  for (final stat in stats) {
    attempts += stat.attempts;
    successes += stat.successes;
    weighted += (stat.averageElapsedMs ?? 0) * stat.attempts;
  }
  return _BootstrapSlice(
    summary: LogBootstrapSummary(
      attempts: attempts,
      successes: successes,
      averageElapsedMs: attempts == 0 ? 0 : weighted / attempts,
    ),
    ips: [
      for (final stat in stats.take(_topListLimit))
        LogBootstrapIp(
          name: stat.name,
          ip: stat.ip,
          attempts: stat.attempts,
          successes: stat.successes,
          averageElapsedMs: stat.averageElapsedMs ?? 0,
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// 最近请求（dns_log + http_request_log 合并，按时间倒序取前 N 条）
// ---------------------------------------------------------------------------

Future<List<LogRecentRequest>> _loadRecentRequests(
  Ref ref,
  Database db, {
  required bool express,
  required bool filtered,
}) async {
  // 「仅拦截与错误」模式下旧版在 SQL 里就只取 BLOCKED / ERROR 两档
  // （`recentLogs(limit, mode)`），不是在内存里筛。
  final dnsRows = await db.query(
    'dns_log',
    where: filtered ? "result IN ('BLOCKED', 'ERROR')" : null,
    orderBy: 'timestamp DESC, id DESC',
    limit: _recentLogLimit,
  );
  final dnsLogs = [
    for (final row in dnsRows)
      DnsLogRecord(
        timestamp: (row['timestamp'] as num?)?.toInt() ?? 0,
        domain: row['queryName'] as String? ?? '',
        queryType: (row['queryType'] as num?)?.toInt() ?? 0,
        result: row['result'] as String? ?? 'PASSED',
        cached: (row['cached'] as num?)?.toInt() == 1,
        message: row['message'] as String?,
        packageName: row['packageName'] as String?,
      ),
  ];

  var httpRows = const <HttpRequestRecord>[];
  if (!express) {
    final mainDb = await ref.watch(mainLogDatabaseProvider.future);
    if (mainDb != null) {
      try {
        httpRows = await HttpRequestRepository(
          mainDb,
        ).recent(limit: _recentLogLimit);
      } on DatabaseException {
        httpRows = const [];
      }
    }
  }

  final merged = <({int timestamp, LogRecentRequest row})>[
    for (final row in dnsLogs)
      (timestamp: row.timestamp, row: logRecentRequestOfDns(row)),
    for (final row in httpRows)
      if (!filtered || !httpOutcomeIsPassed(row.outcome))
        (timestamp: row.timestamp, row: logRecentRequestOfHttp(row)),
  ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return [for (final entry in merged.take(_recentLogLimit)) entry.row];
}

// ---------------------------------------------------------------------------
// 缓存热点（dns_cache，命中次数降序）
// ---------------------------------------------------------------------------

Future<List<LogCacheHotspot>> _loadCacheHotspots(
  DnsCacheRepository repository,
) async {
  final entries = await repository.entries(limit: _recentCacheLimit);
  return [
    for (final entry in entries)
      LogCacheHotspot(
        queryName: entry.domain,
        queryType: dnsTypeName(entry.queryType),
        remainingSeconds: entry.remainingTtlSeconds,
        responseSize: entry.responseSize,
        hitCount: entry.hitCount,
      ),
  ];
}

// ---------------------------------------------------------------------------
// 规则拦截（订阅拦截命中 → 订阅名）
// ---------------------------------------------------------------------------

Future<List<LogSubscriptionBlock>> _loadSubscriptionBlocks(
  Database db,
  DateTime since, {
  required bool express,
}) async {
  final start = since.millisecondsSinceEpoch;
  final hits = <int, int>{};
  var total = 0;

  final dnsTotal = await db.rawQuery(
    'SELECT COUNT(*) AS n FROM dns_log WHERE timestamp >= ?',
    [start],
  );
  total += (dnsTotal.first['n'] as num?)?.toInt() ?? 0;

  final dnsHits = await db.rawQuery(
    'SELECT blockSubscriptionId AS id, COUNT(*) AS hits FROM dns_log '
    "WHERE result = 'BLOCKED' AND blockSubscriptionId IS NOT NULL "
    'AND timestamp >= ? GROUP BY blockSubscriptionId',
    [start],
  );
  for (final row in dnsHits) {
    final id = (row['id'] as num?)?.toInt();
    if (id == null) continue;
    hits[id] = (hits[id] ?? 0) + ((row['hits'] as num?)?.toInt() ?? 0);
  }

  if (!express) {
    // 极速模式没有 `http_request_log`；旧库版本偏旧时也没有这一列，两种都按
    // 「没有 HTTPS 命中」处理，不影响 DNS 侧的统计。
    try {
      final httpTotal = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM http_request_log WHERE timestamp >= ?',
        [start],
      );
      total += (httpTotal.first['n'] as num?)?.toInt() ?? 0;

      final httpHits = await db.rawQuery(
        'SELECT blockSubscriptionId AS id, COUNT(*) AS hits '
        'FROM http_request_log '
        "WHERE outcome IN ('blocked', 'invalid') "
        'AND blockSubscriptionId IS NOT NULL AND timestamp >= ? '
        'GROUP BY blockSubscriptionId',
        [start],
      );
      for (final row in httpHits) {
        final id = (row['id'] as num?)?.toInt();
        if (id == null) continue;
        hits[id] = (hits[id] ?? 0) + ((row['hits'] as num?)?.toInt() ?? 0);
      }
    } on DatabaseException {
      // 表或列不存在：HTTPS 侧没有可统计的行。
    }
  }

  if (total == 0 && hits.isEmpty) return const [];

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

  final blocks = [
    for (final entry in hits.entries)
      LogSubscriptionBlock(
        name: byId[entry.key]?.name ?? '已删除订阅 #${entry.key}',
        enabled: byId[entry.key]?.enabled ?? false,
        deleted: !byId.containsKey(entry.key),
        hits: entry.value,
        rate: total == 0 ? 0 : entry.value / total,
      ),
  ]..sort((a, b) => b.hits.compareTo(a.hits));
  return blocks.take(_subscriptionListLimit).toList();
}

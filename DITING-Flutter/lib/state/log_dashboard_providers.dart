/// 日志仪表盘**下钻页**的数据层（时间范围选择器 + 竞速 / Bootstrap / 订阅拦截）。
///
/// 概览块（首页与 `/logs` 顶部的统计卡）搬到了
/// `log_dashboard_overview_providers.dart`：它的聚合要一次扫描五张表，与这里的
/// 单表窗口查询不是同一件事，混在一个文件里只会让两边都读不懂。
///
/// 两类数据仍然刻意分开：
/// - **概览块**读旧库真实表（见概览文件的注释）；
/// - **四个下钻页**也读真实表：竞速 `dns_race_log`、Bootstrap `bootstrap_log`、
///   缓存 `dns_cache`（`dnsCacheProvider`）、订阅拦截 `dns_log` /
///   `http_request_log` 的 `blockSubscriptionId` 列。库空 → 空状态，缺列 →
///   空状态 + 说明，绝不拿演示值冒充。
///
/// 竞速相关（策略概览 / 智能选择首选 / 胜出排行 / 窗口选择）已拆到
/// `log_race_providers.dart`：那一块模型多、SQL 多，与本文件的 Bootstrap /
/// 缓存 / 订阅拦截不是同一份职责，也避免本文件逼近 600 行上限。
library;

import 'package:diting/data/db/bootstrap_log_repository.dart';
import 'package:diting/state/log_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';



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

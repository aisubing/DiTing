/// 日志仪表盘概览块的模型（旧版 `ModernLogDashboardViewModel.kt` 的
/// `Dashboard*Item` / `Dashboard*Summary`）。
///
/// 这里只有形状，没有数值：每一块的取值来自
/// `state/log_dashboard_overview_providers.dart` 对旧库真实表的聚合。曾经的
/// `mock_log_dashboard.dart` 把这些模型和一组固定演示常量混在一起，调用方只要
/// 引用模型就会顺带拿到那组常量，于是「概览块用演示值」一路留到了最后。
library;

/// 一行请求的处置档位。与 `LogResult` 的四值 + 缓存命中同形，颜色在 UI 侧映射。
enum LogRowStatus { passed, filtered, failed, bypassed, cached }

/// DNS 解析质量（旧版 `DashboardDnsQuality`）。
///
/// 三个数都来自 `dns_log` 的当日行：
/// - [averageLatencyMs] 是 `elapsed=NNms` 的平均值，**没有样本时给 null**，
///   页面显示破折号。给 0 会被读成「0ms，很快」，而真相是「今天还没解析过」。
/// - [cacheHitRate] 的分母是 `passed + error`（旧版口径），不是全部行：拦截与
///   旁路根本没有查上游，计入分母会把命中率算低。
class LogDnsQuality {
  const LogDnsQuality({
    required this.averageLatencyMs,
    required this.latencySamples,
    required this.cacheHitRate,
  });

  const LogDnsQuality.empty()
    : averageLatencyMs = null,
      latencySamples = 0,
      cacheHitRate = 0;

  final double? averageLatencyMs;
  final int latencySamples;
  final double cacheHitRate;
}

/// 今日流量结构（旧版 `DashboardDailyStats`）。
class LogTrafficBreakdown {
  const LogTrafficBreakdown({
    required this.total,
    required this.passed,
    required this.blocked,
    required this.error,
    required this.bypassed,
    required this.cached,
  });

  const LogTrafficBreakdown.empty()
    : total = 0,
      passed = 0,
      blocked = 0,
      error = 0,
      bypassed = 0,
      cached = 0;

  final int total;
  final int passed;
  final int blocked;
  final int error;
  final int bypassed;

  /// 缓存命中数，是 [passed] 的子集（旧版把它单列一块图例）。
  final int cached;

  double get blockRate => total == 0 ? 0 : blocked / total;

  double get cacheRate => total == 0 ? 0 : cached / total;
}

/// 竞速汇总（旧版 `DashboardRaceSummary`）。
class LogRaceSummary {
  const LogRaceSummary({
    required this.requests,
    required this.successes,
    required this.averageElapsedMs,
  });

  const LogRaceSummary.empty()
    : requests = 0,
      successes = 0,
      averageElapsedMs = 0;

  final int requests;
  final int successes;
  final double averageElapsedMs;

  double get successRate => requests == 0 ? 0 : successes / requests;
}

/// Bootstrap 汇总（旧版 `DashboardBootstrapSummary`）。
class LogBootstrapSummary {
  const LogBootstrapSummary({
    required this.attempts,
    required this.successes,
    required this.averageElapsedMs,
  });

  const LogBootstrapSummary.empty()
    : attempts = 0,
      successes = 0,
      averageElapsedMs = 0;

  final int attempts;
  final int successes;
  final double averageElapsedMs;

  double get successRate => attempts == 0 ? 0 : successes / attempts;
}

/// 关闭日志模式下的四格：缓存与竞速仍然在跑，只是不记请求明细。
class LogOffModeStats {
  const LogOffModeStats({
    required this.cacheEntries,
    required this.cacheHits,
    required this.raceRequests,
    required this.bootstrapAttempts,
  });

  const LogOffModeStats.empty()
    : cacheEntries = 0,
      cacheHits = 0,
      raceRequests = 0,
      bootstrapAttempts = 0;

  final int cacheEntries;
  final int cacheHits;
  final int raceRequests;
  final int bootstrapAttempts;
}

/// 一条最近请求（旧版 `DashboardRequestLogItem`）。
///
/// [time] 由该行的 `timestamp` 现算（`HH:mm:ss`），不是固定字面量：列表要按
/// 真实时间倒序，写死的时间戳会与排序依据对不上。
class LogRecentRequest {
  const LogRecentRequest({
    required this.time,
    required this.name,
    required this.source,
    required this.meta,
    required this.resultLabel,
    required this.status,
  });

  final String time;
  final String name;

  /// `DNS` / `HTTPS` / `TCP` / `UDP`，旧版按行来源给这一列。
  final String source;

  /// 记录类型 + 命中情况（`A · 命中缓存`）。
  final String meta;

  /// 处置文案：通过 / 覆写 / 过滤 / 失败 / 旁路（旧版 `dashboardDnsResultLabel`）。
  final String resultLabel;
  final LogRowStatus status;
}

/// 一条缓存热点（旧版 `DashboardCacheEntryItem`）。
class LogCacheHotspot {
  const LogCacheHotspot({
    required this.queryName,
    required this.queryType,
    required this.remainingSeconds,
    required this.responseSize,
    required this.hitCount,
  });

  final String queryName;

  /// 记录类型名，已由数字类型（1 / 28 / 5 …）转成 `A` / `AAAA` / `CNAME`。
  final String queryType;
  final int remainingSeconds;
  final int responseSize;
  final int hitCount;
}

/// 一个竞速胜出服务商（旧版 `DashboardRaceWinnerItem`）。
class LogRaceWinner {
  const LogRaceWinner({
    required this.name,
    required this.wins,
    required this.averageElapsedMs,
  });

  final String name;
  final int wins;
  final double averageElapsedMs;
}

/// 一个 Bootstrap 节点（旧版 `DashboardBootstrapIpItem`）。
class LogBootstrapIp {
  const LogBootstrapIp({
    required this.name,
    required this.ip,
    required this.attempts,
    required this.successes,
    required this.averageElapsedMs,
  });

  final String name;
  final String ip;
  final int attempts;
  final int successes;
  final double averageElapsedMs;

  double get successRate => attempts == 0 ? 0 : successes / attempts;
}

/// 一条订阅规则拦截（旧版 `DashboardSubscriptionItem`）。
class LogSubscriptionBlock {
  const LogSubscriptionBlock({
    required this.name,
    required this.enabled,
    required this.deleted,
    required this.hits,
    required this.rate,
  });

  final String name;
  final bool enabled;

  /// 规则已从库里删掉、但日志里还留着它的命中 → 显示「已删除」。
  final bool deleted;
  final int hits;

  /// 占全部已记录请求的比例（0..1）。
  final double rate;

  /// 旧版 `status` 文案：已删除 > 已启用 > 已禁用。
  String get statusLabel {
    if (deleted) return '已删除';
    return enabled ? '已启用' : '已禁用';
  }
}

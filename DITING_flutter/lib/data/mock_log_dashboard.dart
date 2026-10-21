/// 日志仪表盘的演示数据。
///
/// 1.4.3 的这些数字全部来自 Room 表与 `RaceLogRepository` / `BootstrapLogRepository`
/// 的当日聚合（见 `ui/ModernLogDashboardViewModel.kt`）。本仓的**概览块**用固定
/// 演示值把布局撑到真实密度；**四个下钻页**读真实表
/// （`dnsCacheProvider` / `raceRankingProvider` / `BootstrapLogRepository`），
/// 库空时显示空状态，绝不拿这里的数字冒充。
///
/// 取值纪律：
/// - 不用 `Random`、不在断言路径里调 `DateTime.now()`：数值是编译期常量，
///   测试与截图都可复现；
/// - 内部自洽：`total = passed + blocked + error + bypassed`（`cached` 是
///   `passed` 的子集，与旧版 `DashboardDailyStats` 同口径），竞速胜出次数之和
///   等于竞速请求数，Bootstrap 各 IP 尝试次数之和等于总尝试数。
library;

/// 一行请求的处置档位。与 `LogResult` 的四值 + 缓存命中同形，颜色在 UI 侧映射。
enum LogRowStatus { passed, filtered, failed, bypassed, cached }

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

/// 数值刻意不与旧版 `mockServiceStats`（28471 / 21930 / 4218）重合：
/// 那组数字是 FlClash 演示时代的常量，长得一样会让「这是真实数据还是演示
/// 数据」这个判断彻底失去抓手。
const mockLogTrafficBreakdown = LogTrafficBreakdown(
  total: 21846,
  passed: 17320,
  blocked: 3124,
  error: 251,
  bypassed: 1151,
  cached: 12847,
);

/// 竞速汇总（旧版 `DashboardRaceSummary`）。
class LogRaceSummary {
  const LogRaceSummary({
    required this.requests,
    required this.successes,
    required this.averageElapsedMs,
  });

  final int requests;
  final int successes;
  final double averageElapsedMs;

  double get successRate => requests == 0 ? 0 : successes / requests;
}

const mockLogRaceSummary = LogRaceSummary(
  requests: 1842,
  successes: 1793,
  averageElapsedMs: 38,
);

/// Bootstrap 汇总（旧版 `DashboardBootstrapSummary`）。
class LogBootstrapSummary {
  const LogBootstrapSummary({
    required this.attempts,
    required this.successes,
    required this.averageElapsedMs,
  });

  final int attempts;
  final int successes;
  final double averageElapsedMs;

  double get successRate => attempts == 0 ? 0 : successes / attempts;
}

const mockLogBootstrapSummary = LogBootstrapSummary(
  attempts: 632,
  successes: 629,
  averageElapsedMs: 52,
);

/// 关闭日志模式下的四格：缓存与竞速仍然在跑，只是不记请求明细。
class LogOffModeStats {
  const LogOffModeStats({
    required this.cacheEntries,
    required this.cacheHits,
    required this.raceRequests,
    required this.bootstrapAttempts,
  });

  final int cacheEntries;
  final int cacheHits;
  final int raceRequests;
  final int bootstrapAttempts;
}

const mockLogOffModeStats = LogOffModeStats(
  cacheEntries: 4096,
  cacheHits: 21930,
  raceRequests: 1842,
  bootstrapAttempts: 632,
);

/// 一条最近请求（旧版 `DashboardRequestLogItem`）。
///
/// [time] 是固定的 `HH:mm:ss` 字面量而不是 `DateTime`：演示列表要能逐字比对，
/// 用当前时钟排序会让每次打开都不一样。
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

  /// 处置文案：通过 / 过滤 / 失败 / 旁路（旧版 `dashboardDnsResultLabel`）。
  final String resultLabel;
  final LogRowStatus status;
}

const mockRecentRequests = <LogRecentRequest>[
  LogRecentRequest(
    time: '12:04:31',
    name: 'api.example.com',
    source: 'DNS',
    meta: 'A · 命中缓存',
    resultLabel: '通过',
    status: LogRowStatus.passed,
  ),
  LogRecentRequest(
    time: '12:04:28',
    name: 'ads.tracker.example.net',
    source: 'DNS',
    meta: 'A · 命中规则',
    resultLabel: '过滤',
    status: LogRowStatus.filtered,
  ),
  LogRecentRequest(
    time: '12:04:22',
    name: 'cdn.example.com',
    source: 'HTTPS',
    meta: 'h2 · com.android.chrome',
    resultLabel: '通过',
    status: LogRowStatus.passed,
  ),
  LogRecentRequest(
    time: '12:04:15',
    name: 'login.example.org',
    source: 'DNS',
    meta: 'AAAA · 上游超时',
    resultLabel: '失败',
    status: LogRowStatus.failed,
  ),
  LogRecentRequest(
    time: '12:04:09',
    name: '140.82.112.3:443',
    source: 'TCP',
    meta: 'TCP 直连 · 系统',
    resultLabel: '旁路',
    status: LogRowStatus.bypassed,
  ),
];

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

const mockCacheHotspots = <LogCacheHotspot>[
  LogCacheHotspot(
    queryName: 'api.example.com',
    queryType: 'A',
    remainingSeconds: 3420,
    responseSize: 148,
    hitCount: 512,
  ),
  LogCacheHotspot(
    queryName: 'cdn.example.com',
    queryType: 'CNAME',
    remainingSeconds: 1860,
    responseSize: 96,
    hitCount: 388,
  ),
  LogCacheHotspot(
    queryName: 'img.example.com',
    queryType: 'A',
    remainingSeconds: 720,
    responseSize: 128,
    hitCount: 264,
  ),
  LogCacheHotspot(
    queryName: 'static.example.com',
    queryType: 'AAAA',
    remainingSeconds: 240,
    responseSize: 172,
    hitCount: 150,
  ),
  LogCacheHotspot(
    queryName: 'mail.example.org',
    queryType: 'MX',
    remainingSeconds: 3600,
    responseSize: 210,
    hitCount: 96,
  ),
];

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

/// 胜出次数之和 = [mockLogRaceSummary.requests] - 失败数，与概览口径一致。
const mockRaceWinners = <LogRaceWinner>[
  LogRaceWinner(name: '阿里云 DNS', wins: 624, averageElapsedMs: 24),
  LogRaceWinner(name: '腾讯云 DNSPod', wins: 512, averageElapsedMs: 31),
  LogRaceWinner(name: 'Cloudflare', wins: 402, averageElapsedMs: 46),
  LogRaceWinner(name: 'Google', wins: 255, averageElapsedMs: 78),
];

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

/// 尝试次数之和 = [mockLogBootstrapSummary.attempts]。
const mockBootstrapIps = <LogBootstrapIp>[
  LogBootstrapIp(
    name: '阿里 DNS',
    ip: '223.5.5.5',
    attempts: 268,
    successes: 268,
    averageElapsedMs: 41,
  ),
  LogBootstrapIp(
    name: '腾讯 DNS',
    ip: '1.12.12.12',
    attempts: 186,
    successes: 185,
    averageElapsedMs: 46,
  ),
  LogBootstrapIp(
    name: 'Cloudflare',
    ip: '1.1.1.1',
    attempts: 118,
    successes: 118,
    averageElapsedMs: 63,
  ),
  LogBootstrapIp(
    name: 'Google',
    ip: '8.8.8.8',
    attempts: 60,
    successes: 58,
    averageElapsedMs: 92,
  ),
];

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

const mockSubscriptionBlocks = <LogSubscriptionBlock>[
  LogSubscriptionBlock(
    name: 'AdGuard 基础',
    enabled: true,
    deleted: false,
    hits: 1842,
    rate: 0.0647,
  ),
  LogSubscriptionBlock(
    name: 'EasyList China',
    enabled: true,
    deleted: false,
    hits: 1204,
    rate: 0.0423,
  ),
  LogSubscriptionBlock(
    name: '反跟踪合集',
    enabled: true,
    deleted: false,
    hits: 806,
    rate: 0.0283,
  ),
  LogSubscriptionBlock(
    name: '实验性规则',
    enabled: false,
    deleted: false,
    hits: 366,
    rate: 0.0129,
  ),
];

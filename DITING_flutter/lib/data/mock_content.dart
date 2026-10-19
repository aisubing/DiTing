part of 'mock_data.dart';


/// 订阅导入类型。
enum SubscriptionImportType {
  remote('订阅地址'),
  local('本地文件');

  const SubscriptionImportType(this.label);

  final String label;
}

/// 一条订阅。
class MockSubscription {
  const MockSubscription({
    required this.id,
    required this.name,
    required this.url,
    required this.importType,
    required this.ruleCount,
    required this.group,
    this.enabled = true,
    this.updatedAt = '2026-10-18 09:24',
    this.isUpdating = false,
    this.error,
  });

  final String id;
  final String name;
  final String url;
  final SubscriptionImportType importType;
  final int ruleCount;
  final String group;
  final bool enabled;
  final String updatedAt;
  final bool isUpdating;
  final String? error;
}

const mockSubscriptionGroups = <String>['未分组', '广告拦截', '内网加速', '实验'];

const mockSubscriptions = <MockSubscription>[
  MockSubscription(
    id: 'sub-1',
    name: 'AdGuard 基础',
    url: 'https://rules.example.com/adguard-base.txt',
    importType: SubscriptionImportType.remote,
    ruleCount: 48213,
    group: '广告拦截',
  ),
  MockSubscription(
    id: 'sub-2',
    name: 'EasyList China',
    url: 'https://rules.example.com/easylist-cn.txt',
    importType: SubscriptionImportType.remote,
    ruleCount: 12870,
    group: '广告拦截',
  ),
  MockSubscription(
    id: 'sub-3',
    name: '内网 hosts',
    url: 'content://com.android.providers.downloads.documents/document/42',
    importType: SubscriptionImportType.local,
    ruleCount: 64,
    group: '内网加速',
    updatedAt: '2026-10-11 21:02',
  ),
  MockSubscription(
    id: 'sub-4',
    name: '实验性规则',
    url: 'https://rules.example.com/experimental.txt',
    importType: SubscriptionImportType.remote,
    ruleCount: 731,
    group: '实验',
    enabled: false,
    error: '上次更新失败：HTTP 404',
  ),
  MockSubscription(
    id: 'sub-5',
    name: '反跟踪合集',
    url: 'https://rules.example.com/anti-tracking.txt',
    importType: SubscriptionImportType.remote,
    ruleCount: 9021,
    group: '未分组',
  ),
];

/// 日志条目。
class MockLogEntry {
  const MockLogEntry({
    required this.time,
    required this.domain,
    required this.action,
    required this.latencyMs,
    required this.client,
    this.rule,
    this.cached = false,
  });

  final String time;
  final String domain;
  final LogAction action;
  final int latencyMs;
  final String client;
  final String? rule;
  final bool cached;
}

enum LogAction {
  allowed('放行'),
  blocked('拦截'),
  rewritten('覆写'),
  cached('缓存');

  const LogAction(this.label);

  final String label;
}

const _logDomains = <String>[
  'api.example.com',
  'ads.example.com',
  'cdn.example.com',
  'tracker.example.net',
  'login.example.com',
  'static.example.com',
  'metrics.example.org',
  'mail.example.com',
  'img.example.com',
  'beacon.example.io',
];

/// 40 条日志，时间从 12:04:31 递减，覆盖四种处置。
final mockLogs = <MockLogEntry>[
  for (var i = 0; i < 40; i++)
    MockLogEntry(
      time: _logTimeAt(i),
      domain: _logDomains[i % _logDomains.length],
      action: LogAction.values[i % LogAction.values.length],
      latencyMs: 6 + (i * 17) % 180,
      client: i % 3 == 0 ? '192.168.1.42' : '本机',
      rule: i % 4 == 0 ? '||ads.example.com^' : null,
      cached: i % 5 == 0,
    ),
];

String _logTimeAt(int index) {
  const base = 12 * 3600 + 4 * 60 + 31;
  final seconds = base - index * 7;
  final h = (seconds ~/ 3600) % 24;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}';
}

/// DNS 缓存条目。
class MockDnsCacheEntry {
  const MockDnsCacheEntry({
    required this.domain,
    required this.answer,
    required this.ttl,
    required this.hits,
  });

  final String domain;
  final String answer;
  final int ttl;
  final int hits;
}

const mockDnsCache = <MockDnsCacheEntry>[
  MockDnsCacheEntry(
    domain: 'api.example.com',
    answer: '10.0.0.12',
    ttl: 292,
    hits: 418,
  ),
  MockDnsCacheEntry(
    domain: 'cdn.example.com',
    answer: '10.0.0.8',
    ttl: 118,
    hits: 302,
  ),
  MockDnsCacheEntry(
    domain: 'img.example.com',
    answer: '10.0.0.9',
    ttl: 64,
    hits: 271,
  ),
  MockDnsCacheEntry(
    domain: 'static.example.com',
    answer: '10.0.0.31',
    ttl: 512,
    hits: 198,
  ),
  MockDnsCacheEntry(
    domain: 'login.example.com',
    answer: '10.0.0.44',
    ttl: 27,
    hits: 96,
  ),
  MockDnsCacheEntry(
    domain: 'mail.example.com',
    answer: '10.0.0.55',
    ttl: 8,
    hits: 41,
  ),
];

/// 上游竞速排行（多路模式）。
class MockRaceEntry {
  const MockRaceEntry({
    required this.provider,
    required this.wins,
    required this.averageLatencyMs,
    required this.failures,
  });

  final String provider;
  final int wins;
  final int averageLatencyMs;
  final int failures;
}

const mockRaceRanking = <MockRaceEntry>[
  MockRaceEntry(
    provider: '阿里公共 DNS',
    wins: 1842,
    averageLatencyMs: 12,
    failures: 0,
  ),
  MockRaceEntry(
    provider: '腾讯 DNSPod',
    wins: 1204,
    averageLatencyMs: 18,
    failures: 2,
  ),
  MockRaceEntry(
    provider: 'Cloudflare',
    wins: 318,
    averageLatencyMs: 96,
    failures: 11,
  ),
  MockRaceEntry(
    provider: 'Google Public DNS',
    wins: 96,
    averageLatencyMs: 142,
    failures: 27,
  ),
];

/// 服务统计（服务器模式 / 日志概览共用）。
class ServiceStats {
  const ServiceStats({
    required this.queries,
    required this.cacheHits,
    required this.blocked,
    required this.averageLatencyMs,
    required this.uptime,
  });

  final int queries;
  final int cacheHits;
  final int blocked;
  final int averageLatencyMs;
  final Duration uptime;

  double get cacheHitRate => queries == 0 ? 0 : cacheHits / queries;

  String get uptimeLabel {
    final hours = uptime.inHours;
    final minutes = uptime.inMinutes % 60;
    final seconds = uptime.inSeconds % 60;
    if (hours > 0) {
      return '$hours小时$minutes分';
    }
    if (minutes > 0) {
      return '$minutes分$seconds秒';
    }
    return '$seconds秒';
  }
}

const mockServiceStats = ServiceStats(
  queries: 28471,
  cacheHits: 21930,
  blocked: 4218,
  averageLatencyMs: 14,
  uptime: Duration(hours: 3, minutes: 42, seconds: 18),
);

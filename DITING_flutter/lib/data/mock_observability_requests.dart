part of 'mock_observability.dart';

/// 一条请求的结果。
enum RequestOutcome {
  success('成功'),
  blocked('已拦截'),
  failed('失败');

  const RequestOutcome(this.label);

  final String label;
}

/// 一条已结束的请求（上游 `requestsProvider` 的 `TrackerInfo`）。
class MockRequest {
  const MockRequest({
    required this.id,
    required this.time,
    required this.host,
    required this.destinationIp,
    required this.outcome,
    required this.latencyMs,
    required this.client,
    required this.rule,
  });

  final String id;
  final String time;
  final String host;
  final String destinationIp;
  final RequestOutcome outcome;
  final int latencyMs;

  /// 发起请求的客户端。
  final String client;
  final String rule;
}

typedef _RequestRow = ({
  String time,
  String host,
  String ip,
  RequestOutcome outcome,
  int latency,
  String client,
  String rule,
});

const _requestRows = <_RequestRow>[
  (
    time: '13:42',
    host: 'api.github.com',
    ip: '140.82.113.6',
    outcome: RequestOutcome.success,
    latency: 84,
    client: '浏览器',
    rule: 'DOMAIN-SUFFIX,github.com',
  ),
  (
    time: '13:41',
    host: 'cdn.jsdelivr.net',
    ip: '151.101.1.229',
    outcome: RequestOutcome.success,
    latency: 132,
    client: '浏览器',
    rule: 'DOMAIN-KEYWORD,jsdelivr',
  ),
  (
    time: '13:41',
    host: 'ads.example.net',
    ip: '0.0.0.0',
    outcome: RequestOutcome.blocked,
    latency: 2,
    client: '浏览器',
    rule: 'RULE-SET,广告拦截',
  ),
  (
    time: '13:40',
    host: 'gateway.discord.gg',
    ip: '162.159.130.234',
    outcome: RequestOutcome.success,
    latency: 186,
    client: '即时通讯',
    rule: 'DOMAIN-SUFFIX,discord.gg',
  ),
  (
    time: '13:39',
    host: 'www.youtube.com',
    ip: '142.250.66.110',
    outcome: RequestOutcome.success,
    latency: 224,
    client: '视频',
    rule: 'GEOSITE,youtube',
  ),
  (
    time: '13:39',
    host: 'tracker.example.org',
    ip: '203.0.113.77',
    outcome: RequestOutcome.blocked,
    latency: 4,
    client: '工具',
    rule: 'DOMAIN-KEYWORD,tracker',
  ),
  (
    time: '13:38',
    host: 'api.telegram.org',
    ip: '149.154.167.51',
    outcome: RequestOutcome.success,
    latency: 96,
    client: '即时通讯',
    rule: 'GEOSITE,telegram',
  ),
  (
    time: '13:37',
    host: 'push.apple.com',
    ip: '17.57.146.20',
    outcome: RequestOutcome.success,
    latency: 42,
    client: '系统服务',
    rule: 'PROCESS-NAME,apsd',
  ),
  (
    time: '13:36',
    host: 'unknown-cdn.example.com',
    ip: '198.51.100.42',
    outcome: RequestOutcome.failed,
    latency: 3000,
    client: '浏览器',
    rule: 'MATCH,自动选择',
  ),
  (
    time: '13:36',
    host: 'i.instagram.com',
    ip: '157.240.11.63',
    outcome: RequestOutcome.success,
    latency: 168,
    client: '社交',
    rule: 'GEOSITE,instagram',
  ),
  (
    time: '13:35',
    host: 'mirrors.aliyun.com',
    ip: '106.11.42.20',
    outcome: RequestOutcome.success,
    latency: 28,
    client: '终端',
    rule: 'DOMAIN-SUFFIX,aliyun.com',
  ),
  (
    time: '13:34',
    host: 'api.openai.com',
    ip: '104.18.6.192',
    outcome: RequestOutcome.success,
    latency: 268,
    client: '效率',
    rule: 'DOMAIN-SUFFIX,openai.com',
  ),
  (
    time: '13:33',
    host: 'www.netflix.com',
    ip: '45.57.0.16',
    outcome: RequestOutcome.success,
    latency: 312,
    client: '视频',
    rule: 'GEOSITE,netflix',
  ),
  (
    time: '13:33',
    host: 'beacon.example.org',
    ip: '0.0.0.0',
    outcome: RequestOutcome.blocked,
    latency: 1,
    client: '系统服务',
    rule: 'RULE-SET,广告拦截',
  ),
  (
    time: '13:32',
    host: 'registry.npmjs.org',
    ip: '104.16.25.34',
    outcome: RequestOutcome.success,
    latency: 214,
    client: '终端',
    rule: 'DOMAIN-SUFFIX,npmjs.org',
  ),
  (
    time: '13:31',
    host: 'music.163.com',
    ip: '59.111.181.31',
    outcome: RequestOutcome.success,
    latency: 36,
    client: '音乐',
    rule: 'DOMAIN-SUFFIX,163.com',
  ),
  (
    time: '13:30',
    host: 'expired.example.com',
    ip: '203.0.113.9',
    outcome: RequestOutcome.failed,
    latency: 1500,
    client: '浏览器',
    rule: 'MATCH,自动选择',
  ),
  (
    time: '13:29',
    host: 'passport.jd.com',
    ip: '211.152.108.24',
    outcome: RequestOutcome.success,
    latency: 22,
    client: '购物',
    rule: 'DOMAIN-SUFFIX,jd.com',
  ),
  (
    time: '13:29',
    host: 'sentry.io',
    ip: '35.186.224.47',
    outcome: RequestOutcome.success,
    latency: 148,
    client: '开发工具',
    rule: 'DOMAIN-SUFFIX,sentry.io',
  ),
  (
    time: '13:28',
    host: 'api.spotify.com',
    ip: '35.186.224.25',
    outcome: RequestOutcome.success,
    latency: 256,
    client: '音乐',
    rule: 'GEOSITE,spotify',
  ),
  (
    time: '13:27',
    host: 'dns.google',
    ip: '8.8.8.8',
    outcome: RequestOutcome.success,
    latency: 68,
    client: '系统服务',
    rule: 'DOMAIN,dns.google',
  ),
  (
    time: '13:26',
    host: 'api.notion.so',
    ip: '104.18.34.126',
    outcome: RequestOutcome.success,
    latency: 174,
    client: '效率',
    rule: 'DOMAIN-SUFFIX,notion.so',
  ),
];

/// 请求明细（时间倒序）。
final mockRequests = <MockRequest>[
  for (final (index, row) in _requestRows.indexed)
    MockRequest(
      id: 'req-${index + 1}',
      time: row.time,
      host: row.host,
      destinationIp: row.ip,
      outcome: row.outcome,
      latencyMs: row.latency,
      client: row.client,
      rule: row.rule,
    ),
];

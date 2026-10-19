part of 'mock_observability.dart';

/// 一条活动连接（上游 `TrackerInfo` + `Metadata` 的拍平等价物）。
///
/// 上游是「外层连接 + 内层元数据」两层结构，这里拍平成一层：列表与详情都按
/// 平铺字段渲染，少一层取值路径。
class MockConnection {
  const MockConnection({
    required this.id,
    required this.host,
    required this.destinationIp,
    required this.destinationPort,
    required this.process,
    required this.network,
    required this.rule,
    required this.rulePayload,
    required this.chains,
    required this.upload,
    required this.download,
    required this.uploadSpeed,
    required this.downloadSpeed,
    required this.startedAt,
    required this.seconds,
    this.geoIp = '中国 香港',
    this.asn = 'AS64500 Example Cloud',
    this.remoteDestination = '',
    this.specialProxy = '',
    this.specialRules = '',
    this.dnsMode = 'fake-ip',
  });

  final String id;
  final String host;
  final String destinationIp;
  final int destinationPort;

  /// 发起连接的应用（演示数据里用中文应用名，不用包名）。
  final String process;

  /// `tcp` / `udp`。
  final String network;
  final String rule;
  final String rulePayload;

  /// 命中规则之后的节点与策略组，按实际走向排列。
  final List<String> chains;

  final int upload;
  final int download;
  final int uploadSpeed;
  final int downloadSpeed;
  final String startedAt;

  /// 已持续秒数。
  final int seconds;

  final String geoIp;
  final String asn;
  final String remoteDestination;
  final String specialProxy;
  final String specialRules;
  final String dnsMode;

  String get endpoint => '$destinationIp:$destinationPort';

  String get ruleText => '$rule,$rulePayload';
}

typedef _ConnectionRow = ({
  String host,
  String ip,
  int port,
  String process,
  String network,
  String rule,
  String payload,
  String chain,
  String group,
  int up,
  int down,
  int seconds,
});

/// 连接明细表。链路固定是「节点 → 策略组」，与上游 `chains` 反序展示一致。
const _connectionRows = <_ConnectionRow>[
  (host: 'api.github.com', ip: '140.82.113.6', port: 443, process: '浏览器',
    network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: 'github.com',
    chain: '香港 01', group: '自动选择', up: 18240, down: 1284302, seconds: 412),
  (host: 'cdn.jsdelivr.net', ip: '151.101.1.229', port: 443, process: '浏览器',
    network: 'tcp', rule: 'DOMAIN-KEYWORD', payload: 'jsdelivr',
    chain: '日本 02', group: '自动选择', up: 9120, down: 4820193, seconds: 236),
  (host: 'gateway.discord.gg', ip: '162.159.130.234', port: 443,
    process: '即时通讯', network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: 'discord.gg',
    chain: '新加坡 01', group: '流媒体', up: 42100, down: 862140, seconds: 731),
  (host: 'www.youtube.com', ip: '142.250.66.110', port: 443, process: '视频',
    network: 'tcp', rule: 'GEOSITE', payload: 'youtube',
    chain: '日本 02', group: '流媒体', up: 68400, down: 15283016, seconds: 1284),
  (host: 'i.instagram.com', ip: '157.240.11.63', port: 443, process: '社交',
    network: 'tcp', rule: 'GEOSITE', payload: 'instagram',
    chain: '香港 03', group: '自动选择', up: 26400, down: 3128450, seconds: 508),
  (host: 'api.telegram.org', ip: '149.154.167.51', port: 443, process: '即时通讯',
    network: 'tcp', rule: 'GEOSITE', payload: 'telegram',
    chain: '香港 01', group: '自动选择', up: 12400, down: 942038, seconds: 196),
  (host: 'steamcdn-a.akamaihd.net', ip: '23.45.76.190', port: 443, process: '游戏',
    network: 'tcp', rule: 'DOMAIN-KEYWORD', payload: 'steam',
    chain: 'DIRECT', group: '直连', up: 30200, down: 8842016, seconds: 942),
  (host: 'mirrors.aliyun.com', ip: '106.11.42.20', port: 443, process: '终端',
    network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: 'aliyun.com',
    chain: 'DIRECT', group: '直连', up: 8010, down: 4210338, seconds: 158),
  (host: 'www.baidu.com', ip: '110.242.68.66', port: 443, process: '浏览器',
    network: 'tcp', rule: 'GEOIP', payload: 'CN',
    chain: 'DIRECT', group: '直连', up: 3420, down: 288401, seconds: 84),
  (host: 'raw.githubusercontent.com', ip: '185.199.108.133', port: 443,
    process: '终端', network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: 'githubusercontent.com',
    chain: '香港 02', group: '自动选择', up: 10240, down: 640228, seconds: 302),
  (host: 'music.163.com', ip: '59.111.181.31', port: 443, process: '音乐',
    network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: '163.com',
    chain: 'DIRECT', group: '直连', up: 2980, down: 1284032, seconds: 764),
  (host: 'api.openai.com', ip: '104.18.6.192', port: 443, process: '效率',
    network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: 'openai.com',
    chain: '美国 01', group: '自动选择', up: 46200, down: 284620, seconds: 58),
  (host: 'push.apple.com', ip: '17.57.146.20', port: 5223, process: '系统服务',
    network: 'tcp', rule: 'PROCESS-NAME', payload: 'apsd',
    chain: 'DIRECT', group: '直连', up: 1820, down: 24108, seconds: 52),
  (host: 'dns.google', ip: '8.8.8.8', port: 853, process: '系统服务',
    network: 'tcp', rule: 'DOMAIN', payload: 'dns.google',
    chain: '香港 02', group: '自动选择', up: 4200, down: 9840, seconds: 38),
  (host: 'www.netflix.com', ip: '45.57.0.16', port: 443, process: '视频',
    network: 'tcp', rule: 'GEOSITE', payload: 'netflix',
    chain: '新加坡 01', group: '流媒体', up: 52100, down: 9840220, seconds: 1520),
  (host: 'chat.openai.com', ip: '104.18.7.192', port: 443, process: '浏览器',
    network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: 'openai.com',
    chain: '美国 01', group: '自动选择', up: 38400, down: 1420386, seconds: 421),
  (host: 'sentry.io', ip: '35.186.224.47', port: 443, process: '开发工具',
    network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: 'sentry.io',
    chain: '香港 01', group: '自动选择', up: 6200, down: 84028, seconds: 96),
  (host: 'fonts.gstatic.com', ip: '142.250.66.131', port: 443, process: '浏览器',
    network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: 'gstatic.com',
    chain: '日本 02', group: '自动选择', up: 3480, down: 620144, seconds: 214),
  (host: 'api.spotify.com', ip: '35.186.224.25', port: 443, process: '音乐',
    network: 'tcp', rule: 'GEOSITE', payload: 'spotify',
    chain: '美国 02', group: '流媒体', up: 12400, down: 482011, seconds: 348),
  (host: 'passport.jd.com', ip: '211.152.108.24', port: 443, process: '购物',
    network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: 'jd.com',
    chain: 'DIRECT', group: '直连', up: 2840, down: 96240, seconds: 46),
  (host: 'registry.npmjs.org', ip: '104.16.25.34', port: 443, process: '终端',
    network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: 'npmjs.org',
    chain: '香港 03', group: '自动选择', up: 9640, down: 3410284, seconds: 622),
  (host: 'cloudflare-dns.com', ip: '1.1.1.1', port: 853, process: '系统服务',
    network: 'tcp', rule: 'DOMAIN', payload: 'cloudflare-dns.com',
    chain: '香港 01', group: '自动选择', up: 3200, down: 12044, seconds: 30),
  (host: 'update.googleapis.com', ip: '142.250.66.202', port: 443,
    process: '系统服务', network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: 'googleapis.com',
    chain: 'DIRECT', group: '直连', up: 1420, down: 18420, seconds: 24),
  (host: 'tracker.example.org', ip: '203.0.113.77', port: 8443, process: '工具',
    network: 'udp', rule: 'DOMAIN-KEYWORD', payload: 'tracker',
    chain: 'REJECT', group: '拦截', up: 620, down: 0, seconds: 6),
  (host: 'ads.example.net', ip: '198.51.100.9', port: 443, process: '浏览器',
    network: 'tcp', rule: 'RULE-SET', payload: '广告拦截',
    chain: 'REJECT', group: '拦截', up: 480, down: 0, seconds: 3),
  (host: 'edge.microsoft.com', ip: '13.107.42.14', port: 443, process: '浏览器',
    network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: 'microsoft.com',
    chain: 'DIRECT', group: '直连', up: 2140, down: 428016, seconds: 132),
  (host: 'static.zhihu.com', ip: '118.89.204.19', port: 443, process: '浏览器',
    network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: 'zhihu.com',
    chain: 'DIRECT', group: '直连', up: 1840, down: 962048, seconds: 264),
  (host: 'api.notion.so', ip: '104.18.34.126', port: 443, process: '效率',
    network: 'tcp', rule: 'DOMAIN-SUFFIX', payload: 'notion.so',
    chain: '香港 02', group: '自动选择', up: 8420, down: 284620, seconds: 188),
];

/// 观测快照的「现在」。所有 `startedAt` 都由它减去已持续秒数得到——写死的
/// 时间字面量没法跟 `seconds` 对上，一眼就能看出是假数据。
final _observedAt = DateTime(2026, 10, 19, 13, 42, 8);

String _startedAt(int seconds) {
  final start = _observedAt.subtract(Duration(seconds: seconds));
  String two(int value) => value.toString().padLeft(2, '0');
  return '${start.year}-${two(start.month)}-${two(start.day)} '
      '${two(start.hour)}:${two(start.minute)}:${two(start.second)}';
}

/// 当前连接列表。
final mockConnections = <MockConnection>[
  for (final (index, row) in _connectionRows.indexed)
    MockConnection(
      id: 'conn-${index + 1}',
      host: row.host,
      destinationIp: row.ip,
      destinationPort: row.port,
      process: row.process,
      network: row.network,
      rule: row.rule,
      rulePayload: row.payload,
      chains: [row.chain, row.group],
      upload: row.up,
      download: row.down,
      uploadSpeed: row.seconds == 0 ? 0 : row.up ~/ row.seconds,
      downloadSpeed: row.seconds == 0 ? 0 : row.down ~/ row.seconds,
      startedAt: _startedAt(row.seconds),
      seconds: row.seconds,
      // 被拦截的连接没有真实远端：留空，详情里就不会出现一行假的「远端目标」。
      remoteDestination: row.chain == 'REJECT' ? '' : '${row.ip}:${row.port}',
    ),
];

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
  (time: '13:42', host: 'api.github.com', ip: '140.82.113.6',
    outcome: RequestOutcome.success, latency: 84, client: '浏览器',
    rule: 'DOMAIN-SUFFIX,github.com'),
  (time: '13:41', host: 'cdn.jsdelivr.net', ip: '151.101.1.229',
    outcome: RequestOutcome.success, latency: 132, client: '浏览器',
    rule: 'DOMAIN-KEYWORD,jsdelivr'),
  (time: '13:41', host: 'ads.example.net', ip: '0.0.0.0',
    outcome: RequestOutcome.blocked, latency: 2, client: '浏览器',
    rule: 'RULE-SET,广告拦截'),
  (time: '13:40', host: 'gateway.discord.gg', ip: '162.159.130.234',
    outcome: RequestOutcome.success, latency: 186, client: '即时通讯',
    rule: 'DOMAIN-SUFFIX,discord.gg'),
  (time: '13:39', host: 'www.youtube.com', ip: '142.250.66.110',
    outcome: RequestOutcome.success, latency: 224, client: '视频',
    rule: 'GEOSITE,youtube'),
  (time: '13:39', host: 'tracker.example.org', ip: '203.0.113.77',
    outcome: RequestOutcome.blocked, latency: 4, client: '工具',
    rule: 'DOMAIN-KEYWORD,tracker'),
  (time: '13:38', host: 'api.telegram.org', ip: '149.154.167.51',
    outcome: RequestOutcome.success, latency: 96, client: '即时通讯',
    rule: 'GEOSITE,telegram'),
  (time: '13:37', host: 'push.apple.com', ip: '17.57.146.20',
    outcome: RequestOutcome.success, latency: 42, client: '系统服务',
    rule: 'PROCESS-NAME,apsd'),
  (time: '13:36', host: 'unknown-cdn.example.com', ip: '198.51.100.42',
    outcome: RequestOutcome.failed, latency: 3000, client: '浏览器',
    rule: 'MATCH,自动选择'),
  (time: '13:36', host: 'i.instagram.com', ip: '157.240.11.63',
    outcome: RequestOutcome.success, latency: 168, client: '社交',
    rule: 'GEOSITE,instagram'),
  (time: '13:35', host: 'mirrors.aliyun.com', ip: '106.11.42.20',
    outcome: RequestOutcome.success, latency: 28, client: '终端',
    rule: 'DOMAIN-SUFFIX,aliyun.com'),
  (time: '13:34', host: 'api.openai.com', ip: '104.18.6.192',
    outcome: RequestOutcome.success, latency: 268, client: '效率',
    rule: 'DOMAIN-SUFFIX,openai.com'),
  (time: '13:33', host: 'www.netflix.com', ip: '45.57.0.16',
    outcome: RequestOutcome.success, latency: 312, client: '视频',
    rule: 'GEOSITE,netflix'),
  (time: '13:33', host: 'beacon.example.org', ip: '0.0.0.0',
    outcome: RequestOutcome.blocked, latency: 1, client: '系统服务',
    rule: 'RULE-SET,广告拦截'),
  (time: '13:32', host: 'registry.npmjs.org', ip: '104.16.25.34',
    outcome: RequestOutcome.success, latency: 214, client: '终端',
    rule: 'DOMAIN-SUFFIX,npmjs.org'),
  (time: '13:31', host: 'music.163.com', ip: '59.111.181.31',
    outcome: RequestOutcome.success, latency: 36, client: '音乐',
    rule: 'DOMAIN-SUFFIX,163.com'),
  (time: '13:30', host: 'expired.example.com', ip: '203.0.113.9',
    outcome: RequestOutcome.failed, latency: 1500, client: '浏览器',
    rule: 'MATCH,自动选择'),
  (time: '13:29', host: 'passport.jd.com', ip: '211.152.108.24',
    outcome: RequestOutcome.success, latency: 22, client: '购物',
    rule: 'DOMAIN-SUFFIX,jd.com'),
  (time: '13:29', host: 'sentry.io', ip: '35.186.224.47',
    outcome: RequestOutcome.success, latency: 148, client: '开发工具',
    rule: 'DOMAIN-SUFFIX,sentry.io'),
  (time: '13:28', host: 'api.spotify.com', ip: '35.186.224.25',
    outcome: RequestOutcome.success, latency: 256, client: '音乐',
    rule: 'GEOSITE,spotify'),
  (time: '13:27', host: 'dns.google', ip: '8.8.8.8',
    outcome: RequestOutcome.success, latency: 68, client: '系统服务',
    rule: 'DOMAIN,dns.google'),
  (time: '13:26', host: 'api.notion.so', ip: '104.18.34.126',
    outcome: RequestOutcome.success, latency: 174, client: '效率',
    rule: 'DOMAIN-SUFFIX,notion.so'),
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


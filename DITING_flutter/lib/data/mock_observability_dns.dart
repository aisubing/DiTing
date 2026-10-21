part of 'mock_observability.dart';

/// DNS 记录类型。展示一律用 [label]，不要插值枚举名。
enum DnsRecordType {
  a('A'),
  aaaa('AAAA'),
  cname('CNAME'),
  https('HTTPS'),
  txt('TXT');

  const DnsRecordType(this.label);

  final String label;
}

/// 一次 DNS 查询的结果。
enum DnsOutcome {
  ok('成功'),
  cached('缓存命中'),
  servfail('SERVFAIL'),
  nxdomain('NXDOMAIN'),
  timeout('超时');

  const DnsOutcome(this.label);

  final String label;

  /// 失败态：列表里用 error 色 + 警告图标，而不是普通结果的灰字。
  bool get isFailure =>
      this == DnsOutcome.servfail ||
      this == DnsOutcome.nxdomain ||
      this == DnsOutcome.timeout;
}

/// 一条 DNS 查询记录。
class MockDnsQuery {
  const MockDnsQuery({
    required this.id,
    required this.time,
    required this.domain,
    required this.type,
    required this.outcome,
    required this.latencyMs,
    required this.source,
    required this.ttlSeconds,
    required this.answers,
    required this.hops,
    this.error,
  });

  final String id;
  final String time;
  final String domain;
  final DnsRecordType type;
  final DnsOutcome outcome;
  final int latencyMs;

  /// 实际应答的上游（并发竞速时可能不是首选上游）。
  final String source;
  final int ttlSeconds;

  /// 应答记录；失败查询为空。
  final List<String> answers;

  /// 查询链路：发起 → 缓存 → 上游 → 应答。
  final List<String> hops;
  final String? error;

  bool get cached => outcome == DnsOutcome.cached;

  bool get isFailure => outcome.isFailure;
}

typedef _DnsRow = ({
  String time,
  String domain,
  DnsRecordType type,
  DnsOutcome outcome,
  int latency,
  String source,
  int ttl,
  List<String> answers,
});

const _dnsRows = <_DnsRow>[
  (
    time: '13:42:08',
    domain: 'api.github.com',
    type: DnsRecordType.a,
    outcome: DnsOutcome.cached,
    latency: 0,
    source: '缓存',
    ttl: 184,
    answers: ['140.82.113.6'],
  ),
  (
    time: '13:42:03',
    domain: 'cdn.jsdelivr.net',
    type: DnsRecordType.a,
    outcome: DnsOutcome.ok,
    latency: 28,
    source: '阿里 DoH',
    ttl: 60,
    answers: ['151.101.1.229', '151.101.65.229'],
  ),
  (
    time: '13:41:57',
    domain: 'gateway.discord.gg',
    type: DnsRecordType.a,
    outcome: DnsOutcome.ok,
    latency: 132,
    source: 'Cloudflare DoH',
    ttl: 30,
    answers: ['162.159.130.234'],
  ),
  (
    time: '13:41:52',
    domain: 'www.youtube.com',
    type: DnsRecordType.https,
    outcome: DnsOutcome.ok,
    latency: 96,
    source: 'Google DoH',
    ttl: 300,
    answers: ['alpn=h2,h3 port=443'],
  ),
  (
    time: '13:41:44',
    domain: 'tracker.example.org',
    type: DnsRecordType.a,
    outcome: DnsOutcome.nxdomain,
    latency: 42,
    source: '阿里 DoH',
    ttl: 0,
    answers: [],
  ),
  (
    time: '13:41:39',
    domain: 'i.instagram.com',
    type: DnsRecordType.a,
    outcome: DnsOutcome.cached,
    latency: 0,
    source: '缓存',
    ttl: 96,
    answers: ['157.240.11.63'],
  ),
  (
    time: '13:41:31',
    domain: 'slow-upstream.example.net',
    type: DnsRecordType.a,
    outcome: DnsOutcome.timeout,
    latency: 2000,
    source: '自建 DoH',
    ttl: 0,
    answers: [],
  ),
  (
    time: '13:41:22',
    domain: 'api.telegram.org',
    type: DnsRecordType.a,
    outcome: DnsOutcome.ok,
    latency: 64,
    source: 'Cloudflare DoH',
    ttl: 60,
    answers: ['149.154.167.51'],
  ),
  (
    time: '13:41:18',
    domain: 'mirrors.aliyun.com',
    type: DnsRecordType.cname,
    outcome: DnsOutcome.ok,
    latency: 12,
    source: '阿里 DoH',
    ttl: 600,
    answers: ['mirrors.aliyun.com.w.alikunlun.com'],
  ),
  (
    time: '13:41:09',
    domain: 'broken-dns.example.org',
    type: DnsRecordType.aaaa,
    outcome: DnsOutcome.servfail,
    latency: 286,
    source: '自建 DoH',
    ttl: 0,
    answers: [],
  ),
  (
    time: '13:41:02',
    domain: 'api.openai.com',
    type: DnsRecordType.a,
    outcome: DnsOutcome.ok,
    latency: 118,
    source: 'Cloudflare DoH',
    ttl: 30,
    answers: ['104.18.6.192'],
  ),
  (
    time: '13:40:56',
    domain: 'fonts.gstatic.com',
    type: DnsRecordType.a,
    outcome: DnsOutcome.cached,
    latency: 0,
    source: '缓存',
    ttl: 42,
    answers: ['142.250.66.131'],
  ),
  (
    time: '13:40:44',
    domain: 'www.netflix.com',
    type: DnsRecordType.a,
    outcome: DnsOutcome.ok,
    latency: 88,
    source: 'Google DoH',
    ttl: 60,
    answers: ['45.57.0.16'],
  ),
  (
    time: '13:40:31',
    domain: 'nonexistent.domain.test',
    type: DnsRecordType.a,
    outcome: DnsOutcome.nxdomain,
    latency: 18,
    source: '阿里 DoH',
    ttl: 0,
    answers: [],
  ),
  (
    time: '13:40:24',
    domain: 'music.163.com',
    type: DnsRecordType.a,
    outcome: DnsOutcome.ok,
    latency: 16,
    source: '阿里 DoH',
    ttl: 120,
    answers: ['59.111.181.31'],
  ),
  (
    time: '13:40:15',
    domain: 'registry.npmjs.org',
    type: DnsRecordType.a,
    outcome: DnsOutcome.ok,
    latency: 74,
    source: 'Cloudflare DoH',
    ttl: 30,
    answers: ['104.16.25.34'],
  ),
  (
    time: '13:40:08',
    domain: 'dns.google',
    type: DnsRecordType.txt,
    outcome: DnsOutcome.ok,
    latency: 26,
    source: 'Google DoH',
    ttl: 300,
    answers: ['"v=spf1 -all"'],
  ),
  (
    time: '13:39:58',
    domain: 'expired.example.com',
    type: DnsRecordType.a,
    outcome: DnsOutcome.timeout,
    latency: 2000,
    source: '自建 DoH',
    ttl: 0,
    answers: [],
  ),
  (
    time: '13:39:47',
    domain: 'passport.jd.com',
    type: DnsRecordType.a,
    outcome: DnsOutcome.cached,
    latency: 0,
    source: '缓存',
    ttl: 240,
    answers: ['211.152.108.24'],
  ),
  (
    time: '13:39:38',
    domain: 'api.spotify.com',
    type: DnsRecordType.aaaa,
    outcome: DnsOutcome.ok,
    latency: 102,
    source: 'Cloudflare DoH',
    ttl: 60,
    answers: ['2600:1901:0:7a7d::'],
  ),
  (
    time: '13:39:26',
    domain: 'sentry.io',
    type: DnsRecordType.a,
    outcome: DnsOutcome.ok,
    latency: 58,
    source: 'Cloudflare DoH',
    ttl: 120,
    answers: ['35.186.224.47'],
  ),
  (
    time: '13:39:17',
    domain: 'cloudflare-dns.com',
    type: DnsRecordType.https,
    outcome: DnsOutcome.cached,
    latency: 0,
    source: '缓存',
    ttl: 300,
    answers: ['alpn=h3 port=443'],
  ),
];

/// DNS 查询记录（时间倒序，含 6 条失败：超时 / SERVFAIL / NXDOMAIN）。
final mockDnsQueries = <MockDnsQuery>[
  for (final (index, row) in _dnsRows.indexed)
    MockDnsQuery(
      id: 'dns-${index + 1}',
      time: '2026-10-19 ${row.time}',
      domain: row.domain,
      type: row.type,
      outcome: row.outcome,
      latencyMs: row.latency,
      source: row.source,
      ttlSeconds: row.ttl,
      answers: row.answers,
      hops: [
        '客户端发起 · ${row.type.label} 查询',
        row.outcome == DnsOutcome.cached ? '内存缓存命中' : '缓存未命中',
        switch (row.outcome) {
          DnsOutcome.cached => '无需上游',
          DnsOutcome.timeout => '${row.source} · 2000 ms 超时',
          _ => '${row.source} · ${row.latency} ms',
        },
        if (row.outcome == DnsOutcome.cached) '返回缓存记录' else '返回并写入缓存',
      ],
      error: switch (row.outcome) {
        DnsOutcome.timeout => '上游 2000 ms 内未返回，已回退到下一个上游。',
        DnsOutcome.servfail => '上游返回 SERVFAIL：域名服务器内部错误。',
        DnsOutcome.nxdomain => '域名不存在（NXDOMAIN），可能是拼写错误或已过期。',
        _ => null,
      },
    ),
];

/// IP 质量来源的一条结果。
///
/// 名字带 `Observed` 前缀：`mock_forms.dart` 里已有一个 IP 质量演示模型，两个
/// 库同时被引用时不至于撞名。
class MockObservedIpSource {
  const MockObservedIpSource({
    required this.name,
    required this.status,
    this.detail,
    this.latencyMs,
  });

  final String name;

  /// 命中 / 超时 / 限流 / 失败。
  final String status;
  final String? detail;
  final int? latencyMs;
}

/// IP 质量快照（DNS 页「IP 质量」入口的演示浮层）。
class MockObservedIpQuality {
  const MockObservedIpQuality({
    required this.ip,
    required this.ipType,
    required this.level,
    required this.organization,
    required this.asn,
    required this.checkedAt,
    required this.sources,
  });

  final String ip;

  /// 住宅 / 移动 / 商业 / 机房。
  final String ipType;

  /// 优秀 / 一般 / 风险。
  final String level;
  final String organization;
  final String asn;
  final String checkedAt;
  final List<MockObservedIpSource> sources;
}

/// DNS 页浮层用的演示快照：故意给出「机房 + 风险」，这样等级色与来源失败都
/// 能在一次演示里同时看到。
const mockObservedIpQuality = MockObservedIpQuality(
  ip: '203.0.113.24',
  ipType: '机房',
  level: '风险',
  organization: 'Example Hosting Ltd.',
  asn: 'AS64500 Example Cloud',
  checkedAt: '2026-10-19 13:38',
  sources: [
    MockObservedIpSource(
      name: 'ipinfo.io',
      status: '命中',
      detail: '机房',
      latencyMs: 182,
    ),
    MockObservedIpSource(
      name: 'ipapi.com',
      status: '命中',
      detail: '机房',
      latencyMs: 264,
    ),
    MockObservedIpSource(name: 'scamalytics', status: '限流'),
    MockObservedIpSource(name: 'whois.example.com', status: '超时'),
  ],
);

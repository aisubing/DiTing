part of 'mock_data.dart';

enum ProviderProtocol {
  dns('DNS'),
  doh('DoH'),
  dot('DoT');

  const ProviderProtocol(this.label);

  final String label;
}

class MockProvider {
  const MockProvider({
    required this.id,
    required this.name,
    required this.protocol,
    required this.address,
    required this.latencyMs,
    this.isPreset = false,
    this.isEnabled = true,
  });

  final String id;
  final String name;
  final ProviderProtocol protocol;
  final String address;
  final int latencyMs;

  /// Built-in providers cannot be edited or deleted.
  final bool isPreset;

  final bool isEnabled;
}

const mockProviders = <MockProvider>[
  MockProvider(
    id: 'ali',
    name: '阿里公共 DNS',
    protocol: ProviderProtocol.doh,
    address: 'https://dns.alidns.com/dns-query',
    latencyMs: 12,
    isPreset: true,
  ),
  MockProvider(
    id: 'tencent',
    name: '腾讯 DNSPod',
    protocol: ProviderProtocol.doh,
    address: 'https://doh.pub/dns-query',
    latencyMs: 18,
    isPreset: true,
  ),
  MockProvider(
    id: 'dnspod-dot',
    name: 'DNSPod DoT',
    protocol: ProviderProtocol.dot,
    address: 'dot.pub:853',
    latencyMs: 24,
    isPreset: true,
  ),
  MockProvider(
    id: 'cloudflare',
    name: 'Cloudflare',
    protocol: ProviderProtocol.doh,
    address: 'https://cloudflare-dns.com/dns-query',
    latencyMs: 96,
    isPreset: true,
  ),
  MockProvider(
    id: 'google',
    name: 'Google Public DNS',
    protocol: ProviderProtocol.doh,
    address: 'https://dns.google/dns-query',
    latencyMs: 142,
    isPreset: true,
  ),
  MockProvider(
    id: 'local',
    name: '本地递归（dnsmasq）',
    protocol: ProviderProtocol.dns,
    address: '192.168.1.1:53',
    latencyMs: 6,
  ),
];

enum RuleKind {
  block('黑名单', '拦截匹配的域名', 'rules'),
  allow('白名单', '放行匹配的域名', 'checkCircle'),
  rewrite('覆写', '改写域名解析结果', 'swap');

  const RuleKind(this.title, this.summary, this.glyphName);

  final String title;
  final String summary;

  /// Same names as `AppGlyphs` constants; the page maps them to a Glyph.
  final String glyphName;
}

enum RuleSource {
  user('用户自定义'),
  subscription('规则订阅'),
  preset('内置预设');

  const RuleSource(this.label);

  final String label;
}

class MockRule {
  const MockRule({
    required this.id,
    required this.pattern,
    required this.kind,
    required this.source,
    this.enabled = true,
    this.important = false,
    this.group,
    this.subscriptionName,
    this.target,
    this.appScope,
    this.appInverted = false,
  });

  final String id;
  final String pattern;
  final RuleKind kind;
  final RuleSource source;
  final bool enabled;
  final bool important;
  final String? group;
  final String? subscriptionName;

  final String? target;

  /// `appScope` column, a `~`-separated package list, empty for global. Must reach the engine as
  /// `appRules[pkg].block`, never `globalBlock`.
  final String? appScope;

  /// Inverted app exclusion: packages in `appScope` are never blocked.
  final bool appInverted;

  MockRule copyWith({bool? enabled, bool? important}) {
    return MockRule(
      id: id,
      pattern: pattern,
      kind: kind,
      source: source,
      enabled: enabled ?? this.enabled,
      important: important ?? this.important,
      group: group,
      subscriptionName: subscriptionName,
      target: target,
      appScope: appScope,
      appInverted: appInverted,
    );
  }
}

const _blockPatterns = <String>[
  '||ads.example.com^',
  '||tracker.example.net^',
  '||metrics.example.org^',
  '||beacon.example.io^',
  '||analytics.example.cn^',
  '||promo.example.com^',
  '||cdn-ads.example.net^',
  '||telemetry.example.org^',
  '||push.example.io^',
  '||adserver.example.cn^',
  '||sponsor.example.com^',
  '||banner.example.net^',
];

const _allowPatterns = <String>[
  '||api.example.com^',
  '||login.example.com^',
  '||pay.example.com^',
  '||static.example.com^',
  '||docs.example.com^',
  '||mail.example.com^',
];

const _rewritePatterns = <(String, String)>[
  ('cdn.example.com', '10.0.0.8'),
  ('img.example.com', '10.0.0.9'),
  ('v6.example.com', '2001:db8::1'),
  ('alias.example.com', 'origin.example.com'),
  ('api.example.com', '192.168.1.20'),
];

final mockBlockRules = <MockRule>[
  for (var i = 0; i < _blockPatterns.length; i++)
    MockRule(
      id: 'block-$i',
      pattern: _blockPatterns[i],
      kind: RuleKind.block,
      source: i < 9
          ? RuleSource.user
          : i < 12
          ? RuleSource.subscription
          : RuleSource.preset,
      enabled: i % 7 != 3,
      important: i % 5 == 0,
      subscriptionName: i >= 9 && i < 12 ? 'AdGuard 基础' : null,
      group: i % 4 == 0 ? '广告' : null,
    ),
];

final mockAllowRules = <MockRule>[
  for (var i = 0; i < _allowPatterns.length; i++)
    MockRule(
      id: 'allow-$i',
      pattern: _allowPatterns[i],
      kind: RuleKind.allow,
      source: i < 4 ? RuleSource.user : RuleSource.preset,
      enabled: i != 2,
      group: i < 2 ? '支付' : null,
    ),
];

final mockRewriteRules = <MockRule>[
  for (var i = 0; i < _rewritePatterns.length; i++)
    MockRule(
      id: 'rewrite-$i',
      pattern: _rewritePatterns[i].$1,
      kind: RuleKind.rewrite,
      source: i < 3 ? RuleSource.user : RuleSource.subscription,
      target: _rewritePatterns[i].$2,
      enabled: i != 4,
      subscriptionName: i >= 3 ? '内网加速' : null,
    ),
];

List<MockRule> mockRulesOf(RuleKind kind) => switch (kind) {
  RuleKind.block => mockBlockRules,
  RuleKind.allow => mockAllowRules,
  RuleKind.rewrite => mockRewriteRules,
};

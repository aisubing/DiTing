part of 'mock_observability.dart';

/// 资源种类。分组标题直接用 [label]。
enum ObsResourceKind {
  geoData('GeoData', '本机 GeoIP / GeoSite 数据文件'),
  iconSet('图标集', '策略组与节点图标'),
  ruleProvider('规则提供者', '远程规则集（RULE-SET）'),
  script('脚本', '覆写脚本与助手脚本');

  const ObsResourceKind(this.label, this.description);

  final String label;
  final String description;
}

/// 一个可刷新的资源。
class MockObsResource {
  const MockObsResource({
    required this.id,
    required this.kind,
    required this.name,
    required this.url,
    required this.updatedAt,
    required this.sizeBytes,
    required this.lineCount,
    required this.defaultUrl,
  });

  final String id;
  final ObsResourceKind kind;
  final String name;
  final String url;
  final String updatedAt;
  final int sizeBytes;

  /// 规则 / 图标条数；详情里作为「内容量」显示。
  final int lineCount;

  /// 「重置为默认地址」用的原始地址。
  final String defaultUrl;
}

typedef _ResourceRow = ({
  String name,
  String url,
  String updated,
  int size,
  int lines,
});

const _geoRows = <_ResourceRow>[
  (name: 'GeoIP.dat', url: 'https://cdn.example.com/geo/geoip.dat',
    updated: '2026-10-17 04:12', size: 8421376, lines: 0),
  (name: 'GeoSite.dat', url: 'https://cdn.example.com/geo/geosite.dat',
    updated: '2026-10-17 04:12', size: 3248128, lines: 0),
  (name: 'Country.mmdb', url: 'https://cdn.example.com/geo/country.mmdb',
    updated: '2026-10-16 22:38', size: 6140928, lines: 0),
  (name: 'ASN.mmdb', url: 'https://cdn.example.com/geo/asn.mmdb',
    updated: '2026-10-16 22:38', size: 4182016, lines: 0),
];

const _iconRows = <_ResourceRow>[
  (name: 'Clash 官方图标集', url: 'https://cdn.example.com/icons/clash.json',
    updated: '2026-10-18 11:04', size: 284160, lines: 412),
  (name: '常用机场图标', url: 'https://cdn.example.com/icons/airport.json',
    updated: '2026-10-15 09:26', size: 124032, lines: 168),
  (name: '国家与地区旗帜', url: 'https://cdn.example.com/icons/flags.json',
    updated: '2026-10-12 18:42', size: 96408, lines: 248),
];

const _ruleProviderRows = <_ResourceRow>[
  (name: '广告拦截规则集', url: 'https://cdn.example.com/rules/adblock.yaml',
    updated: '2026-10-18 07:20', size: 1842016, lines: 48213),
  (name: '直连域名集', url: 'https://cdn.example.com/rules/direct.yaml',
    updated: '2026-10-18 07:20', size: 962048, lines: 12870),
  (name: '流媒体分流集', url: 'https://cdn.example.com/rules/streaming.yaml',
    updated: '2026-10-16 13:02', size: 342016, lines: 3820),
  (name: '自定义规则集', url: 'https://cdn.example.com/rules/custom.yaml',
    updated: '2026-10-11 21:02', size: 42016, lines: 731),
];

const _scriptRows = <_ResourceRow>[
  (name: '覆写脚本 · 增强', url: 'https://cdn.example.com/js/override.js',
    updated: '2026-10-14 15:36', size: 82016, lines: 1240),
  (name: '节点测速助手', url: 'https://cdn.example.com/js/speedtest.js',
    updated: '2026-10-09 10:18', size: 42016, lines: 486),
  (name: 'DNS 修复脚本', url: 'https://cdn.example.com/js/fix-dns.js',
    updated: '2026-09-28 20:44', size: 18408, lines: 214),
];

List<MockObsResource> _resourcesOf(
  ObsResourceKind kind,
  String prefix,
  List<_ResourceRow> rows,
) => [
  for (final (index, row) in rows.indexed)
    MockObsResource(
      id: '$prefix-${index + 1}',
      kind: kind,
      name: row.name,
      url: row.url,
      updatedAt: row.updated,
      sizeBytes: row.size,
      lineCount: row.lines,
      defaultUrl: row.url,
    ),
];

/// 四类资源，按页面分组顺序排列。
final mockObsResources = <MockObsResource>[
  ..._resourcesOf(ObsResourceKind.geoData, 'geo', _geoRows),
  ..._resourcesOf(ObsResourceKind.iconSet, 'icon', _iconRows),
  ..._resourcesOf(ObsResourceKind.ruleProvider, 'rule', _ruleProviderRows),
  ..._resourcesOf(ObsResourceKind.script, 'script', _scriptRows),
];

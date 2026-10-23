/// Proxy demo data: groups, nodes, external providers. Separate library because this domain sorts
/// by latency and filters by timeout.
library;

enum ProxyProtocol {
  ss('Shadowsocks'),
  vmess('VMess'),
  trojan('Trojan'),
  hysteria2('Hysteria2'),
  direct('直连'),
  reject('拒绝');

  const ProxyProtocol(this.label);

  final String label;
}

enum ProxiesType {
  tab('标签页'),
  list('列表');

  const ProxiesType(this.label);

  final String label;
}

enum ProxiesSortType {
  none('默认'),
  delay('延迟'),
  name('名称');

  const ProxiesSortType(this.label);

  final String label;
}

enum ProxiesLayout {
  tight('紧凑'),
  standard('标准'),
  loose('宽松');

  const ProxiesLayout(this.label);

  final String label;
}

enum ProxyCardType {
  loose('宽松'),
  standard('标准'),
  compact('紧凑');

  const ProxyCardType(this.label);

  final String label;
}

enum ProxiesIconStyle {
  filled('色块'),
  plain('纯图标'),
  hidden('隐藏');

  const ProxiesIconStyle(this.label);

  final String label;
}

enum ProxyGroupType {
  selector('select', '手动选择', true),
  urlTest('url-test', '自动测速', true),
  fallback('fallback', '故障转移', true),
  loadBalance('load-balance', '负载均衡', false),
  relay('relay', '链式代理', false);

  const ProxyGroupType(this.raw, this.label, this.isComputedSelected);

  /// Raw type name from the mihomo config, used when aligning with it.
  final String raw;

  final String label;

  /// Only these groups' in-group choice is the user's "current node".
  final bool isComputedSelected;
}

class MockProxy {
  const MockProxy({required this.name, required this.protocol, this.delayMs});

  final String name;
  final ProxyProtocol protocol;

  /// Last latency test: null is untested, negative means timeout.
  final int? delayMs;
}

class MockProxyGroup {
  const MockProxyGroup({
    required this.name,
    required this.type,
    required this.glyphName,
    required this.proxies,
    this.selectedName,
  });

  final String name;
  final ProxyGroupType type;

  /// List-layout icon name, resolved in `lib/widgets/glyph_lookup.dart`.
  final String glyphName;

  final List<MockProxy> proxies;

  final String? selectedName;
}

/// Probe URL (upstream default `https://www.gstatic.com/generate_204`).
const mockProxyTestUrl = 'https://www.gstatic.com/generate_204';

const mockProxyGroups = <MockProxyGroup>[
  MockProxyGroup(
    name: '🚀 节点选择',
    type: ProxyGroupType.selector,
    glyphName: 'send',
    selectedName: '🇭🇰 香港 01',
    proxies: [
      MockProxy(name: '🇭🇰 香港 01', protocol: ProxyProtocol.ss, delayMs: 42),
      MockProxy(name: '🇭🇰 香港 02', protocol: ProxyProtocol.ss, delayMs: 88),
      MockProxy(
        name: '🇯🇵 日本 01',
        protocol: ProxyProtocol.vmess,
        delayMs: 136,
      ),
      MockProxy(
        name: '🇯🇵 日本 02',
        protocol: ProxyProtocol.vmess,
        delayMs: 158,
      ),
      MockProxy(
        name: '🇸🇬 新加坡 01',
        protocol: ProxyProtocol.trojan,
        delayMs: 96,
      ),
      MockProxy(
        name: '🇺🇸 美国 01',
        protocol: ProxyProtocol.hysteria2,
        delayMs: 212,
      ),
      MockProxy(
        name: '🇺🇸 美国 02',
        protocol: ProxyProtocol.hysteria2,
        delayMs: 468,
      ),
      MockProxy(
        name: '🇩🇪 德国 01',
        protocol: ProxyProtocol.trojan,
        delayMs: -1,
      ),
      MockProxy(name: '🇬🇧 英国 01', protocol: ProxyProtocol.ss),
    ],
  ),
  MockProxyGroup(
    name: '♻️ 自动选择',
    type: ProxyGroupType.urlTest,
    glyphName: 'bolt',
    selectedName: '香港专线',
    proxies: [
      MockProxy(name: '香港专线', protocol: ProxyProtocol.ss, delayMs: 58),
      MockProxy(name: '日本专线', protocol: ProxyProtocol.vmess, delayMs: 124),
      MockProxy(name: '新加坡专线', protocol: ProxyProtocol.trojan, delayMs: 168),
      MockProxy(name: '美国专线', protocol: ProxyProtocol.hysteria2, delayMs: 264),
      MockProxy(name: '负载均衡', protocol: ProxyProtocol.ss, delayMs: 312),
      MockProxy(name: '备用线路', protocol: ProxyProtocol.ss, delayMs: -1),
    ],
  ),
  MockProxyGroup(
    name: '🌍 国外流量',
    type: ProxyGroupType.selector,
    glyphName: 'layers',
    selectedName: '美国 洛杉矶',
    proxies: [
      MockProxy(name: '美国 洛杉矶', protocol: ProxyProtocol.vmess, delayMs: 198),
      MockProxy(name: '美国 圣何塞', protocol: ProxyProtocol.ss, delayMs: 246),
      MockProxy(name: '荷兰 阿姆斯特丹', protocol: ProxyProtocol.trojan, delayMs: 332),
      MockProxy(name: '英国 伦敦', protocol: ProxyProtocol.ss, delayMs: 412),
      MockProxy(name: '法国 巴黎', protocol: ProxyProtocol.vmess, delayMs: -1),
    ],
  ),
  MockProxyGroup(
    name: '🎬 流媒体',
    type: ProxyGroupType.fallback,
    glyphName: 'star',
    selectedName: '香港 流媒体',
    proxies: [
      MockProxy(name: '香港 流媒体', protocol: ProxyProtocol.ss, delayMs: 64),
      MockProxy(name: '日本 流媒体', protocol: ProxyProtocol.trojan, delayMs: 118),
      MockProxy(name: '新加坡 流媒体', protocol: ProxyProtocol.vmess, delayMs: 176),
      MockProxy(
        name: '美国 流媒体',
        protocol: ProxyProtocol.hysteria2,
        delayMs: 356,
      ),
    ],
  ),
  MockProxyGroup(
    name: '🍎 苹果服务',
    type: ProxyGroupType.urlTest,
    glyphName: 'devices',
    selectedName: '直连',
    proxies: [
      MockProxy(name: '直连', protocol: ProxyProtocol.direct, delayMs: 8),
      MockProxy(name: '香港 中继', protocol: ProxyProtocol.ss, delayMs: 76),
      MockProxy(name: '日本 中继', protocol: ProxyProtocol.vmess, delayMs: 152),
      MockProxy(name: '美国 中继', protocol: ProxyProtocol.trojan, delayMs: 288),
    ],
  ),
  MockProxyGroup(
    name: '🛑 广告拦截',
    type: ProxyGroupType.relay,
    glyphName: 'block',
    selectedName: '拒绝',
    proxies: [
      MockProxy(name: '拒绝', protocol: ProxyProtocol.reject),
      MockProxy(name: '黑洞', protocol: ProxyProtocol.reject),
      MockProxy(name: '本地规则', protocol: ProxyProtocol.direct, delayMs: 4),
    ],
  ),
];

class MockProxyProvider {
  const MockProxyProvider({
    required this.name,
    required this.url,
    required this.count,
    required this.updatedAt,
    required this.intervalHours,
    this.filter,
  });

  final String name;
  final String url;

  final int count;

  final String updatedAt;

  final int intervalHours;

  /// mihomo node-name filter regex; empty means no filtering.
  final String? filter;
}

const mockProxyProviders = <MockProxyProvider>[
  MockProxyProvider(
    name: '机场主订阅',
    url: 'https://sub.example.com/api/v1/client/subscribe?token=8f2c1a',
    count: 42,
    updatedAt: '10-19 09:24',
    intervalHours: 24,
    filter: '🇭🇰|🇯🇵|🇸🇬',
  ),
  MockProxyProvider(
    name: '备用节点',
    url: 'https://backup.example.net/subscribe?token=41bd77',
    count: 18,
    updatedAt: '10-18 22:10',
    intervalHours: 12,
  ),
  MockProxyProvider(
    name: '自建节点',
    url: 'https://edge.example.org/links/v2ray.txt',
    count: 6,
    updatedAt: '10-17 08:00',
    intervalHours: 168,
    filter: 'HK|SG',
  ),
  MockProxyProvider(
    name: '实验线路',
    url: 'https://lab.example.io/api/subscribe?token=9k3s',
    count: 9,
    updatedAt: '10-16 19:42',
    intervalHours: 72,
  ),
];

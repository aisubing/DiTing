/// 代理域演示数据：分组、节点、外部提供者。
///
/// 独立成库而不是 `mock_data.dart` 的 part：那个文件在并行期冻结，且代理
/// 页的数据自成一域（节点还要按延迟排序、按超时过滤），放一起会互相牵连。
library;

/// 代理协议（上游 `Proxy.type`）。
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

/// 代理列表的呈现形式（上游 `ProxiesType`）。
enum ProxiesType {
  tab('标签页'),
  list('列表');

  const ProxiesType(this.label);

  final String label;
}

/// 节点排序方式（上游 `ProxiesSortType`）。
enum ProxiesSortType {
  none('默认'),
  delay('延迟'),
  name('名称');

  const ProxiesSortType(this.label);

  final String label;
}

/// 分组标签页的列密度（上游 `ProxiesLayout`）。
enum ProxiesLayout {
  tight('紧凑'),
  standard('标准'),
  loose('宽松');

  const ProxiesLayout(this.label);

  final String label;
}

/// 节点卡片的尺寸档（上游 `ProxyCardType`）。
enum ProxyCardType {
  loose('宽松'),
  standard('标准'),
  compact('紧凑');

  const ProxyCardType(this.label);

  final String label;
}

/// 分组图标样式（上游 `ProxiesIconStyle`，仅列表形式可用）。
enum ProxiesIconStyle {
  filled('色块'),
  plain('纯图标'),
  hidden('隐藏');

  const ProxiesIconStyle(this.label);

  final String label;
}

/// 策略组类型（上游 `GroupType`）。
enum ProxyGroupType {
  selector('select', '手动选择', true),
  urlTest('url-test', '自动测速', true),
  fallback('fallback', '故障转移', true),
  loadBalance('load-balance', '负载均衡', false),
  relay('relay', '链式代理', false);

  const ProxyGroupType(this.raw, this.label, this.isComputedSelected);

  /// mihomo 配置里的原始类型名，只在需要与配置对齐时使用。
  final String raw;

  final String label;

  /// 只有这三类组的组内选择是用户语义上的「当前节点」。
  final bool isComputedSelected;
}

/// 一个节点。
class MockProxy {
  const MockProxy({required this.name, required this.protocol, this.delayMs});

  final String name;
  final ProxyProtocol protocol;

  /// 上一次测速结果：`null` 未测试，负数代表超时。
  final int? delayMs;
}

/// 一个策略组。
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

  /// 列表形式的组图标名，解析在 `lib/widgets/glyph_lookup.dart`。
  final String glyphName;

  final List<MockProxy> proxies;

  /// 组内当前选中的节点名。
  final String? selectedName;
}

/// 测速用的探测地址（上游默认 `https://www.gstatic.com/generate_204`）。
const mockProxyTestUrl = 'https://www.gstatic.com/generate_204';

/// 6 个策略组，节点数 3–9 不等，覆盖全部协议与四种延迟档。
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

/// 一个外部提供者（上游 `ExternalProvider`）。
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

  /// 提供者里的节点条数。
  final int count;

  /// 上次更新的展示时间。
  final String updatedAt;

  /// 自动更新的间隔小时数，0 表示不自动更新。
  final int intervalHours;

  /// mihomo 的节点名过滤正则，空表示不过滤。
  final String? filter;
}

/// 4 个演示用外部提供者。
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

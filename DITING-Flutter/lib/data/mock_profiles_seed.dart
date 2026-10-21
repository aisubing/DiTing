part of 'mock_profiles.dart';

/// 初始节点列表。
const mockProxies = <MockProxy>[
  MockProxy(
    id: 'n1',
    name: '香港 01 · IPLC',
    protocol: ProxyProtocol.vmess,
    server: 'hk01.example.net',
    port: 443,
    latencyMs: 42,
    password: 'hk01-node-key',
    tls: true,
    sni: 'hk01.example.net',
  ),
  MockProxy(
    id: 'n2',
    name: '日本 02 · 软银',
    protocol: ProxyProtocol.trojan,
    server: 'jp02.example.net',
    port: 443,
    latencyMs: 78,
    password: 'jp02-pass',
    tls: true,
    sni: 'jp02.example.net',
  ),
  MockProxy(
    id: 'n3',
    name: '新加坡 03',
    protocol: ProxyProtocol.shadowsocks,
    server: 'sg03.example.net',
    port: 8388,
    latencyMs: 96,
    cipher: 'aes-256-gcm',
    password: 'sg03-pass',
  ),
  MockProxy(
    id: 'n4',
    name: '美国 04 · 家宽',
    protocol: ProxyProtocol.hysteria2,
    server: 'us04.example.net',
    port: 8443,
    latencyMs: 186,
    password: 'us04-pass',
    tls: true,
    sni: 'us04.example.net',
    skipCertVerify: true,
  ),
  MockProxy(
    id: 'n5',
    name: '德国 05',
    protocol: ProxyProtocol.vless,
    server: 'de05.example.net',
    port: 2053,
    latencyMs: 212,
    password: 'de05-uuid',
    tls: true,
    sni: 'de05.example.net',
  ),
  MockProxy(
    id: 'n6',
    name: '隧道 · WireGuard',
    protocol: ProxyProtocol.wireguard,
    server: 'wg.example.net',
    port: 51820,
    latencyMs: 34,
    password: 'wg-private-key',
    udp: true,
  ),
];

/// 初始代理组。
const mockProxyGroups = <MockProxyGroup>[
  MockProxyGroup(
    id: 'g1',
    name: '🚀 节点选择',
    kind: GroupKind.selector,
    members: ['♻️ 自动选择', '香港 01 · IPLC', '日本 02 · 软银', '美国 04 · 家宽'],
    icon: 'bolt',
  ),
  MockProxyGroup(
    id: 'g2',
    name: '♻️ 自动选择',
    kind: GroupKind.urlTest,
    members: ['香港 01 · IPLC', '日本 02 · 软银', '新加坡 03', '德国 05'],
    icon: 'speed',
    intervalSeconds: 300,
  ),
  MockProxyGroup(
    id: 'g3',
    name: '🛑 广告拦截',
    kind: GroupKind.selector,
    members: ['REJECT', 'DIRECT'],
    icon: 'block',
  ),
  MockProxyGroup(
    id: 'g4',
    name: '📺 流媒体',
    kind: GroupKind.fallback,
    members: ['日本 02 · 软银', '新加坡 03', '美国 04 · 家宽'],
    icon: 'star',
    intervalSeconds: 600,
  ),
  MockProxyGroup(
    id: 'g5',
    name: '⚖️ 负载均衡',
    kind: GroupKind.loadBalance,
    members: ['香港 01 · IPLC', '隧道 · WireGuard'],
    strategy: BalanceStrategy.roundRobin,
    icon: 'shuffle',
  ),
];

/// 初始自定义规则。
const mockCustomRules = <MockCustomRule>[
  MockCustomRule(
    id: 'r1',
    type: CustomRuleType.domainSuffix,
    content: 'adservice.example.com',
    target: '🛑 广告拦截',
  ),
  MockCustomRule(
    id: 'r2',
    type: CustomRuleType.domainKeyword,
    content: 'analytics',
    target: '🛑 广告拦截',
  ),
  MockCustomRule(
    id: 'r3',
    type: CustomRuleType.geosite,
    content: 'netflix',
    target: '📺 流媒体',
  ),
  MockCustomRule(
    id: 'r4',
    type: CustomRuleType.ipCidr,
    content: '10.0.0.0/8',
    target: 'DIRECT',
    noResolve: true,
  ),
  MockCustomRule(
    id: 'r5',
    type: CustomRuleType.domain,
    content: 'intranet.example.com',
    target: 'DIRECT',
  ),
  MockCustomRule(
    id: 'r6',
    type: CustomRuleType.processName,
    content: 'Telegram.exe',
    target: '🚀 节点选择',
  ),
  MockCustomRule(
    id: 'r7',
    type: CustomRuleType.geoip,
    content: 'CN',
    target: 'DIRECT',
    noResolve: true,
    disabled: true,
  ),
];

/// 初始代理提供者。
const mockProxyProviders = <MockProxyProvider>[
  MockProxyProvider(
    id: 'pp1',
    name: '机场 A',
    url: 'https://sub-a.example.com/providers/proxies',
    updatedAt: '12 分钟前',
    proxyCount: 26,
  ),
  MockProxyProvider(
    id: 'pp2',
    name: '机场 B（备用）',
    url: 'https://sub-b.example.com/providers/proxies',
    updatedAt: '2 小时前',
    proxyCount: 18,
    intervalMinutes: 1440,
    enabled: false,
  ),
];

/// 初始规则提供者。
const mockRuleProviders = <MockRuleProvider>[
  MockRuleProvider(
    id: 'rp1',
    name: '广告拦截',
    url: 'https://rules.example.com/adblock.yaml',
    behavior: 'domain',
    ruleCount: 18420,
    updatedAt: '1 小时前',
  ),
  MockRuleProvider(
    id: 'rp2',
    name: '国内直连',
    url: 'https://rules.example.com/cn.yaml',
    behavior: 'classical',
    ruleCount: 6320,
    updatedAt: '1 小时前',
  ),
  MockRuleProvider(
    id: 'rp3',
    name: '内网地址',
    url: 'https://rules.example.com/private.yaml',
    behavior: 'ipcidr',
    ruleCount: 84,
    updatedAt: '昨天',
    format: 'text',
  ),
];

/// 初始拨号器配置。
const mockDialers = <MockDialer>[
  MockDialer(proxyName: '美国 04 · 家宽', target: '隧道 · WireGuard'),
  MockDialer(proxyName: '德国 05', target: '香港 01 · IPLC'),
];

part of 'mock_config.dart';

/// 一份覆写页的数据：分组 + 条目 + 「可添加但未添加」的全部候选键。
///
/// 上游每个覆写页都是一个 `OverrideSpec`（值域 + 字段工厂 + 说明），页面
/// 只负责把 spec 渲染成列表。演示层保留同样的分工：`allKeys` 是可选全集，
/// `entries` 是用户已经「挑出来」的子集——加号按钮从 `allKeys` 里补一条。
class MockOverrideSpec {
  const MockOverrideSpec({
    required this.id,
    required this.title,
    required this.description,
    required this.allKeys,
    required this.initiallyPicked,
  });

  /// 稳定 id，provider 用它区分四份覆写页的状态。
  final String id;
  final String title;
  final String description;

  /// 全集，顺序即「添加条目」浮层里的展示顺序。
  final List<MockOverrideEntry> allKeys;

  /// 初次进入页面时已经「挑出来」的键；其余键等待用户点加号添加。
  final List<String> initiallyPicked;
}

/// 按 [MockOverrideEntry.section] 分组，保持首次出现顺序。
Map<String, List<MockOverrideEntry>> groupOverrideEntries(
  Iterable<MockOverrideEntry> entries,
) {
  final grouped = <String, List<MockOverrideEntry>>{};
  for (final entry in entries) {
    grouped.putIfAbsent(entry.section, () => []).add(entry);
  }
  return grouped;
}

/// TUN 覆写。
const mockTunOverrideSpec = MockOverrideSpec(
  id: 'tun',
  title: 'TUN 覆写',
  description:
      '这里的键只在 TUN 模式下生效，逐项覆盖订阅自带的 TUN 配置。'
      '清空一个条目的值等于不覆写它，回落到订阅自己的值。',
  initiallyPicked: [
    'mtu',
    'congestion-controller',
    'strict-route',
    'route-address',
    'dns-hijack',
    'udp-timeout',
    'gso',
  ],
  allKeys: [
    MockOverrideEntry(
      key: 'mtu',
      label: 'MTU',
      value: '1500',
      kind: OverrideFieldKind.number,
      section: '接口',
      min: minTunMtu,
      max: maxTunMtu,
    ),
    MockOverrideEntry(
      key: 'congestion-controller',
      label: '拥塞控制',
      value: 'bbr',
      kind: OverrideFieldKind.options,
      section: '接口',
      options: mockCongestionControllers,
      description: '只有 mips 栈读取这一项。',
    ),
    MockOverrideEntry(
      key: 'strict-route',
      label: '严格路由',
      value: 'true',
      kind: OverrideFieldKind.toggle,
      section: '路由',
      description:
          '拒绝所有未经 TUN 的流量，避免应用绕过代理。'
          '仅 Linux 与 Windows 生效。',
    ),
    MockOverrideEntry(
      key: 'route-address',
      label: '路由网段',
      value: '198.18.0.1/16',
      kind: OverrideFieldKind.list,
      section: '路由',
    ),
    MockOverrideEntry(
      key: 'route-exclude-address',
      label: '排除网段',
      value: '10.0.0.0/8',
      kind: OverrideFieldKind.list,
      section: '路由',
      description: '这些网段不会进入 TUN。',
    ),
    MockOverrideEntry(
      key: 'dns-hijack',
      label: 'DNS 劫持',
      value: 'any:53',
      kind: OverrideFieldKind.list,
      section: '路由',
    ),
    MockOverrideEntry(
      key: 'udp-timeout',
      label: 'UDP 超时',
      value: '300',
      kind: OverrideFieldKind.number,
      section: '转发',
      unit: '秒',
      min: 1,
      max: 65535,
    ),
    MockOverrideEntry(
      key: 'disable-icmp-forwarding',
      label: '禁用 ICMP 转发',
      value: 'false',
      kind: OverrideFieldKind.toggle,
      section: '转发',
    ),
    MockOverrideEntry(
      key: 'gso',
      label: 'GSO',
      value: 'true',
      kind: OverrideFieldKind.toggle,
      section: '转发',
      description: '通用分段卸载，Linux 专属。',
    ),
    MockOverrideEntry(
      key: 'include-interface',
      label: '包含接口',
      value: 'eth0',
      kind: OverrideFieldKind.list,
      section: '过滤',
      description: '只让这些接口的流量进入 TUN。Linux 专属。',
    ),
    MockOverrideEntry(
      key: 'exclude-interface',
      label: '排除接口',
      value: 'docker0',
      kind: OverrideFieldKind.list,
      section: '过滤',
      description: 'Linux 专属。',
    ),
    MockOverrideEntry(
      key: 'include-uid',
      label: '包含 UID',
      value: '1000',
      kind: OverrideFieldKind.list,
      section: '过滤',
      description: 'Linux 专属，按进程用户过滤。',
    ),
    MockOverrideEntry(
      key: 'exclude-uid',
      label: '排除 UID',
      value: '0',
      kind: OverrideFieldKind.list,
      section: '过滤',
      description: 'Linux 专属。',
    ),
    MockOverrideEntry(
      key: 'exclude-src-port',
      label: '排除源端口',
      value: '5353',
      kind: OverrideFieldKind.list,
      section: '过滤',
      description: 'Linux 专属。',
    ),
    MockOverrideEntry(
      key: 'exclude-dst-port',
      label: '排除目标端口',
      value: '443',
      kind: OverrideFieldKind.list,
      section: '过滤',
      description: 'Linux 专属。',
    ),
  ],
);

/// NTP 覆写。
const mockNtpOverrideSpec = MockOverrideSpec(
  id: 'ntp',
  title: 'NTP',
  description:
      'NTP 覆写让内核自己校准时间：开启后内核按间隔向服务器对时，'
      '必要时把时间写回系统。',
  initiallyPicked: ['enable', 'server', 'port', 'interval', 'write-to-system'],
  allKeys: [
    MockOverrideEntry(
      key: 'enable',
      label: '启用',
      value: 'true',
      kind: OverrideFieldKind.toggle,
      section: '基础',
      description: '关掉之后内核不再校时。',
    ),
    MockOverrideEntry(
      key: 'server',
      label: '服务器',
      value: 'time.apple.com',
      kind: OverrideFieldKind.text,
      section: '基础',
    ),
    MockOverrideEntry(
      key: 'port',
      label: '端口',
      value: '123',
      kind: OverrideFieldKind.number,
      section: '基础',
      min: 1,
      max: 65535,
    ),
    MockOverrideEntry(
      key: 'interval',
      label: '对时间隔',
      value: '30',
      kind: OverrideFieldKind.number,
      section: '基础',
      unit: '分钟',
      min: 1,
      max: 10000,
    ),
    MockOverrideEntry(
      key: 'dialer-proxy',
      label: '拨号代理',
      value: 'DIRECT',
      kind: OverrideFieldKind.text,
      section: '高级',
      description: '对时请求走哪个代理组。',
    ),
    MockOverrideEntry(
      key: 'write-to-system',
      label: '写回系统',
      value: 'false',
      kind: OverrideFieldKind.toggle,
      section: '高级',
      description: '把内核时间同步给系统；需要额外权限。',
    ),
  ],
);

/// 嗅探协议。
enum SniffProtocol {
  http('HTTP', 80),
  tls('TLS', 443),
  quic('QUIC', 443);

  const SniffProtocol(this.label, this.defaultPort);

  final String label;

  /// 不填端口时 mihomo 用的标准端口。
  final int defaultPort;
}

/// 单个协议的嗅探配置。
class MockSniffConfig {
  const MockSniffConfig({
    required this.protocol,
    required this.enable,
    required this.ports,
    this.overrideDestination,
  });

  final SniffProtocol protocol;
  final bool enable;

  /// 空列表表示「标准端口」，与上游 `_portsText` 的文案一致。
  final List<String> ports;

  /// null 表示继承全局 `override-destination`。
  final bool? overrideDestination;

  MockSniffConfig copyWith({
    bool? enable,
    List<String>? ports,
    Object? overrideDestination = _keepDestination,
  }) => MockSniffConfig(
    protocol: protocol,
    enable: enable ?? this.enable,
    ports: ports ?? this.ports,
    overrideDestination: overrideDestination == _keepDestination
        ? this.overrideDestination
        : overrideDestination as bool?,
  );
}

const _keepDestination = Object();

/// 嗅探覆写。
const mockSnifferOverrideSpec = MockOverrideSpec(
  id: 'sniffer',
  title: '嗅探',
  description:
      '嗅探从流量里读出真实域名，再用它重新匹配规则。'
      '跳过名单里的地址不做嗅探，强制名单里的地址一定做。',
  initiallyPicked: [
    'enable',
    'override-destination',
    'force-domain',
    'skip-domain',
    'skip-dst-address',
  ],
  allKeys: [
    MockOverrideEntry(
      key: 'enable',
      label: '启用嗅探',
      value: 'true',
      kind: OverrideFieldKind.toggle,
      section: '基础',
    ),
    MockOverrideEntry(
      key: 'override-destination',
      label: '覆写目标地址',
      value: 'true',
      kind: OverrideFieldKind.toggle,
      section: '基础',
      description: '用嗅探到的域名替换连接目标，让域名规则生效。',
    ),
    MockOverrideEntry(
      key: 'force-dns-mapping',
      label: '强制 DNS 映射',
      value: 'false',
      kind: OverrideFieldKind.toggle,
      section: '基础',
    ),
    MockOverrideEntry(
      key: 'parse-pure-ip',
      label: '解析纯 IP 连接',
      value: 'false',
      kind: OverrideFieldKind.toggle,
      section: '基础',
    ),
    MockOverrideEntry(
      key: 'force-domain',
      label: '强制嗅探域名',
      value: '*.example.com',
      kind: OverrideFieldKind.list,
      section: '名单',
    ),
    MockOverrideEntry(
      key: 'skip-domain',
      label: '跳过域名',
      value: '*.lan',
      kind: OverrideFieldKind.list,
      section: '名单',
    ),
    MockOverrideEntry(
      key: 'skip-src-address',
      label: '跳过源地址',
      value: '192.168.0.0/16',
      kind: OverrideFieldKind.list,
      section: '名单',
    ),
    MockOverrideEntry(
      key: 'skip-dst-address',
      label: '跳过目标地址',
      value: '10.0.0.0/8',
      kind: OverrideFieldKind.list,
      section: '名单',
    ),
  ],
);

/// 三个协议的初始嗅探配置。
const mockSniffConfigs = <MockSniffConfig>[
  MockSniffConfig(
    protocol: SniffProtocol.http,
    enable: true,
    ports: [],
    overrideDestination: true,
  ),
  MockSniffConfig(
    protocol: SniffProtocol.tls,
    enable: true,
    ports: ['8443', '9443'],
  ),
  MockSniffConfig(protocol: SniffProtocol.quic, enable: false, ports: []),
];

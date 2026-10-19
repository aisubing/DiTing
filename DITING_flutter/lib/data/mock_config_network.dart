part of 'mock_config.dart';

/// TUN 栈实现。
enum TunStack {
  gvisor('gvisor', '用户态协议栈，兼容性最好'),
  system('system', '使用系统协议栈，性能更高'),
  mixed('mixed', 'TCP 走系统栈，UDP 走用户态'),
  mips('mips', 'MIPS 路由器等特殊平台的栈');

  const TunStack(this.label, this.description);

  final String label;
  final String description;
}

/// 接口名模式。
enum InterfaceNameMode {
  clear('不设置', '不显式指定接口名'),
  follow('跟随系统', '沿用系统默认网卡名'),
  custom('自定义', '手动填写接口名');

  const InterfaceNameMode(this.label, this.description);

  final String label;
  final String description;
}

/// 拥塞控制算法（仅 mips 栈可用，上游如此）。
const mockCongestionControllers = <String>['cubic', 'bbr', 'new_reno'];

/// TUN MTU 的合法区间。
const minTunMtu = 1280;
const maxTunMtu = 9000;

/// 网络设置的初始值。
class MockNetworkSnapshot {
  const MockNetworkSnapshot({
    required this.vpnEnable,
    required this.vpnSystemProxy,
    required this.allowBypass,
    required this.ipv6,
    required this.dnsHijacking,
    required this.autoSetSystemDns,
    required this.tunEnable,
    required this.tunStack,
    required this.mtu,
    required this.congestionController,
    required this.bypassPrivateRoute,
    required this.bypassDomain,
    required this.routeAddress,
    required this.routeExcludeAddress,
    required this.interfaceNameMode,
    required this.interfaceName,
    required this.systemProxy,
    required this.disableKeepAlive,
    required this.keepAliveIdle,
    required this.keepAliveInterval,
    required this.routingMark,
  });

  // —— VPN ——
  final bool vpnEnable;
  final bool vpnSystemProxy;
  final bool allowBypass;
  final bool ipv6;
  final bool dnsHijacking;
  final bool autoSetSystemDns;

  // —— TUN ——
  final bool tunEnable;
  final TunStack tunStack;
  final int mtu;
  final String congestionController;
  final bool bypassPrivateRoute;
  final List<String> bypassDomain;
  final List<String> routeAddress;
  final List<String> routeExcludeAddress;
  final InterfaceNameMode interfaceNameMode;
  final String interfaceName;

  // —— 出站 ——
  final bool systemProxy;
  final bool disableKeepAlive;
  final int keepAliveIdle;
  final int keepAliveInterval;
  final int routingMark;

  MockNetworkSnapshot copyWith({
    bool? vpnEnable,
    bool? vpnSystemProxy,
    bool? allowBypass,
    bool? ipv6,
    bool? dnsHijacking,
    bool? autoSetSystemDns,
    bool? tunEnable,
    TunStack? tunStack,
    int? mtu,
    String? congestionController,
    bool? bypassPrivateRoute,
    List<String>? bypassDomain,
    List<String>? routeAddress,
    List<String>? routeExcludeAddress,
    InterfaceNameMode? interfaceNameMode,
    String? interfaceName,
    bool? systemProxy,
    bool? disableKeepAlive,
    int? keepAliveIdle,
    int? keepAliveInterval,
    int? routingMark,
  }) => MockNetworkSnapshot(
    vpnEnable: vpnEnable ?? this.vpnEnable,
    vpnSystemProxy: vpnSystemProxy ?? this.vpnSystemProxy,
    allowBypass: allowBypass ?? this.allowBypass,
    ipv6: ipv6 ?? this.ipv6,
    dnsHijacking: dnsHijacking ?? this.dnsHijacking,
    autoSetSystemDns: autoSetSystemDns ?? this.autoSetSystemDns,
    tunEnable: tunEnable ?? this.tunEnable,
    tunStack: tunStack ?? this.tunStack,
    mtu: mtu ?? this.mtu,
    congestionController: congestionController ?? this.congestionController,
    bypassPrivateRoute: bypassPrivateRoute ?? this.bypassPrivateRoute,
    bypassDomain: bypassDomain ?? this.bypassDomain,
    routeAddress: routeAddress ?? this.routeAddress,
    routeExcludeAddress: routeExcludeAddress ?? this.routeExcludeAddress,
    interfaceNameMode: interfaceNameMode ?? this.interfaceNameMode,
    interfaceName: interfaceName ?? this.interfaceName,
    systemProxy: systemProxy ?? this.systemProxy,
    disableKeepAlive: disableKeepAlive ?? this.disableKeepAlive,
    keepAliveIdle: keepAliveIdle ?? this.keepAliveIdle,
    keepAliveInterval: keepAliveInterval ?? this.keepAliveInterval,
    routingMark: routingMark ?? this.routingMark,
  );
}

/// 网络设置初始值。
const mockNetworkSnapshot = MockNetworkSnapshot(
  vpnEnable: true,
  vpnSystemProxy: false,
  allowBypass: true,
  ipv6: true,
  dnsHijacking: true,
  autoSetSystemDns: false,
  tunEnable: false,
  tunStack: TunStack.mixed,
  mtu: 1500,
  congestionController: 'bbr',
  bypassPrivateRoute: true,
  bypassDomain: ['*.lan', '*.local', 'localhost.ptlogin2.qq.com'],
  routeAddress: ['198.18.0.1/16'],
  routeExcludeAddress: ['10.0.0.0/8', '192.168.0.0/16', '169.254.0.0/16'],
  interfaceNameMode: InterfaceNameMode.follow,
  interfaceName: 'tun0',
  systemProxy: false,
  disableKeepAlive: false,
  keepAliveIdle: 180,
  keepAliveInterval: 30,
  routingMark: 0,
);

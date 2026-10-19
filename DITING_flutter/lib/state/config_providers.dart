/// 配置域演示状态：通用 / 网络 / 四份覆写 / 数据资源。
///
/// 为什么全部放在 provider 而不是页面 `State`：配置项之间互相影响（TUN 关闭时
/// 它的子项要置灰、接口名模式不是「自定义」时接口名要隐藏、DNS 策略表跟着
/// 覆写页走），而页面之间又会互相跳转——放页面 state 里，跳一次就丢一次。
///
/// 拆成多个 notifier 而不是一个巨型 state：`ref.watch` 是按 provider 粒度
/// 重建的，一个 notifier 意味着拨一个开关会重建整页所有行。
library;

import 'package:diting/data/mock_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'config_providers_resources.dart';

/// 通用设置。
class GeneralNotifier extends Notifier<MockConfigSnapshot> {
  @override
  MockConfigSnapshot build() => mockConfigSnapshot;

  void setLogLevel(LogLevel level) => state = state.copyWith(logLevel: level);

  void setTestUrl(String value) => state = state.copyWith(testUrl: value);

  void setAllowLan(bool value) => state = state.copyWith(allowLan: value);

  void setExternalController(bool value) {
    // 与上游一致：打开外部控制器时自动补一个随机密钥，否则面板连不上。
    state = state.copyWith(
      externalController: value,
      controllerSecret: value && state.controllerSecret.isEmpty
          ? 'diting-${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}'
          : null,
    );
  }

  void setControllerSecret(String value) =>
      state = state.copyWith(controllerSecret: value);

  void setAuthentication(bool value) => state = state.copyWith(
    authentication: value,
    // 打开鉴权但账号为空时补默认值，避免一开就是一个连不上的配置。
    account: value && state.account.isEmpty ? 'diting' : null,
    password: value && state.password.isEmpty ? 'demo-pass' : null,
  );

  void setAccount(String value) => state = state.copyWith(account: value);

  void setPassword(String value) => state = state.copyWith(password: value);

  void setPorts(MockPorts ports) => state = state.copyWith(ports: ports);

  void setUnifiedDelay(bool value) =>
      state = state.copyWith(unifiedDelay: value);

  void setTcpConcurrent(bool value) =>
      state = state.copyWith(tcpConcurrent: value);

  void setFindProcess(bool value) => state = state.copyWith(findProcess: value);

  void setCloseConnections(bool value) =>
      state = state.copyWith(closeConnections: value);

  void setOnlyStatisticsProxy(bool value) =>
      state = state.copyWith(onlyStatisticsProxy: value);

  void setCheckCertificate(bool value) =>
      state = state.copyWith(checkCertificate: value);

  void setAutoCheckUpdate(bool value) =>
      state = state.copyWith(autoCheckUpdate: value);

  void setIpv6(bool value) => state = state.copyWith(ipv6: value);

  void setAppendSystemDns(bool value) =>
      state = state.copyWith(appendSystemDns: value);

  void setGeodataMemconservative(bool value) =>
      state = state.copyWith(geodataMemconservative: value);

  void setOpenLogs(bool value) => state = state.copyWith(openLogs: value);

  /// UA 设为 null 表示跟随订阅或内核默认。
  void setUserAgent(String? value) => state = state.copyWith(userAgent: value);

  void setHosts(Map<String, String> hosts) =>
      state = state.copyWith(hosts: hosts);

  /// 写入一条 Hosts 记录；域名重复时覆盖旧值（与上游 map 编辑器一致）。
  void putHost(String key, String value) {
    state = state.copyWith(hosts: {...state.hosts, key: value});
  }

  void removeHost(String key) {
    final next = {...state.hosts}..remove(key);
    state = state.copyWith(hosts: next);
  }
}

final generalConfigProvider =
    NotifierProvider<GeneralNotifier, MockConfigSnapshot>(GeneralNotifier.new);

/// 网络设置。
class NetworkNotifier extends Notifier<MockNetworkSnapshot> {
  @override
  MockNetworkSnapshot build() => mockNetworkSnapshot;

  void setVpnEnable(bool value) => state = state.copyWith(vpnEnable: value);

  void setVpnSystemProxy(bool value) =>
      state = state.copyWith(vpnSystemProxy: value);

  void setAllowBypass(bool value) => state = state.copyWith(allowBypass: value);

  void setIpv6(bool value) => state = state.copyWith(ipv6: value);

  void setDnsHijacking(bool value) =>
      state = state.copyWith(dnsHijacking: value);

  void setAutoSetSystemDns(bool value) =>
      state = state.copyWith(autoSetSystemDns: value);

  void setTunEnable(bool value) => state = state.copyWith(tunEnable: value);

  void setTunStack(TunStack stack) => state = state.copyWith(tunStack: stack);

  void setMtu(int value) => state = state.copyWith(mtu: value);

  void setCongestionController(String value) =>
      state = state.copyWith(congestionController: value);

  void setBypassPrivateRoute(bool value) =>
      state = state.copyWith(bypassPrivateRoute: value);

  void setInterfaceNameMode(InterfaceNameMode mode) =>
      state = state.copyWith(interfaceNameMode: mode);

  void setInterfaceName(String value) =>
      state = state.copyWith(interfaceName: value);

  void setSystemProxy(bool value) => state = state.copyWith(systemProxy: value);

  void setDisableKeepAlive(bool value) =>
      state = state.copyWith(disableKeepAlive: value);

  void setKeepAliveIdle(int value) =>
      state = state.copyWith(keepAliveIdle: value);

  void setKeepAliveInterval(int value) =>
      state = state.copyWith(keepAliveInterval: value);

  /// 字符串列表的通用增删：bypassDomain / routeAddress / routeExcludeAddress
  /// 三处结构一致，各写一套增删逻辑迟早会漏掉其中一处。
  void addToStringList(
    List<String> Function(MockNetworkSnapshot state) read,
    MockNetworkSnapshot Function(MockNetworkSnapshot state, List<String> value)
    write,
    String value,
  ) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || read(state).contains(trimmed)) {
      return;
    }
    state = write(state, [...read(state), trimmed]);
  }

  void removeFromStringList(
    List<String> Function(MockNetworkSnapshot state) read,
    MockNetworkSnapshot Function(MockNetworkSnapshot state, List<String> value)
    write,
    String value,
  ) => state = write(state, [...read(state)]..remove(value));
}

final networkConfigProvider =
    NotifierProvider<NetworkNotifier, MockNetworkSnapshot>(NetworkNotifier.new);

/// 一份覆写页的可变状态：哪些键被「挑出来」+ 每个键的当前值。
class OverrideState {
  const OverrideState({required this.picked, required this.values});

  final List<String> picked;
  final Map<String, String> values;

  OverrideState copyWith({List<String>? picked, Map<String, String>? values}) =>
      OverrideState(
        picked: picked ?? this.picked,
        values: values ?? this.values,
      );
}

/// 四份覆写页共用一张表。
///
/// `Map<String, OverrideState>` 而不是四个 notifier：四个页面的操作完全一致
/// （挑键 / 丢键 / 改值 / 清空），差异只有 spec 本身。
class OverrideNotifier extends Notifier<Map<String, OverrideState>> {
  @override
  Map<String, OverrideState> build() => {
    for (final spec in [
      mockTunOverrideSpec,
      mockDnsOverrideSpec,
      mockNtpOverrideSpec,
      mockSnifferOverrideSpec,
    ])
      spec.id: OverrideState(
        picked: [...spec.initiallyPicked],
        values: {for (final entry in spec.allKeys) entry.key: entry.value},
      ),
  };

  OverrideState stateOf(String specId) =>
      state[specId] ?? const OverrideState(picked: [], values: {});

  void add(String specId, String key) {
    final current = stateOf(specId);
    if (current.picked.contains(key)) {
      return;
    }
    state = {
      ...state,
      specId: current.copyWith(picked: [...current.picked, key]),
    };
  }

  void remove(String specId, String key) {
    final current = stateOf(specId);
    state = {
      ...state,
      specId: current.copyWith(picked: [...current.picked]..remove(key)),
    };
  }

  /// 改值；改成空串等价于「不覆写这一项」，但行仍然留在列表里（上游
  /// `emptyCancels` 的行为是把它从列表拿掉，这里保留行以便用户改回来）。
  void setValue(String specId, String key, String value) {
    final current = stateOf(specId);
    state = {
      ...state,
      specId: current.copyWith(values: {...current.values, key: value}),
    };
  }

  void clearValue(String specId, String key) => setValue(specId, key, '');
}

final overrideProvider =
    NotifierProvider<OverrideNotifier, Map<String, OverrideState>>(
      OverrideNotifier.new,
    );

/// DNS 策略表（规则集 → 服务商）。
class DnsPolicyNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {...mockDnsPolicies};

  bool put(String key, String value) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    state = {...state, trimmed: value.trim()};
    return true;
  }

  void remove(String key) => state = {...state}..remove(key);

  /// 就地改值；键不可改（键是规则集，改了就是另一条策略）。
  void updateValue(String key, String value) =>
      state = {...state, key: value.trim()};
}

final dnsPolicyProvider =
    NotifierProvider<DnsPolicyNotifier, Map<String, String>>(
      DnsPolicyNotifier.new,
    );

/// 嗅探的三个协议配置。
class SnifferNotifier extends Notifier<List<MockSniffConfig>> {
  @override
  List<MockSniffConfig> build() => [...mockSniffConfigs];

  void setEnable(SniffProtocol protocol, bool value) {
    state = [
      for (final config in state)
        config.protocol == protocol ? config.copyWith(enable: value) : config,
    ];
  }

  void setOverrideDestination(SniffProtocol protocol, bool? value) {
    state = [
      for (final config in state)
        config.protocol == protocol
            ? config.copyWith(overrideDestination: value)
            : config,
    ];
  }

  void addPort(SniffProtocol protocol, String port) {
    final trimmed = port.trim();
    if (trimmed.isEmpty) {
      return;
    }
    state = [
      for (final config in state)
        if (config.protocol == protocol)
          config.ports.contains(trimmed)
              ? config
              : config.copyWith(ports: [...config.ports, trimmed])
        else
          config,
    ];
  }

  void removePort(SniffProtocol protocol, String port) {
    state = [
      for (final config in state)
        config.protocol == protocol
            ? config.copyWith(ports: [...config.ports]..remove(port))
            : config,
    ];
  }

  MockSniffConfig of(SniffProtocol protocol) =>
      state.firstWhere((config) => config.protocol == protocol);
}

final snifferConfigProvider =
    NotifierProvider<SnifferNotifier, List<MockSniffConfig>>(
      SnifferNotifier.new,
    );

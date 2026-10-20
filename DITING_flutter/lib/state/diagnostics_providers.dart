/// 网络工具的运行时依赖与设置。
///
/// 三个约束决定了这里的形状：
///
/// 1. **探测必须走原生**。`ping` / `traceroute` 需要 fork 进程、`lookupDns` 的
///    隧道分支要问 Go 引擎，Dart 侧都无法实现，因此统一经
///    `lib/data/native/diagnostics_bridge.dart` 的 `DiagnosticsRunner`。
/// 2. **平台异常不能冒到 UI**。`MethodChannel` 在桌面/测试宿主上抛
///    `MissingPluginException`，原生实现出错抛 `PlatformException`。两者都必须在
///    这一层转成「带可读 message 的失败结果」，页面只面对数据。
/// 3. **三个 viaTunnel 开关落盘到 1.4.3 的独立容器** `network_tools_settings`
///    （键名照抄 `ui/settings/NetworkToolsSettingsStore.kt`）。它们与 DNS 域的
///    `dns_vpn_prefs` 不是同一个文件，写错容器等于写进没人读的抽屉。
library;

import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `NetworkToolsSettingsStore.PREFS_NAME`
const networkToolsContainer = 'network_tools_settings';

/// 三个逐工具的「走隧道解析」开关键名，逐字照抄 Kotlin 常量。
const pingViaTunnelKey = 'ping_via_tunnel';
const dnsLookupViaTunnelKey = 'dns_lookup_via_tunnel';
const tracerouteViaTunnelKey = 'traceroute_via_tunnel';

/// 原生诊断实现。**main.dart 需要 override 成
/// `GuardedDiagnosticsRunner(MethodChannelDiagnosticsRunner())`**；
/// 默认给不可用实现，让测试与非 Android 宿主启动即有可读文案而不是崩溃。
final diagnosticsRunnerProvider = Provider<DiagnosticsRunner>(
  (ref) => const GuardedDiagnosticsRunner(UnavailableDiagnosticsRunner()),
);

/// 把平台异常转成失败结果的装饰器。
///
/// 每个方法都返回「结构完整但 success=false」的对象，而不是抛异常：面板的
/// 忙碌态在 `await` 之后才复位，抛出会让按钮永久卡在「正在探测…」。
class GuardedDiagnosticsRunner implements DiagnosticsRunner {
  const GuardedDiagnosticsRunner(this._inner);

  final DiagnosticsRunner _inner;

  @override
  Future<PingSummary> ping(
    String target, {
    int count = 4,
    int timeoutSeconds = 3,
  }) => _guard(
    () => _inner.ping(target, count: count, timeoutSeconds: timeoutSeconds),
    (message) => PingSummary(
      target: target,
      transmitted: 0,
      received: 0,
      lossPercent: 100,
      success: false,
      message: message,
    ),
  );

  @override
  Future<TraceResult> traceRoute(String target, {int maxHops = 30}) => _guard(
    () => _inner.traceRoute(target, maxHops: maxHops),
    (message) => TraceResult(
      target: target,
      hops: const [],
      success: false,
      message: message,
    ),
  );

  @override
  Future<DnsLookupResult> lookupDns(
    String domain, {
    bool viaTunnel = false,
    bool ipv4 = true,
  }) => _guard(
    () => _inner.lookupDns(domain, viaTunnel: viaTunnel, ipv4: ipv4),
    (message) => DnsLookupResult(
      domain: domain,
      source: 'error',
      answers: const [],
      elapsedMs: 0,
      error: message,
    ),
  );

  @override
  Future<NetworkInfoSnapshot> networkInfo() => _guard(
    () => _inner.networkInfo(),
    (message) => NetworkInfoSnapshot(
      interfaceName: '',
      localIpv4: '',
      privateDns: 'off',
      vpnActive: false,
      gateway: message,
    ),
  );

  static Future<T> _guard<T>(
    Future<T> Function() run,
    T Function(String message) onError,
  ) async {
    try {
      return await run();
    } on MissingPluginException {
      return onError('诊断通道不可用（当前平台没有原生实现）');
    } on PlatformException catch (error) {
      return onError(_platformErrorText(error));
    } on UnsupportedError {
      return onError('当前环境不支持该诊断能力');
    }
  }

  static String _platformErrorText(PlatformException error) {
    final detail = error.message;
    return detail == null || detail.isEmpty
        ? '诊断执行失败（${error.code}）'
        : '诊断执行失败：$detail';
  }
}

/// 非 Android 宿主（桌面、单元测试）的默认实现：全部返回可读失败，不抛。
class UnavailableDiagnosticsRunner implements DiagnosticsRunner {
  const UnavailableDiagnosticsRunner();

  @override
  Future<PingSummary> ping(
    String target, {
    int count = 4,
    int timeoutSeconds = 3,
  }) async => PingSummary(
    target: target,
    transmitted: 0,
    received: 0,
    lossPercent: 100,
    success: false,
    message: '当前环境不支持 Ping 探测',
  );

  @override
  Future<TraceResult> traceRoute(String target, {int maxHops = 30}) async =>
      TraceResult(
        target: target,
        hops: const [],
        success: false,
        message: '当前环境不支持路由追踪',
      );

  @override
  Future<DnsLookupResult> lookupDns(
    String domain, {
    bool viaTunnel = false,
    bool ipv4 = true,
  }) async => DnsLookupResult(
    domain: domain,
    source: 'error',
    answers: const [],
    elapsedMs: 0,
    error: '当前环境不支持 DNS 查询',
  );

  @override
  Future<NetworkInfoSnapshot> networkInfo() async => const NetworkInfoSnapshot(
    interfaceName: '',
    localIpv4: '',
    privateDns: 'off',
    vpnActive: false,
  );
}

/// 物理网络快照。页面顶部信息条读它，不用任何 mock 常量。
final networkInfoProvider = FutureProvider<NetworkInfoSnapshot>(
  (ref) => ref.watch(diagnosticsRunnerProvider).networkInfo(),
);

/// 三个 viaTunnel 开关的当前值。
class NetworkToolFlags {
  const NetworkToolFlags({
    this.pingViaTunnel = false,
    this.dnsLookupViaTunnel = false,
    this.tracerouteViaTunnel = false,
  });

  final bool pingViaTunnel;
  final bool dnsLookupViaTunnel;
  final bool tracerouteViaTunnel;

  NetworkToolFlags copyWith({
    bool? pingViaTunnel,
    bool? dnsLookupViaTunnel,
    bool? tracerouteViaTunnel,
  }) => NetworkToolFlags(
    pingViaTunnel: pingViaTunnel ?? this.pingViaTunnel,
    dnsLookupViaTunnel: dnsLookupViaTunnel ?? this.dnsLookupViaTunnel,
    tracerouteViaTunnel: tracerouteViaTunnel ?? this.tracerouteViaTunnel,
  );
}

/// 读 `network_tools_settings`；默认全部 false（旧版也是默认 false）。
///
/// 依赖 [legacySettingsRevisionProvider] 复用来做失效：两者的写入口都是同一个
/// `LegacyPrefsStore`，而 SharedPreferences 写入不可观察，必须有显式版本号，
/// 否则面板 A 改了开关、面板 B 已经 build 过就读到旧值。
final networkToolFlagsProvider = Provider<NetworkToolFlags>((ref) {
  ref.watch(legacySettingsRevisionProvider);
  final store = ref.watch(legacyPrefsStoreProvider);
  bool read(String key) => store.read(networkToolsContainer, key) == true;
  return NetworkToolFlags(
    pingViaTunnel: read(pingViaTunnelKey),
    dnsLookupViaTunnel: read(dnsLookupViaTunnelKey),
    tracerouteViaTunnel: read(tracerouteViaTunnelKey),
  );
});

/// 写一个开关并通知所有读 `network_tools_settings` 的 provider。
void setNetworkToolFlag(WidgetRef ref, String key, bool value) {
  ref
      .read(legacyPrefsStoreProvider)
      .putBool(networkToolsContainer, key, value);
  ref.read(legacySettingsRevisionProvider.notifier).bump();
}

/// 探测目标的清洗：去掉 scheme / 路径 / 用户信息 / 端口，只留主机名或 IP。
///
/// 逐步转写自 `core/diagnostic/NetworkPingTool.sanitizeHost`（Kotlin）：
/// 1. `://` 之后的部分；
/// 2. 第一个 `/`、`?`、`#` 之前；
/// 3. 最后一个 `@` 之后（去 `user:pass@`）；
/// 4. `[` 开头取到 `]`（`[::1]:53` → `::1`）；
/// 5. 否则「不含 `::` 且恰好一个 `:` 且冒号后全数字」才当端口剥掉——
///    这条守卫是 `2001:db8::1` 这类地址不被误伤的关键。
String sanitizeProbeHost(String input) {
  var value = input.trim();
  if (value.isEmpty) {
    return value;
  }
  final schemeIndex = value.indexOf('://');
  if (schemeIndex >= 0) {
    value = value.substring(schemeIndex + 3);
  }
  final cutIndex = _firstIndexOfAny(value, const ['/', '?', '#']);
  if (cutIndex >= 0) {
    value = value.substring(0, cutIndex);
  }
  final atIndex = value.lastIndexOf('@');
  if (atIndex >= 0) {
    value = value.substring(atIndex + 1);
  }
  if (value.startsWith('[')) {
    final endIndex = value.indexOf(']');
    return endIndex > 0 ? value.substring(1, endIndex) : value;
  }
  if (!value.contains('::') && ':'.allMatches(value).length == 1) {
    final afterColon = value.substring(value.indexOf(':') + 1);
    if (afterColon.isNotEmpty && int.tryParse(afterColon) != null) {
      value = value.substring(0, value.indexOf(':'));
    }
  }
  return value;
}

int _firstIndexOfAny(String value, List<String> needles) {
  var best = -1;
  for (final needle in needles) {
    final index = value.indexOf(needle);
    if (index >= 0 && (best < 0 || index < best)) {
      best = index;
    }
  }
  return best;
}

/// 清洗 + 判空，返回 (host, error)。error 非空时面板直接展示，不再发探测。
({String host, String? error}) resolveProbeHost(String input) {
  final host = sanitizeProbeHost(input);
  if (host.isEmpty) {
    return (host: host, error: '请输入探测目标');
  }
  if (host.contains(' ')) {
    return (host: host, error: '目标不能包含空格');
  }
  return (host: host, error: null);
}

/// 把 `DnsLookupResult.source` 翻成中文。`only upstream reaches a resolver`。
String dnsSourceLabel(String source) => switch (source) {
  'upstream' => '上游解析',
  'cache' => '缓存命中',
  'rewrite' => '覆写规则',
  'blocked' => '被规则拦截',
  _ => '查询失败',
};

/// `networkInfo` 的接口名存在与否决定「无网络」的文案。
String networkInterfaceLabel(NetworkInfoSnapshot snapshot) =>
    snapshot.interfaceName.isEmpty ? '无活动网络' : snapshot.interfaceName;

/// 延迟配色分档。负数/空值交给调用方渲染成破折号，这里只处理有效值。
String latencyText(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(1)} ms';

/// Dart side of `com.haoze.diting/vpn`.
///
/// The controller is intentionally transport-thin: every policy decision is
/// prepared by the Dart layer, and the platform side only applies it to the Go
/// engine. Keeping it abstract lets widget and state tests run without a
/// device.
library;

import 'package:flutter/services.dart';

const vpnChannelName = 'com.haoze.diting/vpn';
const expressVpnChannelName = 'com.haoze.diting/express_vpn';

class VpnStartRequest {
  const VpnStartRequest({
    required this.dnsConfig,
    required this.ruleSnapshot,
    required this.rewriteRules,
    this.outboundProxy = '',
    this.bypassLan = true,
    this.ipv6Mode = 'auto',
    this.excludedPackages = const [],
    this.blockedPackages = const [],
    this.inspectionPackages = const [],
    this.inspectionEnabled = false,
  });

  final String dnsConfig;
  final String ruleSnapshot;
  final String rewriteRules;
  final String outboundProxy;
  final bool bypassLan;
  final String ipv6Mode;

  /// `excluded_app_packages`: handed to `Builder.addDisallowedApplication`, so
  /// these apps bypass the TUN entirely and resolve with the system DNS.
  final List<String> excludedPackages;

  /// `blocked_app_packages`: resolved to UIDs natively and passed to
  /// `Engine.setBlockedUIDs`. 1.4.3 sends UIDs, not package names, because the
  /// engine sees UIDs on the packet path.
  final List<String> blockedPackages;

  /// `http_inspection_app_packages`: resolved to UIDs and passed to
  /// `Engine.setMitmAllowedUIDs`. Only these apps are intercepted; everything
  /// else is forwarded untouched.
  final List<String> inspectionPackages;

  /// `http_inspection_enabled` AND `https_inspection_ready`. Both must hold
  /// before MITM starts: without the CA installed in the user trust store,
  /// intercepting would break every HTTPS request in the selected apps.
  final bool inspectionEnabled;
}

class VpnStartResult {
  const VpnStartResult({
    required this.started,
    required this.needsPermission,
    this.error,
  });

  final bool started;
  final bool needsPermission;
  final String? error;

  factory VpnStartResult.fromMap(Object? raw) {
    final map = raw is Map ? raw : const {};
    return VpnStartResult(
      started: map['started'] == true,
      needsPermission: map['needsPermission'] == true,
      error: map['error'] as String?,
    );
  }
}

class VpnStatus {
  const VpnStatus({
    required this.running,
    required this.persisted,
    this.error,
    this.stats = const {},
  });

  final bool running;
  final bool persisted;
  final String? error;

  /// Engine counters (`queries`, `blocked`, `cacheHits`, ...); empty when the
  /// tunnel has not started or the platform has no Engine instance.
  final Map<String, Object?> stats;

  factory VpnStatus.fromMap(Object? raw) {
    final map = raw is Map ? raw : const {};
    final stats = map['stats'];
    return VpnStatus(
      running: map['running'] == true,
      persisted: map['persisted'] == true,
      error: map['error'] as String?,
      stats: stats is Map ? Map<String, Object?>.from(stats) : const {},
    );
  }
}

/// 一个瞬时速率采样（字节/秒）。
///
/// [unsupported] 表示「这条通道压根没有流量统计」——极速模式的窄 TUN 不注册
/// `EngineDataPlane.attachTraffic`，`diting_express` 也没有 `app_traffic_daily`
/// 表。它与「有统计但当前是 0 B/s」是两件事：前者页面上要说明缺失，后者是真实
/// 的空闲。
class VpnTrafficRates {
  const VpnTrafficRates({
    required this.running,
    required this.txBps,
    required this.rxBps,
    this.unsupported = false,
  });

  const VpnTrafficRates.idle()
    : running = false,
      txBps = 0,
      rxBps = 0,
      unsupported = false;

  final bool running;
  final double txBps;
  final double rxBps;
  final bool unsupported;

  factory VpnTrafficRates.fromMap(Object? raw) {
    final map = raw is Map ? raw : const {};
    double read(String key) => (map[key] as num?)?.toDouble() ?? 0;
    return VpnTrafficRates(
      running: map['running'] == true,
      txBps: read('txBps'),
      rxBps: read('rxBps'),
      unsupported: map['unsupported'] == true,
    );
  }
}

abstract class VpnController {
  /// Called after the system VPN consent dialog closes.
  void Function(bool granted)? onPrepareResult;

  /// Returns true when the app already holds VPN permission; otherwise opens
  /// the system dialog and returns false.
  Future<bool> prepare();

  Future<VpnStartResult> start(VpnStartRequest request);

  Future<void> stop();

  Future<VpnStatus> status();

  /// 实时上下行速率（`TrafficRateMonitor.snapshot()`）。
  ///
  /// 单独一个方法而不是塞进 [status]：仪表盘每秒轮询一次速率，而 `status` 还要
  /// 序列化引擎的计数器 JSON，用同一个调用会让 1 Hz 的读秒变成每秒一次重活。
  /// 通道缺失（桌面宿主 / 单元测试）时返回 [VpnTrafficRates.idle]，不抛异常。
  Future<VpnTrafficRates> trafficRates();
}

class MethodChannelVpnController implements VpnController {
  MethodChannelVpnController({MethodChannel? channel})
    : _channel = channel ?? MethodChannel(vpnChannelName);

  final MethodChannel _channel;
  bool _handlerInstalled = false;

  @override
  void Function(bool granted)? onPrepareResult;

  /// Installing the handler needs an initialized binding; provider tests build
  /// this object without one, so defer it until the first platform call.
  void _ensureHandler() {
    if (_handlerInstalled) return;
    _channel.setMethodCallHandler(_handleCall);
    _handlerInstalled = true;
  }

  Future<Object?> _handleCall(MethodCall call) async {
    if (call.method == 'onPrepareResult') {
      onPrepareResult?.call(call.arguments == true);
    }
    return null;
  }

  @override
  Future<bool> prepare() async {
    _ensureHandler();
    return await _channel.invokeMethod<bool>('prepare') ?? false;
  }

  @override
  Future<VpnStartResult> start(VpnStartRequest request) async {
    _ensureHandler();
    final result = await _channel.invokeMethod<Object?>('start', {
      'dnsConfig': request.dnsConfig,
      'ruleSnapshot': request.ruleSnapshot,
      'rewriteRules': request.rewriteRules,
      'outboundProxy': request.outboundProxy,
      'bypassLan': request.bypassLan,
      'ipv6Mode': request.ipv6Mode,
      'excludedPackages': request.excludedPackages,
      'blockedPackages': request.blockedPackages,
      'inspectionPackages': request.inspectionPackages,
      'inspectionEnabled': request.inspectionEnabled,
    });
    return VpnStartResult.fromMap(result);
  }

  @override
  Future<void> stop() {
    _ensureHandler();
    return _channel.invokeMethod<void>('stop');
  }

  @override
  Future<VpnStatus> status() async {
    _ensureHandler();
    return VpnStatus.fromMap(await _channel.invokeMethod<Object?>('status'));
  }

  @override
  Future<VpnTrafficRates> trafficRates() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('trafficRates');
      return VpnTrafficRates.fromMap(raw);
    } on MissingPluginException {
      // 没有原生实现（桌面宿主 / 组件画廊 / 纯 Dart 测试）：既不是「0 B/s」也
      // 不是错误，而是「这台设备没有这个数据源」。
      return const VpnTrafficRates(
        running: false,
        txBps: 0,
        rxBps: 0,
        unsupported: true,
      );
    } on PlatformException {
      return const VpnTrafficRates.idle();
    }
  }
}

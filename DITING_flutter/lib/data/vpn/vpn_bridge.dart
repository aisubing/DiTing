/// Dart side of `com.haoze.diting/vpn`.
///
/// The controller is intentionally transport-thin: every policy decision is
/// prepared by the Dart layer, and the platform side only applies it to the Go
/// engine. Keeping it abstract lets widget and state tests run without a
/// device.
library;

import 'package:flutter/services.dart';

const vpnChannelName = 'com.haoze.diting/vpn';

class VpnStartRequest {
  const VpnStartRequest({
    required this.dnsConfig,
    required this.ruleSnapshot,
    required this.rewriteRules,
    this.outboundProxy = '',
    this.bypassLan = true,
    this.ipv6Mode = 'auto',
    this.excludedPackages = const [],
  });

  final String dnsConfig;
  final String ruleSnapshot;
  final String rewriteRules;
  final String outboundProxy;
  final bool bypassLan;
  final String ipv6Mode;
  final List<String> excludedPackages;
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
  });

  final bool running;
  final bool persisted;
  final String? error;

  factory VpnStatus.fromMap(Object? raw) {
    final map = raw is Map ? raw : const {};
    return VpnStatus(
      running: map['running'] == true,
      persisted: map['persisted'] == true,
      error: map['error'] as String?,
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
}

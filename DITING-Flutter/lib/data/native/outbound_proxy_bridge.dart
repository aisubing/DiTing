/// Dart side of `com.haoze.diting/outbound_proxy`. Credentials sit in `dns_vpn_prefs` under an
/// AndroidKeyStore key Dart cannot reach, so the proxy is composed natively. The app package is
/// part of the config: Android lets only one app bind a loopback port.
library;

import 'package:flutter/services.dart';

/// Matches 1.4.3 `OutboundProxyProtocol`; `storageValue` is parsed by the Go engine.
enum OutboundProxyProtocol {
  socks5('socks5', 'SOCKS5'),
  http('http', 'HTTP CONNECT');

  const OutboundProxyProtocol(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static OutboundProxyProtocol fromStorageValue(String? value) =>
      values.firstWhere(
        (item) => item.storageValue == value,
        orElse: () => OutboundProxyProtocol.socks5,
      );
}

class OutboundProxyConfig {
  const OutboundProxyConfig({
    this.enabled = false,
    this.protocol = OutboundProxyProtocol.socks5,
    this.host = '127.0.0.1',
    this.port = 7890,
    this.username = '',
    this.password = '',
    this.proxyAppPackage = '',
    this.status = 'disabled',
    this.statusMessage = '',
  });

  final bool enabled;
  final OutboundProxyProtocol protocol;
  final String host;
  final int port;
  final String username;
  final String password;

  final String proxyAppPackage;

  /// Engine-reported state: `disabled`, `connecting`, `ready` or `error`.
  final String status;
  final String statusMessage;

  OutboundProxyConfig copyWith({
    bool? enabled,
    OutboundProxyProtocol? protocol,
    String? host,
    int? port,
    String? username,
    String? password,
    String? proxyAppPackage,
    String? status,
    String? statusMessage,
  }) => OutboundProxyConfig(
    enabled: enabled ?? this.enabled,
    protocol: protocol ?? this.protocol,
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    password: password ?? this.password,
    proxyAppPackage: proxyAppPackage ?? this.proxyAppPackage,
    status: status ?? this.status,
    statusMessage: statusMessage ?? this.statusMessage,
  );

  /// Mirrors `OutboundProxyConfig.validationError` in the same order, so the first offending field
  /// is reported identically; a null [installedPackages] skips the "not installed" check rather
  /// than failing closed.
  String? validationError({
    String? selfPackage,
    Set<String>? installedPackages,
  }) {
    if (host != '127.0.0.1' && host != '::1') {
      return '代理地址仅支持 127.0.0.1 或 ::1';
    }
    if (port < 1 || port > 65535) return '代理端口必须在 1 到 65535 之间';
    if (proxyAppPackage.trim().isEmpty) return '请选择提供本地代理端口的应用';
    if (selfPackage != null && proxyAppPackage == selfPackage) {
      return '不能选择 DITING 自身作为代理应用';
    }
    if (installedPackages != null &&
        !installedPackages.contains(proxyAppPackage)) {
      return '所选代理应用未安装';
    }
    if (username.length > 255 || password.length > 255) return '代理账号或密码过长';
    return null;
  }

  /// JSON handed to `Engine.configureOutboundProxy`. `port` must be a JSON number: Go unmarshals
  /// into `Port int` (`tunnel/flow_outbound.go:29`), and a string leaves the proxy silently
  /// disabled.
  String toEngineJson() {
    final encoded = <String, Object>{
      'enabled': enabled,
      'protocol': protocol.storageValue,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
    final parts = <String>[];
    for (final entry in encoded.entries) {
      final value = entry.value;
      parts.add(
        '"${entry.key}":${switch (value) {
          final bool flag => '$flag',
          final int number => '$number',
          _ => '"${_escape('$value')}"',
        }}',
      );
    }
    return '{${parts.join(',')}}';
  }

  static String _escape(String value) =>
      value.replaceAll('\\', r'\\').replaceAll('"', r'\"');

  static OutboundProxyConfig fromMap(Map<Object?, Object?> map) =>
      OutboundProxyConfig(
        enabled: map['enabled'] == true,
        protocol: OutboundProxyProtocol.fromStorageValue(
          map['protocol'] as String?,
        ),
        host: map['host'] as String? ?? '127.0.0.1',
        port: (map['port'] as num?)?.toInt() ?? 7890,
        username: map['username'] as String? ?? '',
        password: map['password'] as String? ?? '',
        proxyAppPackage: map['proxyAppPackage'] as String? ?? '',
        status: map['status'] as String? ?? 'disabled',
        statusMessage: map['statusMessage'] as String? ?? '',
      );
}

abstract class OutboundProxyStore {
  Future<OutboundProxyConfig> read();

  Future<void> write(OutboundProxyConfig config);

  Future<void> reset();

  /// Engine-reported status, persisted so the page can show it after a restart.
  Future<void> setStatus(String state, String message);
}

class MethodChannelOutboundProxyStore implements OutboundProxyStore {
  MethodChannelOutboundProxyStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.haoze.diting/outbound_proxy';

  final MethodChannel _channel;

  @override
  Future<OutboundProxyConfig> read() async {
    final raw = await _channel.invokeMethod<Object?>('read');
    return OutboundProxyConfig.fromMap(
      raw is Map ? Map<Object?, Object?>.from(raw) : const {},
    );
  }

  @override
  Future<void> write(OutboundProxyConfig config) =>
      _channel.invokeMethod<void>('write', {
        'enabled': config.enabled,
        'protocol': config.protocol.storageValue,
        'host': config.host,
        'port': config.port,
        'username': config.username,
        'password': config.password,
        'proxyAppPackage': config.proxyAppPackage,
      });

  @override
  Future<void> reset() => _channel.invokeMethod<void>('reset');

  @override
  Future<void> setStatus(String state, String message) => _channel
      .invokeMethod<void>('setStatus', {'state': state, 'message': message});
}

class MemoryOutboundProxyStore implements OutboundProxyStore {
  OutboundProxyConfig _config = const OutboundProxyConfig();

  @override
  Future<OutboundProxyConfig> read() async => _config;

  @override
  Future<void> write(OutboundProxyConfig config) async => _config = config;

  @override
  Future<void> reset() async => _config = const OutboundProxyConfig();

  @override
  Future<void> setStatus(String state, String message) async =>
      _config = _config.copyWith(status: state, statusMessage: message);
}

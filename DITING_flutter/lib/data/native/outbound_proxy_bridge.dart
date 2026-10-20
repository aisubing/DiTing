/// Dart side of `com.haoze.diting/outbound_proxy`.
///
/// 1.4.3 stored the outbound proxy in `dns_vpn_prefs` (`OutboundProxySettingsStore`)
/// with the username/password encrypted by an AndroidKeyStore AES-GCM key.
/// Dart cannot reach that keystore, so the credentials compose/decompose
/// natively; the *non-secret* fields still live in the same prefs file and are
/// readable through [LegacyPrefsBridge], keeping the on-disk layout unchanged
/// for an upgrade install.
///
/// Why a proxy app is mandatory: Android only lets one app bind a loopback port
/// at a time, and 1.4.3 refuses to let the user pick anything other than
/// `127.0.0.1` / `::1`. That makes "which app owns the port" part of the
/// configuration instead of something to autodetect.
library;

import 'package:flutter/services.dart';

/// Matches `OutboundProxyProtocol` in 1.4.3 (`storageValue` is what the Go
/// engine parses — lowercase, `socks5` / `http`).
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

/// The whole proxy configuration, secrets included (only in memory).
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

  /// Package that is expected to be listening on [host]:[port].
  final String proxyAppPackage;

  /// Engine-reported state (`disabled` / `connecting` / `ready` / `error`),
  /// fed by `OutboundProxyStatusCallback`.
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

  /// `OutboundProxyConfig.validationError`, in the same order so the first
  /// offending field is reported identically. [selfPackage] is passed in
  /// because Dart already knows its own application id.
  ///
  /// [installedPackages] is null when the caller could not enumerate apps; the
  /// "not installed" check is then skipped rather than failing closed.
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

  /// The JSON handed to `Engine.configureOutboundProxy` via `VpnStartRequest`.
  /// `protocol` uses [OutboundProxyProtocol.storageValue]; the Go side rejects
  /// anything else.
  ///
  /// `port` must be a JSON **number**, not a string: the Go side unmarshals into
  /// `outboundProxyConfig{Port int}` (`Android/tunnel/flow_outbound.go:29`), and
  /// `json.Unmarshal` rejects `"port":"7890"` with
  /// `invalid outbound proxy config: … cannot unmarshal string into Go struct
  /// field …Port of type int`. That error comes back from
  /// `Engine.configureOutboundProxy` and the whole proxy silently stays disabled,
  /// while 1.4.3's Kotlin producer (`toNativeJson`) emitted a real number.
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

/// Persistence for [OutboundProxyConfig] (`OutboundProxySettingsStore`).
abstract class OutboundProxyStore {
  Future<OutboundProxyConfig> read();

  /// Encrypts the credentials with the platform keystore and writes every key.
  Future<void> write(OutboundProxyConfig config);

  /// Removes all nine keys (1.4.3's `resetOutboundProxy`).
  Future<void> reset();

  /// Engine-reported status, written by `OutboundProxyStatusCallback` from the
  /// tunnel service so the settings page can show it after a restart.
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
  Future<void> setStatus(String state, String message) =>
      _channel.invokeMethod<void>('setStatus', {
        'state': state,
        'message': message,
      });
}

/// In-memory store for tests / non-Android hosts.
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

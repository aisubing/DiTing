/// Dart side of `com.haoze.diting/https_inspection`: `available` means the engine produced a CA,
/// `installed` means its SHA-256 matches an entry in the Android user CA store, the only store an
/// app can write.
library;

import 'package:flutter/services.dart';

const httpsInspectionChannelName = 'com.haoze.diting/https_inspection';

class CaCertificateState {
  const CaCertificateState({
    required this.available,
    required this.installed,
    this.fingerprintSha256,
    this.pem,
    this.error,
  });

  const CaCertificateState.missing()
    : available = false,
      installed = false,
      fingerprintSha256 = null,
      pem = null,
      error = null;

  final bool available;

  final bool installed;

  /// Uppercase colon-separated hex, the format 1.4.3 displayed verbatim.
  final String? fingerprintSha256;

  final String? pem;

  final String? error;

  /// Legacy `https_inspection_ready` flag: ready AND `ca_backend == "go-v1"`, set from [installed].
  bool get ready => available && installed;

  static CaCertificateState fromMap(Map<Object?, Object?> map) =>
      CaCertificateState(
        available: map['available'] == true,
        installed: map['installed'] == true,
        fingerprintSha256: map['fingerprintSha256'] as String?,
        pem: map['pem'] as String?,
        error: map['error'] as String?,
      );
}

abstract class CaCertificateService {
  /// Reads, and lazily generates, the CA; [regenerate] deletes `ca.crt`, `ca.key` and
  /// `mitm_blacklist.txt`, invalidating every certificate the device trusted.
  Future<CaCertificateState> inspect({bool regenerate = false});

  /// Writes the PEM to [uri] through `ContentResolver.openOutputStream`, so no storage permission
  /// is needed.
  Future<void> exportTo(String uri);

  /// Opens the system "install CA certificate" screen. Android offers no silent install.
  Future<bool> openInstallSettings();
}

class MethodChannelCaCertificateService implements CaCertificateService {
  MethodChannelCaCertificateService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(httpsInspectionChannelName);

  final MethodChannel _channel;

  @override
  Future<CaCertificateState> inspect({bool regenerate = false}) async {
    final raw = await _channel.invokeMethod<Object?>('inspectCa', {
      'regenerate': regenerate,
    });
    return CaCertificateState.fromMap(
      raw is Map ? Map<Object?, Object?>.from(raw) : const {},
    );
  }

  @override
  Future<void> exportTo(String uri) =>
      _channel.invokeMethod<void>('exportCa', {'uri': uri});

  @override
  Future<bool> openInstallSettings() async =>
      await _channel.invokeMethod<bool>('openCaInstallSettings') ?? false;
}

class UnavailableCaCertificateService implements CaCertificateService {
  const UnavailableCaCertificateService();

  @override
  Future<CaCertificateState> inspect({bool regenerate = false}) async =>
      const CaCertificateState.missing();

  @override
  Future<void> exportTo(String uri) async {}

  @override
  Future<bool> openInstallSettings() async => false;
}

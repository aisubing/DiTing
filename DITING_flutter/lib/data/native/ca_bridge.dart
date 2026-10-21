/// Dart side of `com.haoze.diting/https_inspection`: the MITM root CA.
///
/// 1.4.3 generated and validated the CA through `GoInspectionCaManager`, which
/// drives `Engine.startStackMitm(certDir)` to materialise `ca.crt` / `ca.key`
/// under `filesDir/go-mitm`. The Flutter port hardcoded a fingerprint instead,
/// so the CA page could not tell "not generated yet" from "generated but not
/// installed in the Android trust store".
///
/// Two facts matter and are often conflated:
/// - `available`: the engine produced a certificate (PEM readable, fingerprint
///   computable). Without this, HTTPS inspection cannot be enabled at all.
/// - `installed`: the certificate's SHA-256 matches an entry in
///   `AndroidCAStore` under `user:`. Only the *user* store counts — the system
///   store cannot be written by an app, and `GoInspectionCaManager.isInstalled`
///   filters on the `user:` alias prefix for exactly this reason.
library;

import 'package:flutter/services.dart';

const httpsInspectionChannelName = 'com.haoze.diting/https_inspection';

/// Result of inspecting the local CA.
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

  /// A certificate exists and can be exported.
  final bool available;

  /// The certificate is trusted by the Android user store.
  final bool installed;

  /// Colon-separated uppercase hex, e.g. `AB:CD:...` — the format
  /// `GoInspectionCaManager.fingerprint` produced and 1.4.3 displayed verbatim.
  final String? fingerprintSha256;

  /// PEM body, used for the "view certificate" sheet and for share/export.
  final String? pem;

  final String? error;

  /// `https_inspection_ready` in 1.4.3 is exactly this conjunction
  /// (`isHttpsInspectionReady` = ready flag AND `ca_backend == "go-v1"`), and
  /// `checkAndUpdateHttpsInspectionReady` sets the flag from [installed].
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

/// Root-CA lifecycle, mirroring `GoInspectionCaManager`.
abstract class CaCertificateService {
  /// Reads (and lazily generates) the CA. [regenerate] deletes `ca.crt` /
  /// `ca.key` / `mitm_blacklist.txt` first, which invalidates every certificate
  /// the device previously trusted — 1.4.3's `reset` + re-open path.
  Future<CaCertificateState> inspect({bool regenerate = false});

  /// Writes the PEM to [uri] via `ContentResolver.openOutputStream`. The URI
  /// comes from the system "save file" picker, so the app never needs storage
  /// permission.
  Future<void> exportTo(String uri);

  /// Opens the system "install a certificate → CA certificate" screen. Android
  /// gives the app no way to install it silently; this only navigates.
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

/// Non-Android host: no engine, no trust store.
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

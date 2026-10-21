/// MITM root-CA state, shared by the HTTPS-inspection page and the CA page.
///
/// The status shown here comes from `Engine.startStackMitm`, never from a
/// hardcoded string: 1.4.3 computed `available` (a certificate exists) and
/// `installed` (its SHA-256 is in the Android **user** trust store) separately,
/// and the old Flutter port replaced both with a constant fingerprint, so the CA
/// page could not tell "not generated yet" from "generated but not trusted".
///
/// Write-back rule (1.4.3's `checkAndUpdateHttpsInspectionReady`): after every
/// inspect, `https_inspection_ready` becomes `ready` (= available AND installed),
/// and when the certificate is not installed the master
/// `http_inspection_enabled` switch is forced to false — enabling interception
/// without a trusted CA makes every handshake fail.
library;

import 'package:diting/data/native/ca_bridge.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden in `main()` with [MethodChannelCaCertificateService].
///
/// The default reports a missing certificate, which is the truthful answer on any
/// host without the engine.
final caCertificateServiceProvider = Provider<CaCertificateService>(
  (ref) => const UnavailableCaCertificateService(),
);

/// Bumped to force a re-inspect (the pull-to-refresh path).
class CaCertificateRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final caCertificateRevisionProvider =
    NotifierProvider<CaCertificateRevision, int>(CaCertificateRevision.new);

/// Current CA state plus the three actions 1.4.3 exposes on the CA page.
///
/// The actions go through the controller instead of the raw service so the new
/// state lands in [state] without a second `inspect()`: minting the certificate
/// loads the Go engine (`libgojni.so` + a fresh CA), which is far too slow to run
/// twice for one tap.
class CaCertificateController extends AsyncNotifier<CaCertificateState> {
  @override
  Future<CaCertificateState> build() async {
    ref.watch(caCertificateRevisionProvider);
    final service = ref.watch(caCertificateServiceProvider);
    final state = await _guard(service.inspect);
    _syncLegacyFlags(state);
    return state;
  }

  /// Deletes `ca.crt` / `ca.key` and mints a new pair. Every previously trusted
  /// certificate stops matching, so `https_inspection_ready` drops to false.
  Future<CaCertificateState> regenerate() async {
    final service = ref.read(caCertificateServiceProvider);
    final state = await _guard(() => service.inspect(regenerate: true));
    _publish(state);
    return state;
  }

  /// Re-reads the CA without regenerating it (used after the user returns from
  /// the system "install certificate" screen).
  Future<CaCertificateState> refresh() async {
    final service = ref.read(caCertificateServiceProvider);
    final state = await _guard(service.inspect);
    _publish(state);
    return state;
  }

  /// Writes the PEM to a URI handed back by the system save-file picker.
  Future<void> exportTo(String uri) async {
    try {
      await ref.read(caCertificateServiceProvider).exportTo(uri);
    } on MissingPluginException {
      // Nothing to report: no picker, no channel, no export (see the page note
      // about the copyable PEM fallback).
    } on PlatformException {
      // The service surfaces the reason through `inspect()`'s `error` on the
      // next refresh; swallowing here keeps the page from throwing.
    }
  }

  /// Opens Android's "install a certificate" screen; returns false when the
  /// platform refused to launch it.
  Future<bool> openInstallSettings() async {
    try {
      return await ref.read(caCertificateServiceProvider).openInstallSettings();
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  void _publish(CaCertificateState next) {
    state = AsyncData(next);
    _syncLegacyFlags(next);
    // SharedPreferences writes are unobservable; every screen reading the
    // HTTPS switches must be told explicitly.
    ref.read(legacySettingsRevisionProvider.notifier).bump();
  }

  /// Folds channel failures into the state instead of throwing: a page cannot
  /// render an exception, and the CA page has a dedicated `error` row.
  Future<CaCertificateState> _guard(
    Future<CaCertificateState> Function() call,
  ) async {
    try {
      return await call();
    } on MissingPluginException catch (error) {
      return CaCertificateState(
        available: false,
        installed: false,
        error: '证书通道不可用：${error.message ?? '未注册'}',
      );
    } on PlatformException catch (error) {
      final message = (error.message ?? '').trim();
      return CaCertificateState(
        available: false,
        installed: false,
        error: message.isEmpty ? '读取根证书失败（${error.code}）' : '读取根证书失败：$message',
      );
    }
  }

  /// `https_inspection_ready` ← `ready`, and drop the master switch when the
  /// certificate is not trusted. Idempotent, so running it on every inspect is
  /// safe; it deliberately does not bump the legacy revision itself (that would
  /// invalidate this provider and loop).
  void _syncLegacyFlags(CaCertificateState state) {
    final settings = ref.read(legacySettingsProvider);
    if (settings.httpsInspectionReady != state.ready) {
      settings.setHttpsInspectionReady(state.ready);
    }
    if (!state.ready && settings.httpInspectionEnabled) {
      settings.setHttpInspectionApps(
        packages: settings.httpInspectionPackages,
        enabled: false,
      );
    }
  }
}

final caCertificateStateProvider =
    AsyncNotifierProvider<CaCertificateController, CaCertificateState>(
      CaCertificateController.new,
    );

/// Reads the CA without throwing; `null` until the first inspect finishes.
final caReadyProvider = Provider<bool>((ref) {
  return ref.watch(caCertificateStateProvider).value?.ready ?? false;
});

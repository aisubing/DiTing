/// Work mode, power state, provider selection and server mode.
library;

import 'dart:async';

import 'package:diting/data/mock_data.dart';
import 'package:diting/data/notifications/notification_status_text.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/data/vpn/vpn_bridge.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/outbound_proxy_providers.dart';
import 'package:diting/state/provider_catalog_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:diting/state/provider_catalog_providers.dart';

/// The three work modes: `normal` (full-tunnel Go), `server` (DNS-only LAN), `express` (narrow
/// Kotlin route).
enum AppWorkMode {
  normal('普通模式', '推荐', '全量域名解析、黑白名单、HTTPS 检查、网络管控', 'normal'),
  server('服务器模式', '轻量', '纯 DNS 代理与解析加速、低功耗', 'dns'),
  express('极速模式', '极速', '纯 Kotlin、DNS 加速与规则过滤、Android 7+（64 位）', 'express');

  const AppWorkMode(this.title, this.badge, this.summary, this.storageValue);

  final String title;
  final String badge;
  final String summary;

  /// Persisted legacy `app_work_mode` value; server mode is still stored as `dns`.
  final String storageValue;

  static AppWorkMode fromStorageValue(String? value) => values.firstWhere(
    (mode) => mode.storageValue == value,
    orElse: () => normal,
  );
}

/// Power state machine; the error state is server-mode only.
enum PowerState {
  stopped('已停止'),
  starting('启动中'),
  running('运行中'),
  stopping('停止中'),
  error('启动失败');

  const PowerState(this.label);

  final String label;

  bool get isBusy => this == starting || this == stopping;

  bool get isRunning => this == running;
}

/// Work mode and power state share a notifier: switching mode stops the other service.
class WorkModeNotifier extends Notifier<AppWorkMode> {
  @override
  AppWorkMode build() => AppWorkMode.fromStorageValue(
    ref.read(legacySettingsProvider).workModeRaw,
  );

  void select(AppWorkMode mode) {
    final previous = state;
    // Stop before publishing: the channel is picked from the current mode.
    if (previous != mode) {
      final power = ref.read(powerProvider);
      if (power.isRunning || power == PowerState.starting) {
        unawaited(ref.read(powerProvider.notifier).stop());
      }
    }
    // Persist, then bump, then publish: the dataset-aware settings view has to point at the new
    // mode's container by the time dependents rebuild.
    ref.read(legacySettingsProvider).setWorkModeRaw(mode.storageValue);
    ref.read(legacySettingsRevisionProvider.notifier).bump();
    state = mode;
  }
}

final workModeProvider = NotifierProvider<WorkModeNotifier, AppWorkMode>(
  WorkModeNotifier.new,
);

/// Real normal-mode tunnel control; tests override it with a fake.
final vpnControllerProvider = Provider<VpnController>(
  (ref) => MethodChannelVpnController(),
);

/// Express mode uses the same contract on its own channel.
final expressVpnControllerProvider = Provider<VpnController>(
  (ref) =>
      MethodChannelVpnController(channel: MethodChannel(expressVpnChannelName)),
);

class PowerNotifier extends Notifier<PowerState> {
  /// Deadline for `onPrepareResult`: it travels through the activity result and can be lost on
  /// recreate.
  static const Duration _consentTimeout = Duration(seconds: 90);

  /// Deadline for a consented start; `start()` returns once scheduled.
  static const Duration _launchTimeout = Duration(seconds: 30);

  bool _disposed = false;
  bool _pendingPermissionStart = false;
  Timer? _statsTimer;
  Timer? _guardTimer;

  /// Last bridge failure, kept for diagnostics while the UI shows a generic label.
  String? lastError;

  bool get _isExpress => ref.read(workModeProvider) == AppWorkMode.express;

  VpnController get _controller => _isExpress
      ? ref.read(expressVpnControllerProvider)
      : ref.read(vpnControllerProvider);

  @override
  PowerState build() {
    ref.onDispose(() {
      _disposed = true;
      _statsTimer?.cancel();
      _guardTimer?.cancel();
    });
    ref.read(vpnControllerProvider).onPrepareResult = _onPrepareResult;
    ref.read(expressVpnControllerProvider).onPrepareResult = _onPrepareResult;
    final settings = ref.read(legacySettingsProvider);
    final persisted = _isExpress
        ? settings.expressVpnRunning
        : settings.vpnRunning;
    if (persisted) {
      // The legacy flag survives process death, so confirm with the native side.
      scheduleMicrotask(syncStatus);
      _armGuard(_launchTimeout);
      return PowerState.starting;
    }
    return PowerState.stopped;
  }

  Future<void> syncStatus() async {
    // Capture the dataset before awaiting: a concurrent switch must not write it.
    final mode = ref.read(workModeProvider);
    final express = mode == AppWorkMode.express;
    // Resolved before the await, so a mode switch cannot redirect this round trip.
    final controller = express
        ? ref.read(expressVpnControllerProvider)
        : ref.read(vpnControllerProvider);
    final settings = ref.read(legacySettingsProvider);
    try {
      final status = await controller.status();
      if (_disposed) return;
      if (express) {
        settings.setExpressVpnRunning(status.running);
      } else {
        settings.setVpnRunning(status.running);
      }
      if (status.error != null && !status.running) {
        lastError = status.error;
        state = PowerState.error;
      } else {
        state = status.running ? PowerState.running : PowerState.stopped;
      }
      _guardTimer?.cancel();
      ref
          .read(serviceStatsProvider.notifier)
          .applyNative(
            status.stats,
            running: status.running,
            // Server mode owns the counters there; this plane's "not running" is expected.
            ownsStats: mode != AppWorkMode.server,
            startedAt: status.startedAt,
          );
      if (status.running) {
        _ensureStatsPolling();
      } else {
        _cancelStatsPolling();
      }
    } catch (_) {
      if (!_disposed) {
        state = PowerState.stopped;
        _guardTimer?.cancel();
      }
    }
  }

  Future<void> toggle() async {
    if (state.isBusy) return;
    if (state.isRunning) {
      await stop();
      return;
    }
    await _start();
  }

  /// Stops the tunnel; server mode calls it first so the two data planes never coexist.
  Future<void> stopIfActive() async {
    if (state.isRunning || state == PowerState.starting) {
      await stop();
    }
  }

  Future<void> _start() async {
    final mode = ref.read(workModeProvider);
    if (mode != AppWorkMode.normal && mode != AppWorkMode.express) {
      _fail('当前工作模式尚未接入数据面');
      return;
    }
    state = PowerState.starting;
    lastError = null;
    _armGuard(_launchTimeout);
    try {
      final prepared = await _controller.prepare();
      if (_disposed) return;
      if (!prepared) {
        // The consent dialog is showing; _onPrepareResult continues the flow.
        _pendingPermissionStart = true;
        // It can be lost on recreate or dismissal, so do not wait forever.
        _armGuard(_consentTimeout);
        return;
      }
      await _launch(mode);
    } catch (error) {
      _fail(error);
    }
  }

  /// Restarts the start watchdog; on expiry it asks the service for its real state.
  void _armGuard(Duration timeout) {
    _guardTimer?.cancel();
    _guardTimer = Timer(timeout, () {
      if (_disposed) return;
      final pending = _pendingPermissionStart;
      _pendingPermissionStart = false;
      if (state != PowerState.starting && state != PowerState.stopping) return;
      if (state == PowerState.stopping) {
        // A wedged stop: the flag is already correct, so converge to idle.
        state = PowerState.stopped;
        return;
      }
      if (pending) {
        // Consent never came back, so asking for status would hide the failure.
        _fail('没有获得 VPN 授权');
        return;
      }
      syncStatus().then((_) {
        if (_disposed) return;
        if (state != PowerState.starting) return;
        _fail('服务启动超时');
      });
    });
  }

  Future<void> _onPrepareResult(bool granted) async {
    if (!_pendingPermissionStart) return;
    _pendingPermissionStart = false;
    // Consent arrived: the consent deadline is over, the launch deadline still runs.
    _armGuard(_launchTimeout);
    if (_disposed) return;
    if (!granted) {
      state = PowerState.stopped;
      return;
    }
    try {
      await _launch(ref.read(workModeProvider));
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _launch(AppWorkMode mode) async {
    if (ref.read(workModeProvider) != mode) {
      // The user switched modes while the consent dialog was open.
      state = PowerState.stopped;
      return;
    }
    final express = mode == AppWorkMode.express;
    // One DNS config for every mode. The UI writes these keys to `dns_vpn_prefs` regardless of the
    // work mode, so reading the express dataset container here made the engine (and the
    // notification) ignore every provider/resolution change made in the app.
    final settings = ref.read(legacySettingsProvider);

    // Rules are no longer loaded or shipped here: the service builds the engine
    // snapshot in its own process (trie files + inline extras), so a large
    // subscription can no longer blow the Binder transaction limit.
    final config = buildDnsConfig(settings);
    // The service only sees the config JSON, so the body is composed here and read back from
    // prefs by the notification builder. Both VPN modes share one shape; the mode is the title.
    final statusText = defaultRunningNotificationText(settings);
    if (express) {
      settings.setNotificationDefaultExpressText(statusText);
    } else {
      settings.setNotificationDefaultRunningText(statusText);
    }
    final controller = express
        ? ref.read(expressVpnControllerProvider)
        : ref.read(vpnControllerProvider);
    final proxy = await ref.read(outboundProxyStoreProvider).read();
    if (_disposed) return;
    // A half-filled config fails validation and is dropped rather than failing the start.
    final proxyUsable = proxy.enabled && proxy.validationError() == null;
    final result = await controller.start(
      VpnStartRequest(
        dnsConfig: config.encode(settings),
        outboundProxy: proxyUsable ? proxy.toEngineJson() : '',
        // The service disallows it in the TUN so the proxy's own dials skip the tunnel.
        proxyAppPackage: proxyUsable ? proxy.proxyAppPackage : '',
        bypassLan: express ? false : settings.bypassLanEnabled,
        ipv6Mode: settings.ipv6ModeRaw,
        excludedPackages: settings.excludedPackages.toList(),
        // Express is a narrow DNS-only route, so app-level inputs are ignored.
        blockedPackages: express
            ? const []
            : settings.blockedAppPackages.toList(),
        inspectionPackages: express
            ? const []
            : settings.httpInspectionPackages.toList(),
        // 1.4.3 requires the CA before MITM may start; the transport re-checks.
        inspectionEnabled: !express && settings.httpsInspectionOperational,
      ),
    );
    if (_disposed) return;
    if (!result.started) {
      _fail(result.error ?? 'VPN 启动失败');
      return;
    }
    if (express) {
      settings.setExpressVpnRunning(true);
    } else {
      settings.setVpnRunning(true);
    }
    ref.read(serviceStatsProvider.notifier).markStarted();
    state = PowerState.running;
    _guardTimer?.cancel();
    _ensureStatsPolling();
    // First counters land shortly after start; refresh once early.
    Timer(const Duration(milliseconds: 700), syncStatus);
  }

  void _ensureStatsPolling() {
    // One second: the status card shows uptime to the second, and a slower tick made the
    // figure jump in 5-second steps.
    _statsTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => syncStatus(),
    );
  }

  void _cancelStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  Future<void> stop() async {
    final express = _isExpress;
    _cancelStatsPolling();
    _pendingPermissionStart = false;
    state = PowerState.stopping;
    // The stop channel answers immediately; a deadline catches a wedge.
    _armGuard(_launchTimeout);
    try {
      await (express
              ? ref.read(expressVpnControllerProvider)
              : ref.read(vpnControllerProvider))
          .stop();
    } catch (error) {
      lastError = _messageOf(error);
    }
    if (_disposed) return;
    final settings = ref.read(legacySettingsProvider);
    if (express) {
      settings.setExpressVpnRunning(false);
    } else {
      settings.setVpnRunning(false);
    }
    ref.read(serviceStatsProvider.notifier).reset();
    state = PowerState.stopped;
  }

  void _fail(Object error) {
    _pendingPermissionStart = false;
    _guardTimer?.cancel();
    lastError = error is String ? error : _messageOf(error);
    final settings = ref.read(legacySettingsProvider);
    settings.setVpnRunning(false);
    settings.setExpressVpnRunning(false);
    state = PowerState.error;
  }

  static String _messageOf(Object error) => error is PlatformException
      ? (error.message ?? error.code)
      : error.toString();

  void fail() => state = PowerState.error;

  void reset() => state = PowerState.stopped;
}

final powerProvider = NotifierProvider<PowerNotifier, PowerState>(
  PowerNotifier.new,
);

/// Service statistics shared by server mode and the log page.
class ServiceStatsNotifier extends Notifier<ServiceStats> {
  static const zero = ServiceStats(
    queries: 0,
    cacheHits: 0,
    blocked: 0,
    averageLatencyMs: 0,
    uptime: Duration.zero,
  );

  /// Origin of the uptime figure. Preference order: the native start timestamp (survives a
  /// recreated UI process), then the local clock from [markStarted].
  DateTime? _startedAt;

  @override
  ServiceStats build() => zero;

  void reset() {
    _startedAt = null;
    state = zero;
  }

  /// Called when a tunnel reports `running` for the first time.
  void markStarted() {
    _startedAt = DateTime.now();
    state = zero;
  }

  /// Replaces the mock counters with the Go engine's real ones.
  ///
  /// [startedAt] is the service's own start time. It wins over the locally observed one so a
  /// recreated UI process shows the real uptime instead of starting again from zero.
  ///
  /// [ownsStats] is false when the caller's plane is not the one the current work mode drives.
  /// Only one data plane can run at a time, so a non-owner always reports `running: false`; acting
  /// on that would zero the live uptime the owner just published (the status card flashed `0秒`
  /// for a second whenever both notifiers re-synced on resume).
  void applyNative(
    Map<String, Object?> stats, {
    required bool running,
    bool ownsStats = true,
    DateTime? startedAt,
  }) {
    if (!ownsStats) return;
    if (!running) {
      reset();
      return;
    }
    _startedAt = startedAt ?? _startedAt ?? DateTime.now();
    int read(String key) => (stats[key] as num?)?.toInt() ?? 0;
    final elapsed = DateTime.now().difference(_startedAt!);
    state = ServiceStats(
      queries: read('queries'),
      cacheHits: read('cacheHits'),
      blocked: read('blocked'),
      averageLatencyMs: 0,
      // A device clock that moved backwards must not show a negative duration.
      uptime: elapsed.isNegative ? Duration.zero : elapsed,
    );
  }

  void bump() {
    state = ServiceStats(
      queries: state.queries + 1,
      cacheHits: state.cacheHits + (state.queries.isEven ? 1 : 0),
      blocked: state.blocked,
      averageLatencyMs: state.averageLatencyMs,
      uptime: state.uptime + const Duration(seconds: 1),
    );
  }
}

final serviceStatsProvider =
    NotifierProvider<ServiceStatsNotifier, ServiceStats>(
      ServiceStatsNotifier.new,
    );

/// Whether the home page has picked a work mode (onboarding marker).
class WorkModeSelectedNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(legacySettingsProvider).workModeSelected;

  void markSelected() {
    state = true;
    ref.read(legacySettingsProvider).setWorkModeSelected(true);
  }

  void reset() {
    state = false;
    ref.read(legacySettingsProvider).clearWorkModeSelection();
  }
}

final workModeSelectedProvider =
    NotifierProvider<WorkModeSelectedNotifier, bool>(
      WorkModeSelectedNotifier.new,
    );

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(legacySettingsProvider).modeOnboardingCompleted;

  void complete() {
    state = true;
    ref.read(legacySettingsProvider).setModeOnboardingCompleted(true);
  }

  void reset() {
    state = false;
    ref.read(legacySettingsProvider).setModeOnboardingCompleted(false);
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

/// Provider summary text for the home `resolutionMode` (upstream `raceProviderSummary`).
String raceProviderSummary(Set<String> ids) =>
    summaryOfProviders(ids, defaultProviderCatalog());

/// Endpoint text; must use `.label`, since `toString()` leaks `ProviderProtocol.doh`.
String providerEndpointOf(String id) =>
    endpointOfProvider(id, defaultProviderCatalog());

/// Convenience read of the resolution mode from `appearance_providers.dart`.
ResolutionMode resolutionModeOf(Ref ref) => ref.read(resolutionModeProvider);

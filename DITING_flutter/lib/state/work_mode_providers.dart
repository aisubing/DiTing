/// 演示用状态：工作模式、电源状态、服务商选择、服务器模式。
library;

import 'dart:async';

import 'package:diting/data/db/rule_providers.dart';
import 'package:diting/data/db/rule_snapshot.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/data/vpn/vpn_bridge.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 三种工作模式（上游 `ui/mode/AppWorkMode.kt`）。
///
/// 语义陷阱（`docs/refactor/14-migration-strategy.md` §5）：上游的
/// `normal` 指「全隧道 Go 模式」、`server` 指「纯 DNS 局域网服务」、
/// `express` 指「纯 Kotlin 窄路由」。这里沿用同一命名，避免与规格对不上。
enum AppWorkMode {
  normal(
    '普通模式',
    '推荐',
    '全量域名解析、黑白名单、HTTPS 检查、网络管控',
    'normal',
  ),
  server('服务器模式', '轻量', '纯 DNS 代理与解析加速、低功耗', 'dns'),
  express(
    '极速模式',
    '极速',
    '纯 Kotlin、DNS 加速与规则过滤、Android 7+（64 位）',
    'express',
  );

  const AppWorkMode(this.title, this.badge, this.summary, this.storageValue);

  final String title;
  final String badge;
  final String summary;

  /// 旧版 `app_work_mode` 的落盘值：服务器模式仍写作 `dns`。
  final String storageValue;

  static AppWorkMode fromStorageValue(String? value) => values.firstWhere(
    (mode) => mode.storageValue == value,
    orElse: () => normal,
  );
}

/// 电源状态机：停止 / 启动中 / 运行 / 停止中（上游 `PowerToggleButton` 三态，
/// 服务器模式另有 ERROR）。
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

/// 工作模式 + 电源状态放在一个 Notifier 里：两者在真实实现中互相牵连
/// （切换模式会停止另一个模式的服务），拆开会漏掉这种约束。
class WorkModeNotifier extends Notifier<AppWorkMode> {
  @override
  AppWorkMode build() =>
      AppWorkMode.fromStorageValue(ref.read(legacySettingsProvider).workModeRaw);

  void select(AppWorkMode mode) {
    final previous = state;
    // Stop before publishing the new mode: the notifier picks its platform
    // channel from the current mode, so flipping state first would send the
    // stop to the wrong service.
    if (previous != mode) {
      final power = ref.read(powerProvider);
      if (power.isRunning || power == PowerState.starting) {
        unawaited(ref.read(powerProvider.notifier).stop());
      }
    }
    state = mode;
    ref.read(legacySettingsProvider).setWorkModeRaw(mode.storageValue);
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
  (ref) => MethodChannelVpnController(
    channel: MethodChannel(expressVpnChannelName),
  ),
);

class PowerNotifier extends Notifier<PowerState> {
  bool _disposed = false;
  bool _pendingPermissionStart = false;

  /// Last failure surfaced by the platform bridge; the UI shows the generic
  /// [PowerState.error] label, but keeping the reason here makes device
  /// diagnostics possible without a debugger.
  String? lastError;

  bool get _isExpress => ref.read(workModeProvider) == AppWorkMode.express;

  VpnController get _controller => _isExpress
      ? ref.read(expressVpnControllerProvider)
      : ref.read(vpnControllerProvider);

  @override
  PowerState build() {
    ref.onDispose(() => _disposed = true);
    ref.read(vpnControllerProvider).onPrepareResult = _onPrepareResult;
    ref.read(expressVpnControllerProvider).onPrepareResult = _onPrepareResult;
    final settings = ref.read(legacySettingsProvider);
    final persisted = _isExpress
        ? settings.expressVpnRunning
        : settings.vpnRunning;
    if (persisted) {
      // The legacy flag survives process death; ask the service whether the
      // tunnel is really alive before showing "running".
      scheduleMicrotask(syncStatus);
      return PowerState.starting;
    }
    return PowerState.stopped;
  }

  Future<void> syncStatus() async {
    // Capture the dataset before awaiting: a mode switch during the platform
    // round-trip must not write the other mode's flag.
    final express = _isExpress;
    final settings = ref.read(legacySettingsProvider);
    try {
      final status = await _controller.status();
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
      ref
          .read(serviceStatsProvider.notifier)
          .applyNative(status.stats, running: status.running);
    } catch (_) {
      if (!_disposed) state = PowerState.stopped;
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

  /// Stops the tunnel only when it is running or starting; server mode calls
  /// this before binding its port so both data planes never coexist.
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
    try {
      final prepared = await _controller.prepare();
      if (_disposed) return;
      if (!prepared) {
        // The consent dialog is showing; _onPrepareResult continues the flow.
        _pendingPermissionStart = true;
        return;
      }
      await _launch(mode);
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _onPrepareResult(bool granted) async {
    if (!_pendingPermissionStart) return;
    _pendingPermissionStart = false;
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
    final baseSettings = ref.read(legacySettingsProvider);
    final settings = express ? baseSettings.forExpress() : baseSettings;
    final rules = await _rulesFor(express);
    if (_disposed) return;

    final config = buildDnsConfig(settings);
    final controller = express
        ? ref.read(expressVpnControllerProvider)
        : ref.read(vpnControllerProvider);
    final result = await controller.start(
      VpnStartRequest(
        dnsConfig: config.encode(settings),
        ruleSnapshot: encodeRuleSnapshot(rules),
        rewriteRules: encodeRewriteRules(rules),
        bypassLan: express ? false : settings.bypassLanEnabled,
        ipv6Mode: settings.ipv6ModeRaw,
        excludedPackages: settings.excludedPackages.toList(),
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
  }

  /// Express keeps its own database; a fresh install legitimately has none, so
  /// an empty rule set is the correct fallback (unlike normal mode, which shows
  /// the bundled presets).
  Future<Map<RuleKind, List<MockRule>>> _rulesFor(bool express) async {
    if (!express) {
      final repository = ref.read(ruleRepositoryProvider);
      return repository == null
          ? ref.read(initialRulesProvider)
          : await repository.loadAll();
    }
    try {
      final repository = await ref.read(expressRuleRepositoryProvider.future);
      return repository == null
          ? <RuleKind, List<MockRule>>{}
          : await repository.loadAll();
    } catch (_) {
      return <RuleKind, List<MockRule>>{};
    }
  }

  Future<void> stop() async {
    final express = _isExpress;
    state = PowerState.stopping;
    try {
      await (express
          ? ref.read(expressVpnControllerProvider)
          : ref.read(vpnControllerProvider)).stop();
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

/// 当前选中的解析服务商。
class SelectedProviderNotifier extends Notifier<String> {
  @override
  String build() => mockProviders.first.id;

  /// 忽略未知 id——服务商列表是编译期常量，UI 不该能把状态写成空悬引用。
  void select(String id) {
    if (mockProviders.any((provider) => provider.id == id)) {
      state = id;
    }
  }
}

final selectedProviderProvider =
    NotifierProvider<SelectedProviderNotifier, String>(
      SelectedProviderNotifier.new,
    );

/// 多路模式下的服务商集合。竞速至少要 2 家，否则「取最先返回」没有意义。
class RaceProvidersNotifier extends Notifier<Set<String>> {
  static const minCount = 2;

  @override
  Set<String> build() => {mockProviders.first.id, mockProviders[1].id};

  /// 返回 false 表示被下限挡住（调用方据此提示用户）。
  bool toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) {
      next.add(id);
    } else if (next.length < minCount) {
      return false;
    }
    state = next;
    return true;
  }

  void reset() => state = {mockProviders.first.id, mockProviders[1].id};
}

final raceProvidersProvider =
    NotifierProvider<RaceProvidersNotifier, Set<String>>(
      RaceProvidersNotifier.new,
    );

/// 服务统计（服务器模式 / 日志页共用）。
class ServiceStatsNotifier extends Notifier<ServiceStats> {
  static const zero = ServiceStats(
    queries: 0,
    cacheHits: 0,
    blocked: 0,
    averageLatencyMs: 0,
    uptime: Duration.zero,
  );

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
  void applyNative(Map<String, Object?> stats, {required bool running}) {
    if (!running) {
      reset();
      return;
    }
    _startedAt ??= DateTime.now();
    int read(String key) => (stats[key] as num?)?.toInt() ?? 0;
    state = ServiceStats(
      queries: read('queries'),
      cacheHits: read('cacheHits'),
      blocked: read('blocked'),
      averageLatencyMs: 0,
      uptime: DateTime.now().difference(_startedAt!),
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

/// 首页是否已经选过工作模式（引导完成标记）。
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

/// 引导是否已完成（三步流程）。
class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void complete() => state = true;

  void reset() => state = false;
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

/// 首页 `resolutionMode` 对应的服务商摘要文案（上游 `raceProviderSummary`）。
String raceProviderSummary(Set<String> ids) {
  final names = [
    for (final provider in mockProviders)
      if (ids.contains(provider.id)) provider.name,
  ];
  if (names.isEmpty) {
    return '未选择服务商';
  }
  if (names.length == 1) {
    return names.first;
  }
  return '已选 ${names.length} 个：${names.join('、')}';
}

/// 单服务商模式下服务商的端点文案。
///
/// 必须拼 `.label`——枚举的 `toString()` 给的是 `ProviderProtocol.doh`，直接插值
/// 会把源码标识符漏到界面上。多个调用方都踩过这一点，所以这里是唯一出口，
/// 页面不要再自己拼。
String providerEndpointOf(String id) {
  final provider = mockProviders.firstWhere(
    (candidate) => candidate.id == id,
    orElse: () => mockProviders.first,
  );
  return '${provider.protocol.label} · ${provider.address}';
}

/// 让 `appearance_providers.dart` 的解析模式参与首页分支的便捷读取。
ResolutionMode resolutionModeOf(Ref ref) => ref.read(resolutionModeProvider);


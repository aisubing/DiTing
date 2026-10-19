/// 演示用状态：工作模式、电源状态、服务商选择、服务器模式。
library;

import 'package:diting/data/mock_data.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 三种工作模式（上游 `ui/mode/AppWorkMode.kt`）。
///
/// 语义陷阱（`docs/refactor/14-migration-strategy.md` §5）：上游的
/// `normal` 指「全隧道 Go 模式」、`server` 指「纯 DNS 局域网服务」、
/// `express` 指「纯 Kotlin 窄路由」。这里沿用同一命名，避免与规格对不上。
enum AppWorkMode {
  normal('普通模式', '推荐', '全量域名解析、黑白名单、HTTPS 检查、网络管控'),
  server('服务器模式', '轻量', '纯 DNS 代理与解析加速、低功耗'),
  express('极速模式', '极速', '纯 Kotlin、DNS 加速与规则过滤、Android 7+（64 位）');

  const AppWorkMode(this.title, this.badge, this.summary);

  final String title;
  final String badge;
  final String summary;
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
  AppWorkMode build() => AppWorkMode.normal;

  void select(AppWorkMode mode) => state = mode;
}

final workModeProvider = NotifierProvider<WorkModeNotifier, AppWorkMode>(
  WorkModeNotifier.new,
);

class PowerNotifier extends Notifier<PowerState> {
  @override
  PowerState build() => PowerState.stopped;

  /// 模拟一次 900ms 的启动/停止。演示层不用真实定时器之外的东西，
  /// 但必须让「启动中」这个中间态可见，否则三态按钮等于没演示。
  Future<void> toggle() async {
    if (state.isBusy) {
      return;
    }
    final wasRunning = state.isRunning;
    state = wasRunning ? PowerState.stopping : PowerState.starting;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    state = wasRunning ? PowerState.stopped : PowerState.running;
  }

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

/// 服务器模式的监听端口。
class ServerPortNotifier extends Notifier<int> {
  @override
  int build() => 5353;

  void set(int port) => state = port.clamp(1024, 65535);
}

final serverPortProvider = NotifierProvider<ServerPortNotifier, int>(
  ServerPortNotifier.new,
);

/// 服务器模式的 5 态状态卡。
enum ServerStatus {
  stopped('已停止'),
  starting('启动中'),
  running('运行中'),
  stopping('停止中'),
  error('异常');

  const ServerStatus(this.label);

  final String label;
}

class ServerStatusNotifier extends Notifier<ServerStatus> {
  @override
  ServerStatus build() => ServerStatus.stopped;

  Future<void> toggle() async {
    final running = state == ServerStatus.running;
    state = running ? ServerStatus.stopping : ServerStatus.starting;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    state = running ? ServerStatus.stopped : ServerStatus.running;
  }
}

final serverStatusProvider =
    NotifierProvider<ServerStatusNotifier, ServerStatus>(
      ServerStatusNotifier.new,
    );

/// 服务统计（服务器模式 / 日志页共用）。
class ServiceStatsNotifier extends Notifier<ServiceStats> {
  @override
  ServiceStats build() => mockServiceStats;

  void reset() => state = mockServiceStats;

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
  bool build() => false;

  void markSelected() => state = true;

  void reset() => state = false;
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
String providerEndpointOf(String id) {
  final provider = mockProviders.firstWhere(
    (candidate) => candidate.id == id,
    orElse: () => mockProviders.first,
  );
  return '${provider.protocol} · ${provider.address}';
}

/// 让 `appearance_providers.dart` 的解析模式参与首页分支的便捷读取。
ResolutionMode resolutionModeOf(Ref ref) => ref.read(resolutionModeProvider);

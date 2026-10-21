/// 仪表盘的实时数据层：速率序列 / 累计流量 / 内核状态。
///
/// ## 三个数据来源
/// - **速率序列**（[speedSeriesProvider]）：每秒向原生侧取一次
///   `VpnBridge.trafficRates` → `TrafficRateMonitor.snapshot()`，也就是常驻通知
///   里那个 ↑/↓ 读数用的同一份数字。极速模式与没有通道的宿主返回
///   `unsupported`，页面据此说明缺失，而不是画一条 0 的平线冒充「没有流量」。
/// - **累计流量**（[trafficTotalsProvider]）：旧库 `app_traffic_daily` 今日行的
///   `tx_bytes` / `rx_bytes` 求和，与流量页同一份数据。
/// - **内核状态**（[coreStateProvider]）：`powerProvider` / `serverStatusProvider`
///   的真实状态机映射，不再是一个永远 `running` 的内存变量。
///
/// 刻意**不**把定时器放进 provider 构造函数：那样每个 watch 都会起一个 timer。
/// 用 [speedSeriesProvider] 这种 `Notifier` + 显式 `tick()`，由页面在
/// `initState` 里启动、`dispose` 里停止，避免测试里 timer 泄漏
/// （AGENT_MISTAKES：widget 测试必须能 settle）。
library;

import 'dart:async';

import 'package:diting/data/dashboard_models.dart';
import 'package:diting/data/vpn/vpn_bridge.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/traffic_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 是否让仪表盘的速率曲线自动推进。
///
/// **测试必须把它设为 `false`**（`test/support/test_hooks.dart` 已经这么做）。
/// 原因：自动推进用的是永不停歇的周期回调，每一拍都触发重建 → 排一帧，
/// 于是 `WidgetTester.pumpAndSettle` 永远等不到「没有待处理帧」而超时。
///
/// 命名沿用 Flutter 自己的 `debug*` 约定（`debugDisableShadows` 等）：它是给
/// 测试与调试用的全局开关，不是产品配置，因此刻意不放进 Riverpod。
bool debugDisableDashboardLiveUpdates = false;

/// 速率数据源缺失的两种原因。
///
/// 分开而不是一个 `unsupported` 布尔：极速模式是**产品事实**（窄路由不经过
/// 引擎的流量计数器），没有原生通道是**宿主事实**（桌面 / 测试）。混成一句话
/// 会让桌面宿主显示「极速模式不统计」，而它根本不是极速模式。
enum SpeedSource {
  /// 有数据源。
  available,

  /// 极速模式：`ExpressVpnService` 不挂 `EngineDataPlane.attachTraffic`。
  expressMode,

  /// 宿主没有 `com.haoze.diting/vpn` 通道（桌面 / 组件画廊 / 纯 Dart 测试）。
  noNativeChannel,
}

/// 速率序列快照。
///
/// 带 [revision] 是因为 `ui/line_chart.dart` 靠「追加了几点」增量重绘，而不是
/// 逐帧比数组；不回传 revision 的话图表只会画第一帧然后静止。
class SpeedSeries {
  const SpeedSeries({
    required this.samples,
    required this.revision,
    this.source = SpeedSource.available,
  });

  final List<SpeedSample> samples;
  final int revision;

  /// 数据源状态。非 [SpeedSource.available] 时页面要说明缺什么，而不是画一条
  /// 贴在底部的 0 线冒充「没有流量」。
  final SpeedSource source;

  bool get unsupported => source != SpeedSource.available;

  SpeedSample get last =>
      samples.isEmpty ? const SpeedSample.zero() : samples.last;

  /// 曲线是否有过非零采样。全零且已有采样时页面显示「暂无流量」，
  /// 而不是一条贴在底部的直线。
  bool get hasTraffic => samples.any((sample) => !sample.isZero);

  List<double> upValues() => [for (final s in samples) s.up];

  List<double> downValues() => [for (final s in samples) s.down];
}

/// 当前速率序列。
final speedSeriesProvider = NotifierProvider<SpeedSeriesNotifier, SpeedSeries>(
  SpeedSeriesNotifier.new,
);

class SpeedSeriesNotifier extends Notifier<SpeedSeries> {
  /// 上一拍是否已在飞行中。通道调用是异步的，页面定时器不等它——不加这个闸，
  /// 一次慢响应会与后续几拍交错，采样点顺序就乱了。
  bool _inFlight = false;

  /// 轮询定时器与订阅计数。
  ///
  /// 首页与流量页都要这条曲线，两处各起一个 `Timer` 会以 2 Hz 采样、把 60 点
  /// 的窗口压成 30 秒。计数归零才真正停表，因此「首页被 `/traffic` 盖住」这种
  /// 情况不会让曲线断在半路。
  Timer? _timer;
  int _attachments = 0;

  @override
  SpeedSeries build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
      _attachments = 0;
    });
    return const SpeedSeries(samples: [], revision: 0);
  }

  /// 页面挂载时调用；与 [detachPolling] 成对。
  ///
  /// [debugDisableDashboardLiveUpdates] 为 true 时什么都不做（widget 测试用，
  /// 否则永不停歇的定时器会让 `pumpAndSettle` 超时）。
  void attachPolling() {
    _attachments++;
    if (debugDisableDashboardLiveUpdates || _timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    // 立刻取一拍，页面不必空等一秒才出现第一个点。
    unawaited(tick());
  }

  void detachPolling() {
    if (_attachments > 0) _attachments--;
    if (_attachments > 0) return;
    _timer?.cancel();
    _timer = null;
  }

  /// 取一拍真实速率（定时器调用；测试也可直接调）。
  ///
  /// 没有原生通道时 [VpnController.trafficRates] 返回 `unsupported`，这里把它
  /// 记进快照，页面据此显示缺失说明；仍然追加一个 0 采样，曲线不会因为数据源
  /// 缺失而保留上一次的形状。
  Future<void> tick() async {
    if (_inFlight) return;
    _inFlight = true;
    VpnTrafficRates rates;
    try {
      rates = await _controller().trafficRates();
    } catch (_) {
      rates = const VpnTrafficRates.idle();
    } finally {
      _inFlight = false;
    }
    if (!ref.mounted) return;
    final next = SpeedSample(up: rates.txBps, down: rates.rxBps);
    state = SpeedSeries(
      samples: [...state.samples, next].take(speedSampleCapacity).toList(),
      revision: state.revision + 1,
      source: rates.unsupported
          ? ref.read(workModeProvider) == AppWorkMode.express
                ? SpeedSource.expressMode
                : SpeedSource.noNativeChannel
          : SpeedSource.available,
    );
  }

  /// 清空曲线（模式切换 / 隧道重启时调用）。
  void clear() {
    state = const SpeedSeries(samples: [], revision: 0);
  }

  VpnController _controller() {
    final express = ref.read(workModeProvider) == AppWorkMode.express;
    return express
        ? ref.read(expressVpnControllerProvider)
        : ref.read(vpnControllerProvider);
  }
}

/// 累计流量（今日）。
///
/// 读 `app_traffic_daily` 的当日行，与 `/traffic` 页共用
/// [trafficSnapshotProvider]：两处各算一次会出现「首页 1.2 GB、流量页 1.1 GB」。
/// 快照未就绪时给 `null`，卡片显示破折号而不是 `0 B`。
final trafficTotalsProvider = FutureProvider<TrafficTotals?>((ref) async {
  final snapshot = await ref.watch(trafficSnapshotProvider.future);
  return TrafficTotals(
    up: snapshot.txBytes.toDouble(),
    down: snapshot.rxBytes.toDouble(),
  );
});

/// 内核状态：把两个真实状态机压成服务状态卡要的四档。
///
/// 服务器模式用 [ServerStatus]，其余模式用 [PowerState]。两套状态机不能合并
/// （服务器模式多了 `stopping`、少了 `error` 的同一语义），所以这里做一次映射，
/// 而不是让服务状态卡去 `when` 两个枚举。
final coreStateProvider = Provider<CoreState>((ref) {
  final mode = ref.watch(workModeProvider);
  if (mode == AppWorkMode.server) {
    return switch (ref.watch(serverStatusProvider)) {
      ServerStatus.running => CoreState.running,
      ServerStatus.starting => CoreState.starting,
      ServerStatus.stopping => CoreState.starting,
      ServerStatus.error => CoreState.failed,
      ServerStatus.stopped => CoreState.stopped,
    };
  }
  return switch (ref.watch(powerProvider)) {
    PowerState.running => CoreState.running,
    PowerState.starting || PowerState.stopping => CoreState.starting,
    PowerState.error => CoreState.failed,
    PowerState.stopped => CoreState.stopped,
  };
});

/// 仪表盘卡片编排（编辑模式增删/排序）。
final dashboardWidgetsProvider =
    NotifierProvider<DashboardWidgetsNotifier, List<DashboardWidget>>(
      DashboardWidgetsNotifier.new,
    );

class DashboardWidgetsNotifier extends Notifier<List<DashboardWidget>> {
  @override
  List<DashboardWidget> build() => defaultDashboardWidgets;

  /// 编辑模式「添加」：追加到末尾。
  void add(DashboardWidget widget) {
    if (state.contains(widget)) {
      return;
    }
    state = [...state, widget];
  }

  /// 编辑模式「移除」。
  void remove(DashboardWidget widget) {
    state = state.where((item) => item != widget).toList();
  }

  void toggle(DashboardWidget widget) {
    state.contains(widget) ? remove(widget) : add(widget);
  }

  /// 拖拽换位。
  ///
  /// [ReorderableListView.onReorderItem] 传进来的 `newIndex` 已经修正过「移除
  /// 一项后的下标位移」，这里直接插，不要再 +1/-1（旧 `onReorder` 才需要）。
  void move(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.length) {
      return;
    }
    if (newIndex < 0 || newIndex >= state.length || newIndex == oldIndex) {
      return;
    }
    final next = [...state];
    next.insert(newIndex, next.removeAt(oldIndex));
    state = next;
  }

  void reset() => state = defaultDashboardWidgets;

  /// 还没上屏的卡片（可添加项）。
  List<DashboardWidget> get available => [
    for (final widget in DashboardWidget.values)
      if (!state.contains(widget)) widget,
  ];
}

/// 编辑模式开关（不进 persist：退出页面即结束编辑）。
final dashboardEditingProvider =
    NotifierProvider<DashboardEditingNotifier, bool>(
      DashboardEditingNotifier.new,
    );

class DashboardEditingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() => state = true;

  void exit() => state = false;

  void toggle() => state = !state;
}

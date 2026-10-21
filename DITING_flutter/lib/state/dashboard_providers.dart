import 'package:diting/data/mock_dashboard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 仪表盘状态。
///
/// 上游全部接内核实时流；本轮是纯 UI，用「一次性生成 + 定时器推进」的假数据
/// 让图表和计数动起来，形状与真实一致。
///
/// 刻意**不**把定时器放进 provider 构造函数：那样每个 watch 都会起一个 timer。
/// 用 [speedSeriesProvider] 这种 `Notifier` + 显式 `tick()`，由页面在
/// `initState` 里启动、`dispose` 里停止，避免测试里 timer 泄漏
/// （AGENT_MISTAKES：widget 测试必须能 settle）。

/// 是否让仪表盘的速率曲线自动推进。
///
/// **测试必须把它设为 `false`**（`test/support/test_hooks.dart` 已经这么做）。
/// 原因：自动推进用的是永不停歇的周期回调，每一拍都触发重建 → 排一帧，
/// 于是 `WidgetTester.pumpAndSettle` 永远等不到「没有待处理帧」而超时。
///
/// 命名沿用 Flutter 自己的 `debug*` 约定（`debugDisableShadows` 等）：它是给
/// 测试与调试用的全局开关，不是产品配置，因此刻意不放进 Riverpod。
bool debugDisableDashboardLiveUpdates = false;

/// 速率序列快照。
///
/// 带 [revision] 是因为 `ui/line_chart.dart` 靠「追加了几点」增量重绘，而不是
/// 逐帧比数组；不回传 revision 的话图表只会画第一帧然后静止。
class SpeedSeries {
  const SpeedSeries({required this.samples, required this.revision});

  final List<SpeedSample> samples;
  final int revision;

  SpeedSample get last =>
      samples.isEmpty ? const SpeedSample.zero() : samples.last;

  List<double> upValues() => [for (final s in samples) s.up];

  List<double> downValues() => [for (final s in samples) s.down];
}

/// 当前速率序列。
final speedSeriesProvider = NotifierProvider<SpeedSeriesNotifier, SpeedSeries>(
  SpeedSeriesNotifier.new,
);

class SpeedSeriesNotifier extends Notifier<SpeedSeries> {
  int _cursor = 0;
  List<SpeedSample> _seed = const [];

  @override
  SpeedSeries build() {
    _seed = buildMockSpeedSamples();
    _cursor = _seed.length;
    return SpeedSeries(samples: _seed, revision: _seed.length);
  }

  /// 推进一格（由页面的定时器调用）。
  void tick() {
    // 循环复用预生成的波形：视觉上是连续曲线，又不引入随机数（截图可比对）。
    final next = _seed[_cursor % _seed.length];
    _cursor++;
    state = SpeedSeries(
      samples: [...state.samples.skip(1), next],
      revision: state.revision + 1,
    );
  }
}

/// 累计流量。
final trafficTotalsProvider = Provider<TrafficTotals>(
  (ref) => mockTrafficTotals,
);

/// 内核状态。
final coreStateProvider = NotifierProvider<CoreStateNotifier, CoreState>(
  CoreStateNotifier.new,
);

class CoreStateNotifier extends Notifier<CoreState> {
  @override
  CoreState build() => CoreState.running;

  /// 一键重启：启动中 → 运行中，各停留 [delay]，让按钮的忙碌态可见。
  Future<void> restart({
    Duration delay = const Duration(milliseconds: 900),
  }) async {
    if (state == CoreState.starting) {
      return;
    }
    state = CoreState.starting;
    await Future<void>.delayed(delay);
    state = CoreState.running;
  }

  void stop() => state = CoreState.stopped;
}

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

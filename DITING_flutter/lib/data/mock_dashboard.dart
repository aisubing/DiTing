/// 仪表盘演示数据与卡片注册表。
///
/// 上游这些值全部来自内核 `trafficsProvider` / `connectionsProvider` 等实时流；
/// 本轮只做 UI，因此用「固定形状 + 缓动」的假数据：形状与真实一致（环形缓冲、
/// 单调递增的总量、阶段性的连接数），但数值不来自网络。
///
/// 旧的 FlClash 专属模型（`CurrentProfile` / `OutboundMode` / `MemoryInfo` /
/// `IntranetInfo` / `ConnectionStats`）已随对应的仪表盘卡片一起删除：1.4.3 没有
/// 这些界面，留着只会让后继者再长出一页假数据。
library;

import 'dart:math' as math;

/// 环形缓冲：与上游 `FixedList` 同形（定长、追加、带 revision）。
///
/// 图表靠 [revision] 判断「该重绘了」，而不是逐帧比数组内容——上游
/// `ui/line_chart.dart` 就是这么做的，这里保持同一契约。
class RingBuffer<T> {
  RingBuffer(this.maxLength, {List<T>? initial})
    : _items = [...?initial].take(maxLength).toList();

  final int maxLength;
  final List<T> _items;

  int _revision = 0;

  int get revision => _revision;

  List<T> get list => List.unmodifiable(_items);

  T? get last => _items.isEmpty ? null : _items.last;

  void add(T value) {
    _items.add(value);
    if (_items.length > maxLength) {
      _items.removeAt(0);
    }
    _revision++;
  }

  void clear() {
    _items.clear();
    _revision++;
  }
}

/// 一个采样点的上下行速率（字节/秒）。
class SpeedSample {
  const SpeedSample({required this.up, required this.down});

  const SpeedSample.zero() : up = 0, down = 0;

  final double up;
  final double down;
}

/// 采样容量：60 点 ≈ 1 分钟（上游 `trafficsProvider` 也是 60）。
const speedSampleCapacity = 60;

/// 假速率的基准值。故意做成「上行小、下行大」的真实比例。
const _baseUp = 42 * 1024.0;
const _baseDown = 1.8 * 1024 * 1024.0;

/// 生成一段演示速率序列。
///
/// 用两条不同周期的正弦叠加 + 固定抖动，看起来像真实流量（有起伏但不随机乱跳，
/// 每次进页面形态一致，方便截图比对）。
List<SpeedSample> buildMockSpeedSamples({int count = speedSampleCapacity}) {
  return [
    for (var i = 0; i < count; i++)
      SpeedSample(
        up: _wave(i, period: 17, phase: 0.6, base: _baseUp, swing: 0.7),
        down: _wave(i, period: 23, phase: 0.0, base: _baseDown, swing: 0.55),
      ),
  ];
}

double _wave(
  int index, {
  required int period,
  required double phase,
  required double base,
  required double swing,
}) {
  final t = index / period;
  final slow = 0.5 + 0.5 * math.sin(2 * math.pi * (t + phase));
  final fast = 0.5 + 0.5 * math.sin(2 * math.pi * (t * 3.7));
  return base * (1 - swing + swing * (0.7 * slow + 0.3 * fast));
}

/// 累计流量（字节）。
class TrafficTotals {
  const TrafficTotals({required this.up, required this.down});

  const TrafficTotals.zero() : up = 0, down = 0;

  final double up;
  final double down;

  double get total => up + down;
}

/// 演示用的累计流量：约 1.2 GB 下行 / 86 MB 上行。
const mockTrafficTotals = TrafficTotals(
  up: 86 * 1024 * 1024.0,
  down: 1.2 * 1024 * 1024 * 1024.0,
);

/// 内核状态（上游 `core_status_button.dart`）。
///
/// 服务状态卡靠它判断「内核是否在跑」：未运行时探测按钮禁用、状态点变灰。
enum CoreState {
  running('运行中'),
  stopped('已停止'),
  starting('启动中'),
  failed('启动失败');

  const CoreState(this.label);

  final String label;
}

/// 仪表盘可编排卡片。
///
/// 1.4.3 的仪表盘没有「卡片编排」这个概念（它是一屏固定统计块），本仓保留
/// 编排能力，但**卡片集换成了旧版真实存在的统计块**：全部来自
/// `Android/.../ui/dashboard/ModernLogDashboardModeViews.kt`。
///
/// 顺序即「添加卡片」浮层里的展示顺序，与 `AllModeDashboard` 的块顺序一致。
enum DashboardWidget {
  serviceStatus('服务状态'),
  trafficMonitor('流量监控'),
  requestOverview('请求概览'),
  trafficStructure('今日流量结构'),
  recentRequests('最近请求'),
  cacheHotspots('缓存热点'),
  raceWinners('竞速胜出'),
  bootstrapDns('Bootstrap DNS'),
  ruleBlocks('规则拦截'),
  filteredHighlight('重点记录');

  const DashboardWidget(this.label);

  final String label;
}

/// 首页默认上屏的四块：服务状态 → 流量 → 请求概览 → 流量结构。
///
/// 与旧版 `AllModeDashboard` 的前四块一一对应，也是打开首页第一屏能看到的
/// 内容；其余六块通过编辑模式「添加卡片」加进来。
const defaultDashboardWidgets = <DashboardWidget>[
  DashboardWidget.serviceStatus,
  DashboardWidget.trafficMonitor,
  DashboardWidget.requestOverview,
  DashboardWidget.trafficStructure,
];

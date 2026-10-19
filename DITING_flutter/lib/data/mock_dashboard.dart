/// 仪表盘演示数据。
///
/// 上游这些值全部来自内核 `trafficsProvider` / `connectionsProvider` 等实时流；
/// 本轮只做 UI，因此用「固定形状 + 缓动」的假数据：形状与真实一致（环形缓冲、
/// 单调递增的总量、阶段性的连接数），但数值不来自网络。
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

/// 连接统计三计数（上游 `connection_stats.dart` 的 ConnectionStatsCard）。
class ConnectionStats {
  const ConnectionStats({
    required this.active,
    required this.closed,
    required this.upload,
    required this.download,
  });

  final int active;
  final int closed;
  final double upload;
  final double download;
}

const mockConnectionStats = ConnectionStats(
  active: 128,
  closed: 4218,
  upload: 3.4 * 1024 * 1024.0,
  download: 84.6 * 1024 * 1024.0,
);

/// 内网 IP 信息（上游 `intranet_ip.dart`）。
class IntranetInfo {
  const IntranetInfo({
    required this.address,
    required this.interfaceName,
    required this.allowLan,
    required this.port,
  });

  final String address;
  final String interfaceName;
  final bool allowLan;
  final int port;

  /// 允许局域网连接时把端口带在地址后。
  String get display => allowLan ? '$address:$port' : address;
}

const mockIntranet = IntranetInfo(
  address: '192.168.1.42',
  interfaceName: 'wlan0',
  allowLan: true,
  port: 7890,
);

/// 内存信息（上游 `memory_info.dart` + `MemoryDetailSheet`）。
class MemoryInfo {
  const MemoryInfo({
    required this.used,
    required this.total,
    required this.heapUsed,
    required this.heapTotal,
    required this.rss,
    required this.goroutines,
  });

  final int used;
  final int total;
  final int heapUsed;
  final int heapTotal;
  final int rss;
  final int goroutines;

  double get ratio => total == 0 ? 0 : used / total;

  double get percent => ratio * 100;

  /// 剩余量，详情浮层里用。
  int get free => total - used;
}

const mockMemory = MemoryInfo(
  used: 186 * 1024 * 1024,
  total: 512 * 1024 * 1024,
  heapUsed: 42 * 1024 * 1024,
  heapTotal: 128 * 1024 * 1024,
  rss: 214 * 1024 * 1024,
  goroutines: 86,
);

/// 内存历史采样（详情浮层里的小趋势图）。
List<double> buildMockMemoryHistory({int count = 40}) => [
  for (var i = 0; i < count; i++)
    mockMemory.used * (0.78 + 0.22 * (i % 9) / 9),
];

/// 出站模式（上游 `enum/enum.dart` 的 `Mode`）。
enum OutboundMode {
  rule('规则'),
  global('全局'),
  direct('直连');

  const OutboundMode(this.label);

  final String label;
}

/// 当前配置档案（上游 `profiles.dart` 的 ProfilesCard）。
class CurrentProfile {
  const CurrentProfile({
    required this.name,
    required this.type,
    required this.updatedAt,
    required this.upload,
    required this.download,
    required this.total,
    required this.expireAt,
    required this.progress,
  });

  final String name;
  final String type;
  final String updatedAt;
  final double upload;
  final double download;
  final double total;
  final String expireAt;

  /// 已完成比例；`null` 表示无上限（不画进度条）。
  final double? progress;
}

const mockCurrentProfile = CurrentProfile(
  name: '谛听 · 订阅',
  type: '远程',
  updatedAt: '3 分钟前',
  upload: 1.4 * 1024 * 1024 * 1024.0,
  download: 42.7 * 1024 * 1024 * 1024.0,
  total: 100 * 1024 * 1024 * 1024.0,
  expireAt: '2027-03-14',
  progress: 0.44,
);

/// 内核状态（上游 `core_status_button.dart`）。
enum CoreState {
  running('运行中'),
  stopped('已停止'),
  starting('启动中'),
  failed('启动失败');

  const CoreState(this.label);

  final String label;
}

/// 仪表盘可编排卡片（上游 `enum/enum.dart` 的 `DashboardWidget`，11 项）。
///
/// 顺序即上游 `dashboard/widget_registry.dart` 的注册顺序。编辑模式增删卡片
/// 直接用这个枚举，避免另建一套 id。
enum DashboardWidget {
  currentOutbound('当前状态'),
  networkSpeed('网络速率'),
  outboundMode('出站模式'),
  vpn('网络接管'),
  serviceStatus('服务状态'),
  profiles('配置档案'),
  proxyGroups('代理组'),
  connectionStats('连接统计'),
  intranetIp('内网 IP'),
  memory('内存占用');

  const DashboardWidget(this.label);

  final String label;

  /// 该卡片是否可以在当前平台上出现。桌面专属项在 Android 上直接不可选。
  static const mobileAvailable = {
    DashboardWidget.currentOutbound,
    DashboardWidget.networkSpeed,
    DashboardWidget.outboundMode,
    DashboardWidget.vpn,
    DashboardWidget.serviceStatus,
    DashboardWidget.profiles,
    DashboardWidget.proxyGroups,
    DashboardWidget.connectionStats,
    DashboardWidget.intranetIp,
    DashboardWidget.memory,
  };
}

/// [DashboardWidget] 的消费侧派生数据：某张卡片是否应该出现在仪表盘上。
///
/// 上游把「显示哪些卡片」存在 `dashboardWidgets` 配置里（用户可编排）；这里
/// 只在内存里维持一份，供编辑模式演示。
const defaultDashboardWidgets = <DashboardWidget>[
  DashboardWidget.serviceStatus,
  DashboardWidget.networkSpeed,
  DashboardWidget.connectionStats,
  DashboardWidget.profiles,
  DashboardWidget.proxyGroups,
  DashboardWidget.outboundMode,
  DashboardWidget.intranetIp,
  DashboardWidget.memory,
];

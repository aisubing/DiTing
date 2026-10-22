/// 仪表盘模型与卡片注册表。
///
/// 上游这些值全部来自内核实时流（`trafficsProvider` / `connectionsProvider`）；
/// 本仓的对应关系是：
/// - **速率曲线**由 `state/speed_providers.dart` 每秒向原生侧取一次真实速率
///   （`TrafficRateMonitor` 的 `txBps` / `rxBps`），本文件只保留采样点模型；
/// - **累计流量**读旧库 `app_traffic_daily`（见 `state/traffic_providers.dart`）；
/// - **内核状态**来自 `powerProvider` / `serverStatusProvider` 的真实状态机
///   （映射见 `state/core_status_providers.dart`）。
///
/// 旧的 FlClash 专属模型（`CurrentProfile` / `OutboundMode` / `ConnectionStats`）
/// 已随对应的界面一起删除：1.4.3 没有这些界面，留着只会让后继者再长出一页假
/// 数据。内存与内网 IP 两块重新回来了，但模型在各自的数据层
/// （`data/native/process_memory.dart`、`diagnostics_bridge.dart`），不在这里——
/// 它们各有自己的采样通道，塞进仪表盘模型只会让两处口径互相牵制。
library;

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

  bool get isZero => up == 0 && down == 0;
}

/// 采样容量：60 点 ≈ 1 分钟（上游 `trafficsProvider` 也是 60）。
const speedSampleCapacity = 60;

/// 累计流量（字节）。
///
/// 只由 `state/traffic_providers.dart` 的 `trafficTotalsProvider` 从旧库
/// `app_traffic_daily` 的当日行求和得到；`up` 是上行、`down` 是下行，
/// 与表里的 `tx_bytes` / `rx_bytes` 一一对应。
class TrafficTotals {
  const TrafficTotals({required this.up, required this.down});

  const TrafficTotals.zero() : up = 0, down = 0;

  final double up;
  final double down;

  double get total => up + down;
}

/// 内核状态（上游 `core_status_button.dart`）。
///
/// 服务状态卡靠它判断「内核是否在跑」：未运行时探测按钮禁用、状态点变灰。
/// 取值由 `state/core_status_providers.dart` 从真实的电源 / 服务器状态映射而来，
/// 不再是一个固定 `running` 的内存变量。
enum CoreState {
  running('运行中'),
  stopped('已停止'),
  starting('启动中'),
  failed('启动失败');

  const CoreState(this.label);

  final String label;

  bool get isRunning => this == CoreState.running;
}

/// 仪表盘可编排卡片。
///
/// 前半段（[status] / [networkSpeed] / [siteLatency] / [memoryInfo] /
/// [intranetIp]）对齐 FlClash 0.9.1 首页的仪表盘：状态、网络速度、服务状态、
/// 内存信息、内网 IP 五块，形状与信息层级照抄 `views/dashboard/widgets/`，
/// 数据换成本仓的真实来源。其中「服务状态」按用户要求改成了**国内站点测速**
/// （百度 / 抖音 / 哔哩哔哩 / 网易云音乐），因为那张卡真正要回答的是「现在上网
/// 顺不顺」，而不是「解析服务商应答多快」。后半段是 1.4.3 的统计块
/// （`DITING-Legacy/.../ui/dashboard/ModernLogDashboardModeViews.kt`）。
///
/// 顺序即「添加卡片」浮层里的展示顺序，与首页默认顺序一致。
enum DashboardWidget {
  status('状态'),
  networkSpeed('网络速度'),
  siteLatency('网络测速'),
  memoryInfo('内存信息'),
  intranetIp('内网 IP'),
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

/// 首页默认上屏的七块。
///
/// 前五块是 FlClash 式仪表盘（状态 / 网络速度 / 网络测速 / 内存 / 内网 IP），
/// 后两块是日志统计。`trafficMonitor` 刻意**不在**默认集里：它显示的「今日
/// 流量 + 实时速率」与「网络速度」卡是同一份数据，两张一起上屏会让人以为
/// 有两个不同的计数器。它仍然可以在编辑模式里加回来。
const defaultDashboardWidgets = <DashboardWidget>[
  DashboardWidget.status,
  DashboardWidget.networkSpeed,
  DashboardWidget.siteLatency,
  DashboardWidget.memoryInfo,
  DashboardWidget.intranetIp,
  DashboardWidget.requestOverview,
  DashboardWidget.trafficStructure,
];

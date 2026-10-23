library;

/// Ring buffer shaped like upstream `FixedList`: fixed length, append-only, redrawn via [revision].
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

class SpeedSample {
  const SpeedSample({required this.up, required this.down});

  const SpeedSample.zero() : up = 0, down = 0;

  final double up;
  final double down;

  bool get isZero => up == 0 && down == 0;
}

const speedSampleCapacity = 60;

class TrafficTotals {
  const TrafficTotals({required this.up, required this.down});

  const TrafficTotals.zero() : up = 0, down = 0;

  final double up;
  final double down;

  double get total => up + down;
}

/// Core state; the service card disables probes and greys the dot when stopped.
enum CoreState {
  running('运行中'),
  stopped('已停止'),
  starting('启动中'),
  failed('启动失败');

  const CoreState(this.label);

  final String label;

  bool get isRunning => this == CoreState.running;
}

/// Reorderable dashboard cards, in the order the add-card sheet shows them.
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

/// The seven default cards. `trafficMonitor` is left out because it shows the same data as the
/// speed card, but it can still be added in edit mode.
const defaultDashboardWidgets = <DashboardWidget>[
  DashboardWidget.status,
  DashboardWidget.networkSpeed,
  DashboardWidget.siteLatency,
  DashboardWidget.memoryInfo,
  DashboardWidget.intranetIp,
  DashboardWidget.requestOverview,
  DashboardWidget.trafficStructure,
];

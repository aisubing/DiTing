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

/// Reorderable home dashboard cards, in the order the add-card sheet shows them.
///
/// Only cards that are *not* on the log dashboard live here: the log dashboard already owns
/// traffic, request overview, traffic structure, recent requests, cache hotspots, race winners,
/// bootstrap DNS, rule blocks and the filtered highlight. Repeating them on home made the two
/// dashboards look like one page, so home keeps the local device view instead.
enum DashboardWidget {
  /// Picked service provider; `解析服务商` in single mode, `竞速服务商` in the other modes.
  provider('解析服务商'),

  /// Resolution mode plus the endpoints currently in use.
  resolution('解析模式'),
  status('状态'),
  networkSpeed('网络速度'),
  siteLatency('网络测速'),
  memoryInfo('内存信息'),
  intranetIp('内网 IP');

  const DashboardWidget(this.label);

  final String label;
}

/// One card for every widget home owns, in the order a fresh install shows them.
const defaultDashboardWidgets = <DashboardWidget>[
  DashboardWidget.provider,
  DashboardWidget.resolution,
  DashboardWidget.status,
  DashboardWidget.networkSpeed,
  DashboardWidget.siteLatency,
  DashboardWidget.memoryInfo,
  DashboardWidget.intranetIp,
];

/// 流量统计状态：读旧库 `app_traffic_daily`。
///
/// ## 数据来源
/// 行由原生侧 `TrafficIngest` 批量写入（`AppTrafficDao.upsertDelta` 的等价
/// SQL），Dart 只读。SQL 与 `AppTrafficDao` 逐字一致，见
/// `lib/data/db/app_traffic_repository.dart`。
///
/// 这张表只存在于 `diting_database`（普通 / 服务器模式）；极速模式的
/// `diting_express` 明确排除了 `AppTrafficDailyEntity`，所以这里固定读主库
/// （`mainLogDatabaseProvider`），不跟 `activeLogDatabaseProvider` 走。
///
/// ## 三档时间范围的口径
/// 页面保留上游 1.4.3 的 `TrafficTimeRange`（会话 / 今日 / 本周 / 本月 /
/// 全部历史）。本仓能拿到的证据只有「按天落库的行」，所以：
/// - **今日** = `byDate(今天)`，每行一天，占比即当日份额；
/// - **本周** / **本月** / **全部** = `dateRange(a, b)` / `allHistory()`，
///   按包名把多天相加，`date` 取组内最早一天（与旧版 `min(date)` 一致）。
/// - **实时**（本次会话）**没有落库来源**：引擎的会话计数要经
///   `getStats()` 拿，而那是全局累计、不按应用拆分。页面因此不提供「实时」
///   档位，曲线区如实标注为「会话示意」。
library;

import 'package:diting/data/db/app_traffic_repository.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/observability_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 只读仓储。库文件不存在（全新安装 / 未升级过 1.4.3）时为 `null`，
/// 上层据此渲染空态而不是报错。
final appTrafficRepositoryProvider = FutureProvider<AppTrafficRepository?>((
  ref,
) async {
  final db = await ref.watch(mainLogDatabaseProvider.future);
  return db == null ? null : AppTrafficRepository(db);
});

/// 页面可选的时间窗口。取值对应 1.4.3 `TrafficTimeRange` 中**有真实后端**的
/// 那几档；`SESSION` 与 `REALTIME_SPEED` 被刻意排除，原因见文件头。
enum TrafficWindow {
  today('今日'),
  week('本周'),
  month('本月'),
  all('全部');

  const TrafficWindow(this.label);

  final String label;
}

/// 当前选中的窗口。
class TrafficWindowNotifier extends Notifier<TrafficWindow> {
  @override
  TrafficWindow build() => TrafficWindow.today;

  void select(TrafficWindow window) {
    if (state == window) return;
    state = window;
  }
}

final trafficWindowProvider =
    NotifierProvider<TrafficWindowNotifier, TrafficWindow>(
      TrafficWindowNotifier.new,
    );

/// 查询结果：按包名聚合后的行 + 该窗口的上下行合计。
///
/// 合计在这里算而不是让页面 fold：页面同时要显示三格数字与占比条，
/// 两处各 fold 一次就会有机会算成不同的窗口。
class TrafficSnapshot {
  const TrafficSnapshot({
    required this.rows,
    required this.startDate,
    required this.endDate,
  });

  const TrafficSnapshot.empty()
    : rows = const [],
      startDate = '',
      endDate = '';

  /// 按总字节降序，与 SQL 的 `ORDER BY` 同序。
  final List<AppTrafficDaily> rows;

  /// 窗口的首尾日期（`yyyy-MM-dd`），用于页脚说明统计口径。
  /// 今日窗口两项相同。
  final String startDate;
  final String endDate;

  int get txBytes => rows.fold(0, (sum, row) => sum + row.txBytes);

  int get rxBytes => rows.fold(0, (sum, row) => sum + row.rxBytes);

  int get totalBytes => txBytes + rxBytes;

  bool get isEmpty => rows.isEmpty;
}

/// `dateRange` 的日期字符串：`yyyy-MM-dd`，本地时区。
String _dateKey(DateTime time) => AppTrafficRepository.dateKey(time);

Future<TrafficSnapshot> _loadSnapshot(Ref ref, TrafficWindow window) async {
  final repository = await ref.watch(appTrafficRepositoryProvider.future);
  if (repository == null) return const TrafficSnapshot.empty();

  // `DateTime.weekday` 是 1=周一..7=周日；「本周」在中文语境里从周一起算，
  // 用 `weekday - 1` 回退到周一，而不是 1.4.3 `TrafficTimeRange` 的注释里
  // 含糊的「最近 7 天」——两者跨周时数字不同，这里选日历周。
  final now = DateTime.now();
  switch (window) {
    case TrafficWindow.today:
      final key = _dateKey(now);
      return TrafficSnapshot(
        rows: await repository.byDate(key),
        startDate: key,
        endDate: key,
      );
    case TrafficWindow.week:
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final start = _dateKey(monday);
      final end = _dateKey(now);
      return TrafficSnapshot(
        rows: await repository.dateRange(start, end),
        startDate: start,
        endDate: end,
      );
    case TrafficWindow.month:
      final start = _dateKey(DateTime(now.year, now.month));
      final end = _dateKey(now);
      return TrafficSnapshot(
        rows: await repository.dateRange(start, end),
        startDate: start,
        endDate: end,
      );
    case TrafficWindow.all:
      return TrafficSnapshot(
        rows: await repository.allHistory(),
        startDate: '',
        endDate: '',
      );
  }
}

/// 排名字段（1.4.3 `TrafficSortMode` 中能在纯日表上算出来的三档）。
///
/// `REALTIME_SPEED` 没有数据来源，不列——列出来只会点一下就空。
enum TrafficSort {
  total('按总流量'),
  download('按下载流量'),
  upload('按上传流量');

  const TrafficSort(this.label);

  final String label;
}

class TrafficSortNotifier extends Notifier<TrafficSort> {
  @override
  TrafficSort build() => TrafficSort.total;

  void select(TrafficSort sort) {
    if (state == sort) return;
    state = sort;
  }
}

final trafficSortProvider = NotifierProvider<TrafficSortNotifier, TrafficSort>(
  TrafficSortNotifier.new,
);

/// 搜索词（匹配应用名与包名）。
class TrafficSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    if (state == query) return;
    state = query;
  }
}

final trafficSearchProvider =
    NotifierProvider<TrafficSearchNotifier, String>(
      TrafficSearchNotifier.new,
    );

/// 当前窗口的真实数据。
final trafficSnapshotProvider = FutureProvider<TrafficSnapshot>((ref) async {
  ref.watch(dnsLogRevisionProvider);
  final window = ref.watch(trafficWindowProvider);
  return _loadSnapshot(ref, window);
});

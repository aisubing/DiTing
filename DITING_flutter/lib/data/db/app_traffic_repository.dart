/// Read access to the legacy `app_traffic_daily` table.
///
/// Rows are written by the native side (`TrafficIngest` → `AppTrafficDao.upsertDelta`
/// equivalent), so this repository is read-only.
///
/// Both aggregate queries are copied verbatim from
/// `Android/app/src/main/java/com/haoze/diting/data/dao/AppTrafficDao.kt`
/// (`queryDateRange` / `queryAllHistory`), including the `min(date)` / `max(app_name)`
/// projections: Room maps those into an `AppTrafficDailyEntity`, so the DTO keeps
/// the same shape instead of inventing a second one.
library;

import 'package:sqflite/sqflite.dart';

/// One row of `app_traffic_daily` (or one aggregated package across dates).
class AppTrafficDaily {
  const AppTrafficDaily({
    required this.date,
    required this.packageName,
    required this.appName,
    required this.txBytes,
    required this.rxBytes,
    required this.updatedAt,
  });

  /// `yyyy-MM-dd`, local time zone. For the range/history queries this is the
  /// **earliest** date in the group, exactly like the legacy `min(date)`.
  final String date;
  final String packageName;
  final String appName;
  final int txBytes;
  final int rxBytes;
  final int updatedAt;

  int get totalBytes => txBytes + rxBytes;

  /// Share of [total], as 0..1. Guards the empty list shown before the first
  /// traffic tick lands, where `total == 0` would otherwise divide by zero.
  double shareOf(int total) => total <= 0 ? 0 : totalBytes / total;
}

class AppTrafficRepository {
  AppTrafficRepository(this._db);

  final Database _db;

  /// 1.4.3 `queryByDate`.
  Future<List<AppTrafficDaily>> byDate(String date) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM app_traffic_daily WHERE date = ? '
      'ORDER BY (tx_bytes + rx_bytes) DESC',
      [date],
    );
    return [for (final row in rows) _fromRow(row)];
  }

  /// 1.4.3 `queryDateRange`（含首尾两天，字符串比较即日期比较）。
  Future<List<AppTrafficDaily>> dateRange(
    String startDate,
    String endDate,
  ) async {
    final rows = await _db.rawQuery(
      'SELECT min(date) as date, package_name, max(app_name) as app_name, '
      'sum(tx_bytes) as tx_bytes, sum(rx_bytes) as rx_bytes, '
      'max(updated_at) as updated_at '
      'FROM app_traffic_daily '
      'WHERE date >= ? AND date <= ? '
      'GROUP BY package_name '
      'ORDER BY (sum(tx_bytes) + sum(rx_bytes)) DESC',
      [startDate, endDate],
    );
    return [for (final row in rows) _fromRow(row)];
  }

  /// 1.4.3 `queryAllHistory`.
  Future<List<AppTrafficDaily>> allHistory() async {
    final rows = await _db.rawQuery(
      'SELECT min(date) as date, package_name, max(app_name) as app_name, '
      'sum(tx_bytes) as tx_bytes, sum(rx_bytes) as rx_bytes, '
      'max(updated_at) as updated_at '
      'FROM app_traffic_daily '
      'GROUP BY package_name '
      'ORDER BY (sum(tx_bytes) + sum(rx_bytes)) DESC',
    );
    return [for (final row in rows) _fromRow(row)];
  }

  /// Today's row per package; the page shows "今日" by default, which is what
  /// 1.4.3's `TrafficTimeRange.TODAY` selected.
  Future<List<AppTrafficDaily>> today() => byDate(todayKey());

  /// 1.4.3 `AppTrafficDao.clearAll()`：`DELETE FROM app_traffic_daily`。
  ///
  /// 这是本仓储唯一的写操作，对应流量页的「清除历史」（旧版
  /// `AppTrafficStatsViewModel.clearHistory` → `TrafficStatsManager.clearAllTrafficStats`
  /// + `LogMaintenance.clearAllTrafficStats`）。调用方负责先弹确认框——旧版
  /// 的确认文案是「此操作将清空所有已持久化的应用历史流量统计，清除后无法恢复。」
  ///
  /// 返回删掉的行数，供 UI 报告「已清除 N 条记录」。
  Future<int> clearAll() => _db.delete('app_traffic_daily');

  /// `yyyy-MM-dd` in the local time zone.
  ///
  /// Local, not UTC: `TrafficIngest` derives the row key from
  /// `SimpleDateFormat("yyyy-MM-dd")` in the device zone, so a UTC key would
  /// point at the wrong row for eight hours a day in UTC+8.
  static String dateKey(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)}';
  }

  static String todayKey() => dateKey(DateTime.now());

  static AppTrafficDaily _fromRow(Map<String, Object?> row) => AppTrafficDaily(
    date: row['date'] as String? ?? '',
    packageName: row['package_name'] as String? ?? '',
    appName: row['app_name'] as String? ?? '',
    txBytes: (row['tx_bytes'] as num?)?.toInt() ?? 0,
    rxBytes: (row['rx_bytes'] as num?)?.toInt() ?? 0,
    updatedAt: (row['updated_at'] as num?)?.toInt() ?? 0,
  );
}

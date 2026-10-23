/// Read access to the legacy `app_traffic_daily` table.
///
/// Rows are written natively, so this repository only reads. The aggregate
/// projections (`min(date)`, `max(app_name)`) mirror the legacy DAO.
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

    /// `yyyy-MM-dd` in the local zone. For the range/history queries this is the
    /// earliest date in the group.
  final String date;
  final String packageName;
  final String appName;
  final int txBytes;
  final int rxBytes;
  final int updatedAt;

  int get totalBytes => txBytes + rxBytes;

    /// Share of [total], as 0..1. Guards against a zero total while the list is
    /// still empty.
  double shareOf(int total) => total <= 0 ? 0 : totalBytes / total;
}

class AppTrafficRepository {
  AppTrafficRepository(this._db);

  final Database _db;

  Future<List<AppTrafficDaily>> byDate(String date) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM app_traffic_daily WHERE date = ? '
      'ORDER BY (tx_bytes + rx_bytes) DESC',
      [date],
    );
    return [for (final row in rows) _fromRow(row)];
  }

    /// Inclusive on both ends; comparing the `yyyy-MM-dd` strings compares dates.
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

    /// Today's row per package.
  Future<List<AppTrafficDaily>> today() => byDate(todayKey());

    /// The repository's only write: deletes every row and returns the count. The
    /// caller asks for confirmation first.
  Future<int> clearAll() => _db.delete('app_traffic_daily');

    /// `yyyy-MM-dd` in the local zone, matching the key the native ingest writes;
    /// a UTC key would point at the wrong row for part of each day.
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

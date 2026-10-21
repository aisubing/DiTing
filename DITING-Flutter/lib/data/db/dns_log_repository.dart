/// Read/delete access to the legacy `dns_log` table.
///
/// Rows are written by the native services through [DnsLogWriter], so this
/// repository is deliberately read-only apart from "clear all".
library;

import 'package:sqflite/sqflite.dart';

class DnsLogRecord {
  const DnsLogRecord({
    required this.timestamp,
    required this.domain,
    required this.queryType,
    required this.result,
    required this.cached,
    this.message,
    this.packageName,
  });

  final int timestamp;
  final String domain;
  final int queryType;
  final String result;
  final bool cached;
  final String? message;
  final String? packageName;
}

class DnsLogRepository {
  DnsLogRepository(this._db);

  final Database _db;

  Future<List<DnsLogRecord>> recent({int limit = 200}) async {
    final rows = await _db.query(
      'dns_log',
      orderBy: 'timestamp DESC, id DESC',
      limit: limit,
    );
    return [for (final row in rows) _fromRow(row)];
  }

  /// Today's counters, computed the same way as the legacy
  /// `DnsLogRepository.dailyStats`: PASSED/REWRITTEN count as passed, cached
  /// rows are counted separately, BLOCKED and ERROR keep their own buckets.
  ///
  /// `message` carries `elapsed=NNms` (see [DnsLogWriter]), so the average
  /// latency of the same day comes from the same scan instead of a second
  /// query — the header must never mix "today's rows" with "last 200 rows'.
  Future<DnsLogDailyStats> dailyStats({DateTime? since}) async {
    final start = (since ?? _startOfToday()).millisecondsSinceEpoch;
    final rows = await _db.query(
      'dns_log',
      columns: ['result', 'cached', 'message'],
      where: 'timestamp >= ?',
      whereArgs: [start],
    );
    var passed = 0;
    var blocked = 0;
    var error = 0;
    var cached = 0;
    var latencyTotal = 0;
    var latencyCount = 0;
    for (final row in rows) {
      final result = row['result'] as String? ?? 'PASSED';
      final isCached = (row['cached'] as num?)?.toInt() == 1;
      switch (result) {
        case 'BLOCKED':
          blocked++;
        case 'ERROR':
          error++;
        default:
          passed++;
          if (isCached) cached++;
      }
      final elapsed = elapsedMsOf(row['message'] as String?);
      if (elapsed != null) {
        latencyTotal += elapsed;
        latencyCount++;
      }
    }
    return DnsLogDailyStats(
      total: rows.length,
      passed: passed,
      blocked: blocked,
      error: error,
      cached: cached,
      averageLatencyMs: latencyCount == 0 ? 0 : latencyTotal ~/ latencyCount,
      latencySamples: latencyCount,
    );
  }

  /// `elapsed=123ms` inside the persisted `message` column, or null when the
  /// row carries no timing. `DnsLogWriter` only writes the token when the
  /// engine reports `r > 0`, so sub-millisecond blocked queries drop out
  /// instead of being recorded as `0ms`.
  static int? elapsedMsOf(String? message) {
    if (message == null || message.isEmpty) return null;
    final match = _elapsedPattern.firstMatch(message);
    final value = int.tryParse(match?.group(1) ?? '');
    return value == null || value < 0 ? null : value;
  }

  static final _elapsedPattern = RegExp(r'elapsed=(\d+)ms');

  Future<int> clear() => _db.delete('dns_log');

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DnsLogRecord _fromRow(Map<String, Object?> row) => DnsLogRecord(
    timestamp: (row['timestamp'] as num?)?.toInt() ?? 0,
    domain: row['queryName'] as String? ?? '',
    queryType: (row['queryType'] as num?)?.toInt() ?? 1,
    result: row['result'] as String? ?? 'PASSED',
    cached: (row['cached'] as num?)?.toInt() == 1,
    message: row['message'] as String?,
    packageName: row['packageName'] as String?,
  );
}

/// Today's aggregates shown on the dashboard header.
class DnsLogDailyStats {
  const DnsLogDailyStats({
    required this.total,
    required this.passed,
    required this.blocked,
    required this.error,
    required this.cached,
    this.averageLatencyMs = 0,
    this.latencySamples = 0,
  });

  const DnsLogDailyStats.empty()
    : total = 0,
      passed = 0,
      blocked = 0,
      error = 0,
      cached = 0,
      averageLatencyMs = 0,
      latencySamples = 0;

  final int total;
  final int passed;
  final int blocked;
  final int error;
  final int cached;

  /// Mean `elapsed=` over today's timed rows; blocked-by-rule rows have no
  /// timing, so they must not drag the average towards zero.
  final int averageLatencyMs;

  /// How many rows contributed to [averageLatencyMs]. Zero means "no data",
  /// which the header renders as a dash instead of `0ms`.
  final int latencySamples;

  /// Denominator mirrors the Go engine's `hitRatio` = hits/(hits+misses):
  /// the resolver is consulted for PASSED rows (hit or miss) and for ERROR
  /// rows (the cache lookup happens before the upstream call fails), while
  /// rule-blocked rows never touch the cache. Using [passed] alone would
  /// drop every failed upstream query from the denominator and read high.
  ///
  /// Known approximation: a stale-while-revalidate reply is logged with
  /// `cached=1` but the engine counts it in `staleHits`, not `totalHits`.
  double get cacheHitRate {
    final lookups = passed + error;
    return lookups == 0 ? 0 : cached / lookups;
  }
}

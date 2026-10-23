/// Read/delete access to the legacy `dns_log` table.
///
/// Rows are written natively through [DnsLogWriter], so this repository only
/// reads apart from clearing the table.
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

    /// Today's counters: PASSED and REWRITTEN count as passed, cached rows are
    /// counted separately, BLOCKED and ERROR keep their own buckets.
    ///
    /// Latency comes from the same scan, because `message` carries
    /// `elapsed=NNms`; the header must never mix today's rows with the recent
    /// list.
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

    /// Reads `elapsed=123ms` out of the persisted `message`, or null when there
    /// is no timing. The writer only emits the token for positive durations, so
    /// sub-millisecond queries drop out instead of counting as `0ms`.
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

    /// Mean `elapsed=` over timed rows only; rule-blocked rows have no timing
    /// and must not drag the average down.
  final int averageLatencyMs;

    /// Number of rows behind [averageLatencyMs]. Zero means no data, which the
    /// header renders as a dash rather than `0ms`.
  final int latencySamples;

    /// Mirrors the engine's `hitRatio` = hits/(hits+misses). The denominator is
    /// [passed] plus error rows, since the cache lookup happens before the
    /// upstream call fails while rule-blocked rows never reach the cache;
    /// using [passed] alone would read high.
    ///
    /// Known approximation: a stale-while-revalidate reply is logged with
    /// `cached=1` but the engine counts it as a stale hit, not a normal one.
  double get cacheHitRate {
    final lookups = passed + error;
    return lookups == 0 ? 0 : cached / lookups;
  }
}

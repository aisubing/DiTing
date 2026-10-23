/// Read/delete access to the legacy `dns_log` table; rows are written natively through
/// [DnsLogWriter].
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

  /// PASSED and REWRITTEN count as passed; latency comes from the same scan as the list.
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

  /// Reads `elapsed=123ms`; the writer only emits it for positive durations.
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

  /// Mean `elapsed=` over timed rows only; rule-blocked rows carry no timing.
  final int averageLatencyMs;

  final int latencySamples;

  /// Mirrors engine `hitRatio`: errors join the denominator (cache lookup precedes upstream
  /// failure) and a stale-while-revalidate reply counts as a stale hit.
  double get cacheHitRate {
    final lookups = passed + error;
    return lookups == 0 ? 0 : cached / lookups;
  }
}

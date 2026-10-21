/// Read/delete access to the legacy `dns_race_log` table.
///
/// Rows are written by the native services through [RaceLogWriter]. Provider
/// names are resolved in Dart from the provider catalog, because the native
/// side only knows the ids that came in through the start intent.
library;

import 'package:sqflite/sqflite.dart';

class RaceLogRecord {
  const RaceLogRecord({
    required this.timestamp,
    required this.queryName,
    required this.strategy,
    required this.providerCount,
    required this.success,
    required this.elapsedMs,
    this.winnerProviderId,
    this.winnerElapsedMs,
    this.message,
  });

  final int timestamp;
  final String queryName;
  final String strategy;
  final int providerCount;
  final bool success;
  final int elapsedMs;
  final String? winnerProviderId;
  final int? winnerElapsedMs;
  final String? message;
}

/// Per-provider aggregate over the retained race rows.
class RaceRankingEntry {
  const RaceRankingEntry({
    required this.providerId,
    required this.wins,
    required this.averageLatencyMs,
  });

  final String providerId;
  final int wins;
  final int averageLatencyMs;
}

/// Whole-table summary, independent of which provider won.
class RaceLogSummary {
  const RaceLogSummary({
    required this.requests,
    required this.successes,
    required this.failures,
    required this.averageLatencyMs,
  });

  const RaceLogSummary.empty()
    : requests = 0,
      successes = 0,
      failures = 0,
      averageLatencyMs = 0;

  final int requests;
  final int successes;
  final int failures;
  final int averageLatencyMs;
}

class RaceLogRepository {
  RaceLogRepository(this._db);

  final Database _db;

  Future<List<RaceLogRecord>> recent({int limit = 100}) async {
    final rows = await _db.query(
      'dns_race_log',
      orderBy: 'timestamp DESC, id DESC',
      limit: limit,
    );
    return [for (final row in rows) _fromRow(row)];
  }

  /// Wins are rows where this provider produced the winning response. Only
  /// successful rows have a winner, so failures belong to [summary] instead of
  /// being pinned on the provider that happened to sort first.
  Future<List<RaceRankingEntry>> ranking({int limit = 20}) async {
    final rows = await _db.rawQuery(
      'SELECT winnerProviderId AS providerId, '
      'COUNT(*) AS wins, '
      'AVG(CASE WHEN winnerElapsedMs IS NOT NULL THEN winnerElapsedMs END) '
      'AS avgElapsed '
      'FROM dns_race_log '
      'WHERE success = 1 AND winnerProviderId IS NOT NULL '
      'GROUP BY winnerProviderId '
      'ORDER BY wins DESC, avgElapsed ASC '
      'LIMIT ?',
      [limit],
    );
    return [
      for (final row in rows)
        if ((row['providerId'] as String?)?.isNotEmpty == true)
          RaceRankingEntry(
            providerId: row['providerId']! as String,
            wins: (row['wins'] as num?)?.toInt() ?? 0,
            averageLatencyMs: ((row['avgElapsed'] as num?) ?? 0).round(),
          ),
    ];
  }

  Future<RaceLogSummary> summary() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS requests, '
      'SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) AS successes, '
      'SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) AS failures, '
      'AVG(elapsedMs) AS avgElapsed '
      'FROM dns_race_log',
    );
    if (rows.isEmpty) return const RaceLogSummary.empty();
    final row = rows.first;
    return RaceLogSummary(
      requests: (row['requests'] as num?)?.toInt() ?? 0,
      successes: (row['successes'] as num?)?.toInt() ?? 0,
      failures: (row['failures'] as num?)?.toInt() ?? 0,
      averageLatencyMs: ((row['avgElapsed'] as num?) ?? 0).round(),
    );
  }

  Future<int> clear() => _db.delete('dns_race_log');

  static RaceLogRecord _fromRow(Map<String, Object?> row) => RaceLogRecord(
    timestamp: (row['timestamp'] as num?)?.toInt() ?? 0,
    queryName: row['queryName'] as String? ?? '',
    strategy: row['strategy'] as String? ?? '',
    providerCount: (row['providerCount'] as num?)?.toInt() ?? 0,
    success: (row['success'] as num?)?.toInt() == 1,
    elapsedMs: (row['elapsedMs'] as num?)?.toInt() ?? 0,
    winnerProviderId: row['winnerProviderId'] as String?,
    winnerElapsedMs: (row['winnerElapsedMs'] as num?)?.toInt(),
    message: row['message'] as String?,
  );
}

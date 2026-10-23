/// Filtered read access to the legacy `dns_log` table, for the request log
/// page. The dashboard uses the unfiltered queries of `dns_log_repository.dart`.
///
/// The per-status SQL below is copied verbatim from the legacy repository; do
/// not simplify it. The rewrite markers are why a rewritten query is not
/// counted as passed, and the `TCP ` / `UDP ` prefix exclusions keep connection
/// lines out of the DNS result set.
library;

import 'package:sqflite/sqflite.dart';

import 'package:diting/data/db/http_request_repository.dart' show RequestStatus;

/// One `dns_log` row.
class DnsLogRow {
  const DnsLogRow({
    required this.id,
    required this.timestamp,
    required this.queryName,
    required this.queryType,
    required this.result,
    required this.cached,
    this.message,
    this.packageName,
    this.blockSubscriptionId,
  });

  final int id;
  final int timestamp;
  final String queryName;
  final int queryType;

    /// `PASSED` / `REWRITTEN` / `BLOCKED` / `ERROR`.
  final String result;
  final bool cached;
  final String? message;
  final String? packageName;
  final int? blockSubscriptionId;

    /// Whether the row is a connection log line rather than a DNS query: no query
    /// type, a `TCP ` / `UDP ` prefixed name, or `blocked_by=connection`.
  bool get isConnection =>
      queryType == 0 ||
      queryName.startsWith('TCP ') ||
      queryName.startsWith('UDP ') ||
      (message?.contains('blocked_by=connection') ?? false);

    /// Blocked by the firewall: `result = BLOCKED` or `blocked_by=firewall:`.
  bool get isBlocked =>
      result == 'BLOCKED' ||
      (message?.contains('blocked_by=firewall:') ?? false);

    /// Rewritten: the result column says so, or the message carries a rewrite
    /// marker. The Chinese markers come from legacy rule descriptions.
  bool get isRewritten =>
      result == 'REWRITTEN' ||
      (message?.contains('blocked_by=rewrite=') ?? false) ||
      (message?.contains('matched rewrite rule') ?? false) ||
      (message?.contains('复写') ?? false) ||
      (message?.contains('覆写') ?? false);

    /// Display bucket. Only `result = ERROR` maps to `error`; connection rows fold
    /// into bypassed or blocked instead.
  RequestStatus get status {
    if (isConnection) {
      return isBlocked ? RequestStatus.blocked : RequestStatus.bypassed;
    }
    if (isRewritten) return RequestStatus.rewritten;
    return switch (result) {
      'PASSED' => RequestStatus.passed,
      'BLOCKED' => RequestStatus.blocked,
      _ => RequestStatus.error,
    };
  }
}

/// Parsed form of `dns_log.message`.
///
/// The writer joins entries as `app=.., resolved=.., blocked_by=.., error=..,
/// elapsed=NNms`, so splitting on the first `=` per token is enough; values may
/// themselves contain `=`.
class DnsLogMessage {
  const DnsLogMessage({
    this.app,
    this.resolved,
    this.blockedBy,
    this.error,
    this.elapsedMs,
  });

  final String? app;
  final String? resolved;
  final String? blockedBy;
  final String? error;
  final int? elapsedMs;

    /// Keeps the known keys. Unknown tokens are dropped: the detail sheet labels
    /// each field, so a raw `foo=bar` would look like a bug.
  static DnsLogMessage parse(String? message) {
    if (message == null || message.isEmpty) return const DnsLogMessage();
    String? app;
    String? resolved;
    String? blockedBy;
    String? error;
    int? elapsed;
    for (final raw in message.split(',')) {
      final token = raw.trim();
      final separator = token.indexOf('=');
      if (separator <= 0) continue;
      final key = token.substring(0, separator).trim();
      final value = token.substring(separator + 1).trim();
      if (value.isEmpty) continue;
      switch (key) {
        case 'app':
          app = value;
        case 'resolved':
          resolved = value;
        case 'blocked_by':
          blockedBy = value;
        case 'error':
          error = value;
        case 'elapsed':
          elapsed = int.tryParse(
            value.endsWith('ms') ? value.substring(0, value.length - 2) : value,
          );
      }
    }
    return DnsLogMessage(
      app: app,
      resolved: resolved,
      blockedBy: blockedBy,
      error: error,
      elapsedMs: elapsed,
    );
  }
}

class DnsQueryRepository {
  DnsQueryRepository(this._db);

  final Database _db;

    /// Newest first. [status] defaults to `all`; the page chips select one bucket
    /// at a time, so there is no `IN (...)` path.
  Future<List<DnsLogRow>> recent({
    int limit = 200,
    RequestStatus status = RequestStatus.all,
    String query = '',
  }) async {
    final sql = StringBuffer('SELECT * FROM dns_log WHERE 1=1');
    final args = <Object?>[];

    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      sql.write(
        ' AND (queryName LIKE ? OR packageName LIKE ? '
        'OR message LIKE ?)',
      );
      final pattern = '%${trimmed.toLowerCase()}%';
      args
        ..add(pattern)
        ..add(pattern)
        ..add(pattern);
    }

    final clause = _statusClause(status);
    if (clause != null) sql.write(clause);

    sql.write(' ORDER BY timestamp DESC LIMIT ${limit < 0 ? 0 : limit}');
    final rows = await _db.rawQuery(sql.toString(), args);
    return [for (final row in rows) _fromRow(row)];
  }

    /// Single-bucket SQL, whitespace included, so it stays verbatim.
  static String? _statusClause(RequestStatus status) => switch (status) {
    RequestStatus.all => null,
    RequestStatus.passed =>
      " AND result = 'PASSED' AND queryType > 0 AND queryName NOT LIKE 'TCP %' "
          "AND queryName NOT LIKE 'UDP %' AND (message IS NULL OR (message NOT "
          "LIKE '%blocked_by=connection%' AND message NOT LIKE "
          "'%blocked_by=rewrite=%' AND message NOT LIKE '%matched rewrite "
          "rule%' AND message NOT LIKE '%复写%' AND message NOT LIKE '%覆写%'))",
    RequestStatus.rewritten =>
      " AND (result = 'REWRITTEN' OR message LIKE '%blocked_by=rewrite=%' OR "
          "message LIKE '%matched rewrite rule%' OR message LIKE '%复写%' OR "
          "message LIKE '%覆写%') AND queryType > 0 AND queryName NOT LIKE "
          "'TCP %' AND queryName NOT LIKE 'UDP %' AND (message IS NULL OR "
          "message NOT LIKE '%blocked_by=connection%')",
    RequestStatus.blocked =>
      " AND (result = 'BLOCKED' OR message LIKE '%blocked_by=firewall:%') "
          "AND (message IS NULL OR (message NOT LIKE '%blocked_by=rewrite=%' "
          "AND message NOT LIKE '%matched rewrite rule%' AND message NOT LIKE "
          "'%复写%' AND message NOT LIKE '%覆写%'))",
    RequestStatus.error =>
      " AND result = 'ERROR' AND queryType > 0 AND queryName NOT LIKE 'TCP %' "
          "AND queryName NOT LIKE 'UDP %' AND (message IS NULL OR (message NOT "
          "LIKE '%blocked_by=connection%' AND message NOT LIKE "
          "'%blocked_by=rewrite=%' AND message NOT LIKE '%matched rewrite "
          "rule%' AND message NOT LIKE '%复写%' AND message NOT LIKE '%覆写%'))",
    RequestStatus.bypassed =>
      " AND (queryType = 0 OR queryName LIKE 'TCP %' OR queryName LIKE "
          "'UDP %' OR message LIKE '%blocked_by=connection%') AND (message IS "
          "NULL OR message NOT LIKE '%blocked_by=firewall:%')",
  };

  static DnsLogRow _fromRow(Map<String, Object?> row) => DnsLogRow(
    id: (row['id'] as num?)?.toInt() ?? 0,
    timestamp: (row['timestamp'] as num?)?.toInt() ?? 0,
    queryName: row['queryName'] as String? ?? '',
    queryType: (row['queryType'] as num?)?.toInt() ?? 0,
    result: row['result'] as String? ?? '',
    cached: (row['cached'] as num?)?.toInt() == 1,
    message: row['message'] as String?,
    packageName: row['packageName'] as String?,
    blockSubscriptionId: (row['blockSubscriptionId'] as num?)?.toInt(),
  );
}

/// Read access to the legacy `dns_log` table, filtered the way 1.4.3's request
/// log filtered it.
///
/// The page-level repository (`dns_log_repository.dart`) stays read-only and
/// unfiltered because the log dashboard needs "everything, newest first"; this
/// one carries the per-status SQL, which is more specific than the dashboard's.
///
/// `PASSED` / `REWRITTEN` / `BLOCKED` / `ERROR` / `BYPASSED` below are copied
/// **verbatim** from
/// `DITING-Legacy/app/src/main/java/com/haoze/diting/data/repository/RequestLogRepository.kt`
/// lines 56-70. Do not "simplify" them: the `LIKE '%blocked_by=rewrite=%'` and
/// the `%复写%` / `%覆写%` literals are why a rewritten query is not counted as
/// passed, and the `TCP ` / `UDP ` prefix exclusions are what keep connection
/// log lines out of the DNS result set.
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

  /// `PASSED` / `REWRITTEN` / `BLOCKED` / `ERROR`（1.4.3 `LogResult`）。
  final String result;
  final bool cached;
  final String? message;
  final String? packageName;
  final int? blockSubscriptionId;

  /// 1.4.3 `dnsRequestItem` 判定「这是一条连接日志而不是域名查询」的条件：
  /// `queryType == 0`（连接行不写查询类型）、`TCP `/`UDP ` 前缀（引擎把连接写成
  /// `TCP 1.2.3.4:443`）或 `blocked_by=connection`。
  bool get isConnection =>
      queryType == 0 ||
      queryName.startsWith('TCP ') ||
      queryName.startsWith('UDP ') ||
      (message?.contains('blocked_by=connection') ?? false);

  /// 被防火墙拦下的连接：`result = BLOCKED` 或 `blocked_by=firewall:...`。
  bool get isBlocked =>
      result == 'BLOCKED' ||
      (message?.contains('blocked_by=firewall:') ?? false);

  /// 覆写：结果列本身是 `REWRITTEN`，或 message 里带改写标记（旧版同时看
  /// 英文短语与中文「复写 / 覆写」，中文来自旧规则的说明文案）。
  bool get isRewritten =>
      result == 'REWRITTEN' ||
      (message?.contains('blocked_by=rewrite=') ?? false) ||
      (message?.contains('matched rewrite rule') ?? false) ||
      (message?.contains('复写') ?? false) ||
      (message?.contains('覆写') ?? false);

  /// 列表页的展示档位。落到 `error` 的只有 `result = ERROR`：连接行在旧版被
  /// 折成旁路/拦截两档，这里保持同一语义。
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

/// `dns_log.message` 的拆解结果。
///
/// The native writer joins these as `app=.., resolved=.., blocked_by=..,
/// error=.., elapsed=NNms`, so a plain `key=value` split is enough — but the
/// values themselves may contain `=`, hence splitting on the **first** `=` only.
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

  /// Parses `app=.., resolved=..` and keeps every known key. Unknown tokens are
  /// dropped rather than shown raw: the detail sheet labels each field, and an
  /// unlabelled `foo=bar` would read like a bug.
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

  /// Newest first, with the same status/query filter as 1.4.3.
  ///
  /// [status] defaults to `all`; the page's chips select a single档位 at a time
  /// (旧版 `RequestStatus` 是单选), so there is no `IN (...)` path here.
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

  /// 1.4.3 的 `RequestStatus` 单档 SQL。返回值与原文逐字一致（含空格）。
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

/// Read/delete access to the legacy `http_request_log` table.
///
/// Rows are written by the native services (1.4.3 used `HttpRequestLogger`), so
/// this repository is read-only apart from "clear all".
///
/// Every filter clause below is copied verbatim from
/// `Android/app/src/main/java/com/haoze/diting/data/repository/RequestLogRepository.kt`
/// (`load()`), including the `IN (...)` lists and the `ORDER BY timestamp DESC
/// LIMIT n` tail, so the counts on this screen match what 1.4.3 showed.
library;

import 'package:sqflite/sqflite.dart';

/// 1.4.3 `RequestStatus`（`data/RequestLogModels.kt`），六档。
///
/// 页面上的三态配色不够用：`rewritten`（覆写成功）和 `bypassed`（旁路直连）
/// 都不是失败，套进「成功 / 拦截 / 失败」只能二选一地误报。这里保留旧版六档
/// 与原文标签，颜色由页面按档位映射。
enum RequestStatus {
  all('全部', '显示所有请求记录'),
  passed('通过', '请求正常放行，未命中拦截规则'),
  rewritten('覆写', '请求命中了覆写规则，并返回覆写后的结果'),
  blocked('过滤', '请求命中了过滤规则并被拦截'),
  error('失败', '请求解析或处理失败'),
  bypassed('旁路', '请求未被读取或过滤，直接建立连接');

  const RequestStatus(this.label, this.explanation);

  final String label;
  final String explanation;
}

/// 1.4.3 `RequestSource`：请求来源的两个表。
enum RequestSource {
  all('全部'),
  dns('DNS'),
  https('HTTPS');

  const RequestSource(this.label);

  final String label;
}

/// 一条 HTTPS 请求记录（`http_request_log` 一行的等价物）。
class HttpRequestRecord {
  const HttpRequestRecord({
    required this.id,
    required this.timestamp,
    required this.packageName,
    required this.protocol,
    required this.outcome,
    this.authority,
    this.matchedRule,
    this.blockSubscriptionId,
  });

  final int id;
  final int timestamp;
  final String packageName;

  /// 可能为空：1.4.3 在拿不到 authority（例如 TLS 失败早期）时写 null。
  final String? authority;

  /// `h2` / `http/1.1` 等，由引擎上报。
  final String protocol;

  /// 落盘原值，见 [statusOfOutcome]。
  final String outcome;
  final String? matchedRule;
  final int? blockSubscriptionId;

  /// 处置档位。与旧版 `httpRequestItem` 的 `when (log.outcome)` 逐字一致：
  /// 任何未列出的 outcome 都算 `error`，包括引擎新增的失败类型。
  RequestStatus get status => statusOfOutcome(outcome);
}

/// `outcome` → [RequestStatus]。四个直连值来自旧版 `directOutcomes`。
RequestStatus statusOfOutcome(String outcome) => switch (outcome) {
  'allowed' => RequestStatus.passed,
  'rewritten' => RequestStatus.rewritten,
  'blocked' || 'invalid' => RequestStatus.blocked,
  'passthrough' ||
  'bypassed' ||
  'unsupported_protocol' ||
  'resource_bypass' => RequestStatus.bypassed,
  _ => RequestStatus.error,
};

/// `dailyStats` 的结果：总数 + 按 `outcome` 原值分组。
class HttpRequestDailyStats {
  const HttpRequestDailyStats({required this.total, required this.byOutcome});

  const HttpRequestDailyStats.empty() : total = 0, byOutcome = const {};

  final int total;

  /// 键是落盘原值（`allowed` / `blocked` / …），不是档位。
  final Map<String, int> byOutcome;

  /// 某一档的条数。[RequestStatus.all] 返回 [total]。
  int countFor(RequestStatus status) {
    if (status == RequestStatus.all) return total;
    var count = 0;
    for (final entry in byOutcome.entries) {
      if (statusOfOutcome(entry.key) == status) count += entry.value;
    }
    return count;
  }
}

class HttpRequestRepository {
  HttpRequestRepository(this._db);

  final Database _db;

  /// `LIKE` patterns are lower-cased like the legacy repository does. SQLite's
  /// `LIKE` is ASCII case-insensitive by default, and `HttpRequestLogger`
  /// already lower-cases `authority` on write, so a mixed-case `matchedRule`
  /// is the only field this can under-match — same as 1.4.3.
  Future<List<HttpRequestRecord>> recent({
    int limit = 200,
    RequestStatus status = RequestStatus.all,
    String query = '',
  }) async {
    final trimmed = query.trim();
    final args = <Object?>[];
    final sql = StringBuffer('SELECT * FROM http_request_log WHERE 1=1');

    if (trimmed.isNotEmpty) {
      sql.write(' AND (authority LIKE ? OR packageName LIKE ? '
          'OR matchedRule LIKE ?)');
      final pattern = '%${trimmed.toLowerCase()}%';
      args..add(pattern)..add(pattern)..add(pattern);
    }

    switch (status) {
      case RequestStatus.all:
        break;
      case RequestStatus.passed:
        sql.write(" AND outcome = 'allowed'");
      case RequestStatus.rewritten:
        sql.write(" AND outcome = 'rewritten'");
      case RequestStatus.blocked:
        sql.write(" AND outcome IN ('blocked', 'invalid')");
      case RequestStatus.error:
        sql.write(
          " AND outcome NOT IN ('allowed', 'rewritten', 'blocked', 'invalid', "
          "'passthrough', 'bypassed', 'unsupported_protocol', "
          "'resource_bypass')",
        );
      case RequestStatus.bypassed:
        sql.write(
          " AND outcome IN ('passthrough', 'bypassed', 'unsupported_protocol', "
          "'resource_bypass')",
        );
    }

    sql.write(' ORDER BY timestamp DESC LIMIT ${limit < 0 ? 0 : limit}');
    final rows = await _db.rawQuery(sql.toString(), args);
    return [for (final row in rows) _fromRow(row)];
  }

  /// `HttpRequestLogDao.dailyStats`：按 `outcome` 分组的当日计数。
  ///
  /// 与 `countSince` 分开是旧版的写法；这里把它们合成一次扫描，`total` 取
  /// 分组计数之和——两者用同一个窗口，不会出现「总数」与「分档」跨零点错位。
  Future<HttpRequestDailyStats> dailyStats({DateTime? since}) async {
    final start = (since ?? _startOfToday()).millisecondsSinceEpoch;
    final rows = await _db.rawQuery(
      'SELECT outcome, COUNT(*) AS count FROM http_request_log '
      'WHERE timestamp >= ? GROUP BY outcome',
      [start],
    );
    final byOutcome = <String, int>{};
    var total = 0;
    for (final row in rows) {
      final count = (row['count'] as num?)?.toInt() ?? 0;
      byOutcome[row['outcome'] as String? ?? ''] = count;
      total += count;
    }
    return HttpRequestDailyStats(total: total, byOutcome: byOutcome);
  }

  Future<int> clearAll() => _db.delete('http_request_log');

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static HttpRequestRecord _fromRow(Map<String, Object?> row) =>
      HttpRequestRecord(
        id: (row['id'] as num?)?.toInt() ?? 0,
        timestamp: (row['timestamp'] as num?)?.toInt() ?? 0,
        packageName: row['packageName'] as String? ?? '',
        protocol: row['protocol'] as String? ?? '',
        outcome: row['outcome'] as String? ?? '',
        authority: row['authority'] as String?,
        matchedRule: row['matchedRule'] as String?,
        blockSubscriptionId: (row['blockSubscriptionId'] as num?)?.toInt(),
      );
}

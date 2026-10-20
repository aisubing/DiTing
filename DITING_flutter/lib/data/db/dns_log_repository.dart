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

  Future<int> clear() => _db.delete('dns_log');

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

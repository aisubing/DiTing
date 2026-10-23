/// Read access to the legacy persisted `dns_cache` table.
///
/// Only the legacy app wrote these rows; the engine keeps its own in-memory
/// LRU, so this table is a snapshot and may lag behind or run empty.
library;

import 'package:sqflite/sqflite.dart';

class DnsCacheRecord {
  const DnsCacheRecord({
    required this.domain,
    required this.queryType,
    required this.expiresAt,
    required this.hitCount,
    required this.originalTtlSeconds,
    required this.responseSize,
  });

  final String domain;
  final int queryType;
  final int expiresAt;
  final int hitCount;
  final int originalTtlSeconds;
  final int responseSize;

  int get remainingTtlSeconds {
    final remaining = expiresAt - DateTime.now().millisecondsSinceEpoch;
    return remaining <= 0 ? 0 : remaining ~/ 1000;
  }
}

class DnsCacheRepository {
  DnsCacheRepository(this._db);

  final Database _db;

  Future<List<DnsCacheRecord>> entries({int limit = 200}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _db.query(
      'dns_cache',
      columns: [
        'queryName',
        'queryType',
        'expiresAt',
        'hitCount',
        'originalTtlSeconds',
        'responseSize',
      ],
            // Like the legacy `observeValid`: expired rows are hidden, since the
            // engine can no longer serve them.
      where: 'expiresAt > ?',
      whereArgs: [now],
      orderBy: 'hitCount DESC, expiresAt DESC',
      limit: limit,
    );
    return [for (final row in rows) _fromRow(row)];
  }

    /// Number of unexpired entries.
  Future<int> countUnexpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM dns_cache WHERE expiresAt > ?',
      [now],
    );
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }

    /// Lifetime hits over the whole table, expired rows included, because those
    /// hits did happen.
  Future<int> totalHitCount() async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(hitCount), 0) AS n FROM dns_cache',
    );
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }

  static DnsCacheRecord _fromRow(Map<String, Object?> row) => DnsCacheRecord(
    domain: row['queryName'] as String? ?? '',
    queryType: (row['queryType'] as num?)?.toInt() ?? 1,
    expiresAt: (row['expiresAt'] as num?)?.toInt() ?? 0,
    hitCount: (row['hitCount'] as num?)?.toInt() ?? 0,
    originalTtlSeconds: (row['originalTtlSeconds'] as num?)?.toInt() ?? 0,
    responseSize: (row['responseSize'] as num?)?.toInt() ?? 0,
  );
}

/// Read access to the legacy persisted DNS cache table.
///
/// 1.4.3 wrote every cached response into `dns_cache` through Room; the
/// upgraded install still holds those rows. The Go engine keeps its own
/// in-memory LRU, so a fresh tunnel may show an empty table until the legacy
/// rows expire — the table is a snapshot, not a live view.
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
      // Legacy `observeValid` also hides expired rows; showing them as TTL 0
      // would misrepresent a cache the engine can no longer serve.
      where: 'expiresAt > ?',
      whereArgs: [now],
      orderBy: 'hitCount DESC, expiresAt DESC',
      limit: limit,
    );
    return [for (final row in rows) _fromRow(row)];
  }

  /// `DnsCacheDao.countUnexpired`：有效缓存条数（概览块的「有效缓存」）。
  Future<int> countUnexpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS n FROM dns_cache WHERE expiresAt > ?',
      [now],
    );
    return (rows.first['n'] as num?)?.toInt() ?? 0;
  }

  /// `DnsCacheDao.totalHitCount`：`COALESCE(SUM(hitCount), 0)`。
  ///
  /// 统计的是**整张表**的命中累计，不过期过滤：过期行的命中确实发生过，
  /// 旧版「累计缓存命中」也是这么算的。
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

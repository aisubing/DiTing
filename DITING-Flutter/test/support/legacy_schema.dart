import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The exact 1.4.3 table layout, read off the device with `sqlite3 .schema`.
///
/// Kept in `test/support/` rather than inline because all three observability
/// repositories are exercised against the same database: duplicating the DDL
/// per test file is how a column name silently drifts in one copy only.
///
/// Notes that matter for the assertions:
/// - `http_request_log.id` is `INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL`, and
///   `authority` / `matchedRule` / `blockSubscriptionId` are nullable while
///   `outcome` / `protocol` are not — 1.4.3 reports "未取得 authority" for the
///   nullable case, so nulls must be representable here.
/// - `dns_log.cached` is `INTEGER NOT NULL DEFAULT 0` (Room stores booleans as
///   0/1); the repository reads it with `== 1`, not as a bool.
/// - `app_traffic_daily` is keyed by `(date, package_name)`; `date` is a
///   `yyyy-MM-dd` string, so `>=` / `<=` on it are date comparisons.
Future<void> createLegacySchema(Database db) async {
  await db.execute(
    'CREATE TABLE http_request_log ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, '
    'timestamp INTEGER NOT NULL, '
    'packageName TEXT NOT NULL, '
    'authority TEXT, '
    'protocol TEXT NOT NULL, '
    'outcome TEXT NOT NULL, '
    'matchedRule TEXT, '
    'blockSubscriptionId INTEGER)',
  );
  await db.execute(
    'CREATE INDEX index_http_request_log_timestamp '
    'ON http_request_log (timestamp)',
  );
  await db.execute(
    'CREATE INDEX index_http_request_log_outcome_timestamp '
    'ON http_request_log (outcome, timestamp)',
  );
  await db.execute(
    'CREATE TABLE dns_log ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, '
    'timestamp INTEGER NOT NULL, '
    'queryName TEXT NOT NULL, '
    'queryType INTEGER NOT NULL, '
    'result TEXT NOT NULL, '
    'message TEXT, '
    'cached INTEGER NOT NULL DEFAULT 0, '
    'blockSubscriptionId INTEGER, '
    'packageName TEXT)',
  );
  await db.execute(
    'CREATE INDEX index_dns_log_result_cached_timestamp '
    'ON dns_log (result, cached, timestamp)',
  );
  await db.execute(
    'CREATE TABLE app_traffic_daily ('
    'date TEXT NOT NULL, '
    'package_name TEXT NOT NULL, '
    'app_name TEXT NOT NULL, '
    'tx_bytes INTEGER NOT NULL, '
    'rx_bytes INTEGER NOT NULL, '
    'updated_at INTEGER NOT NULL, '
    'PRIMARY KEY(date, package_name))',
  );
}

/// Inserts one `http_request_log` row. Defaults mirror what `HttpRequestLogger`
/// writes: `protocol` is always present, `authority` may be null (TLS failed
/// before the request line was parsed).
Future<int> insertHttpRow(
  Database db, {
  required int timestamp,
  required String outcome,
  String packageName = 'com.example.app',
  String? authority,
  String protocol = 'h2',
  String? matchedRule,
  int? blockSubscriptionId,
}) => db.insert('http_request_log', {
  'timestamp': timestamp,
  'packageName': packageName,
  'authority': authority,
  'protocol': protocol,
  'outcome': outcome,
  'matchedRule': matchedRule,
  'blockSubscriptionId': blockSubscriptionId,
});

/// Inserts one `dns_log` row. `queryType` defaults to 1 (A record) because 0
/// is reserved for connection log lines (`TCP 1.2.3.4:443`).
Future<int> insertDnsRow(
  Database db, {
  required int timestamp,
  required String queryName,
  required String result,
  int queryType = 1,
  String? message,
  bool cached = false,
  String? packageName,
}) => db.insert('dns_log', {
  'timestamp': timestamp,
  'queryName': queryName,
  'queryType': queryType,
  'result': result,
  'message': message,
  'cached': cached ? 1 : 0,
  'packageName': packageName,
});

/// Inserts one `app_traffic_daily` row.
Future<int> insertTrafficRow(
  Database db,
  String date,
  String packageName, {
  required int tx,
  required int rx,
  String appName = '',
  int updatedAt = 1,
}) => db.insert('app_traffic_daily', {
  'date': date,
  'package_name': packageName,
  'app_name': appName,
  'tx_bytes': tx,
  'rx_bytes': rx,
  'updated_at': updatedAt,
});

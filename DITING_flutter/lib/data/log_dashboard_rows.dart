/// 概览块里「一行请求」的映射规则：旧库行 → [LogRecentRequest]。
///
/// 逐条转写自 `Android/.../ui/ModernLogDashboardViewModel.kt` 的
/// `mergedRequestLogs` / `normalizeHttpOutcome` 与
/// `ui/dashboard/DashboardLogLabels.kt`，刻意做成不碰数据库的纯函数：这几条判定
/// （连接行算旁路、覆写不算通过、中文「复写 / 覆写」也算覆写）最容易在重构里
/// 被「简化」掉，单独放一处才能被单元测试钉住。
library;

import 'package:diting/data/db/dns_log_repository.dart';
import 'package:diting/data/db/http_request_repository.dart';
import 'package:diting/data/dns_type_name.dart';
import 'package:diting/data/log_dashboard_models.dart';

/// 毫秒时间戳 → `HH:mm:ss`。时间戳缺失（0）时给 `--:--:--`，不用当前时钟冒充。
String dashboardClockOf(int milliseconds) {
  if (milliseconds <= 0) return '--:--:--';
  final time = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

/// 这一行是不是连接日志而不是域名查询（旧版 `mergedRequestLogs` 的 `isConn`）。
bool isConnectionLog({
  required int queryType,
  required String queryName,
  String? message,
}) =>
    queryType == 0 ||
    queryName.startsWith('TCP ') ||
    queryName.startsWith('UDP ') ||
    (message?.contains('blocked_by=connection') ?? false);

/// 结果标签（旧版 `dashboardDnsResultLabel`）。
///
/// 末尾的 `else => result` 是旧版原文：未知结果原样显示。**不要**把它搬进
/// `DnsLogRepository.dailyStats` 的分档 switch——那里多一个兜底就会把引擎新增的
/// 结果值悄悄算进「通过」（README §7.2 第 4 条）。
String dnsResultLabelOf(String result, {required bool isConnection}) =>
    switch (result) {
      'PASSED' => isConnection ? '旁路' : '通过',
      'REWRITTEN' => '覆写',
      'BLOCKED' => '过滤',
      'ERROR' => '失败',
      _ => result,
    };

/// 结果档位（旧版 `dashboardDnsResultStatus` 的四档 + 缓存命中）。
///
/// 旧版的 `rewritten` 在本仓的 [LogRowStatus] 里没有对应项：覆写不是失败，
/// 归到 `passed` 会丢信息，因此行文案保留「覆写」、颜色按通过处理。
LogRowStatus dnsRowStatusOf(
  String result, {
  required bool isConnection,
  required bool cached,
}) {
  if (result == 'BLOCKED') return LogRowStatus.filtered;
  if (result == 'ERROR') return LogRowStatus.failed;
  if (isConnection) return LogRowStatus.bypassed;
  return cached ? LogRowStatus.cached : LogRowStatus.passed;
}

/// 副标题：`A · 命中缓存 · app=…` 或 `TCP 直连 · com.example`。
String dnsRowMetaOf({
  required int queryType,
  required String queryName,
  required bool cached,
  String? message,
  String? packageName,
}) {
  final connection = isConnectionLog(
    queryType: queryType,
    queryName: queryName,
    message: message,
  );
  if (connection) {
    final protocol = queryName.startsWith('UDP') ? 'UDP' : 'TCP';
    return packageName == null || packageName.isEmpty
        ? '$protocol 直连'
        : '$protocol 直连 · $packageName';
  }
  final parts = <String>[dnsTypeName(queryType)];
  if (cached) parts.add('命中缓存');
  if (message != null && message.isNotEmpty) parts.add(message);
  return parts.join(' · ');
}

/// 来源列：`DNS` / `TCP` / `UDP` / `HTTPS`。
String dnsRowSourceOf({required int queryType, required String queryName}) {
  final connection = isConnectionLog(
    queryType: queryType,
    queryName: queryName,
  );
  if (!connection) return 'DNS';
  return queryName.startsWith('UDP') ? 'UDP' : 'TCP';
}

/// `dns_log` 一行 → 概览行。
LogRecentRequest logRecentRequestOfDns(DnsLogRecord row) {
  final connection = isConnectionLog(
    queryType: row.queryType,
    queryName: row.domain,
    message: row.message,
  );
  return LogRecentRequest(
    time: dashboardClockOf(row.timestamp),
    name: row.domain,
    source: dnsRowSourceOf(queryType: row.queryType, queryName: row.domain),
    meta: dnsRowMetaOf(
      queryType: row.queryType,
      queryName: row.domain,
      cached: row.cached,
      message: row.message,
      packageName: row.packageName,
    ),
    resultLabel: dnsResultLabelOf(row.result, isConnection: connection),
    status: dnsRowStatusOf(
      row.result,
      isConnection: connection,
      cached: row.cached,
    ),
  );
}

/// `http_request_log` 一行 → 概览行（旧版 `normalizeHttpOutcome` 的四档）。
LogRecentRequest logRecentRequestOfHttp(HttpRequestRecord row) {
  final status = httpRowStatusOf(row.outcome);
  final meta = <String>[
    if (row.protocol.isNotEmpty) row.protocol,
    if (row.packageName.isNotEmpty) row.packageName,
    if ((row.matchedRule ?? '').isNotEmpty) row.matchedRule!,
  ].join(' · ');
  return LogRecentRequest(
    time: dashboardClockOf(row.timestamp),
    name: (row.authority ?? '').isEmpty ? '未取得 authority' : row.authority!,
    source: 'HTTPS',
    meta: meta,
    resultLabel: switch (status) {
      LogRowStatus.filtered => '过滤',
      LogRowStatus.bypassed => '旁路',
      LogRowStatus.failed => '失败',
      _ => '通过',
    },
    status: status,
  );
}

/// HTTPS `outcome` → 概览档位。
///
/// 与 `statusOfOutcome` 的区别只在命名：旧版概览把 `rewritten` 也算「通过」，
/// 因为 HTTPS 覆写成功的请求确实被正常放行。四个直连值都算旁路。
LogRowStatus httpRowStatusOf(String outcome) => switch (outcome) {
  'allowed' || 'rewritten' => LogRowStatus.passed,
  'blocked' || 'invalid' => LogRowStatus.filtered,
  'passthrough' ||
  'bypassed' ||
  'unsupported_protocol' ||
  'resource_bypass' => LogRowStatus.bypassed,
  _ => LogRowStatus.failed,
};

/// 概览的「通过」是否要把这一档算进去。
///
/// 「仅拦截与错误」模式下旧版只保留非通过的 HTTP 行（
/// `filter { logMode == ALL || normalizeHttpOutcome(outcome) != "passed" }`）。
bool httpOutcomeIsPassed(String outcome) =>
    httpRowStatusOf(outcome) == LogRowStatus.passed;

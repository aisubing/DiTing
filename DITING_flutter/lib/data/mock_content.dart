part of 'mock_data.dart';

/// 服务统计（服务器模式 / 日志概览共用）。
///
/// 只由 `ServiceStatsNotifier.applyNative` 从原生引擎的真实计数器填充。
///
/// 这个文件曾经装着一整套演示订阅（5 条 `mockSubscriptions` + 4 个分组名）、
/// 40 条 `mockLogs` 与 `mockServiceStats`（28471 次查询 / 21930 次命中 / 3h42m）。
/// 它们在本轮接线后**全部没有消费方**，已删除：真正读订阅的地方走
/// `subscription` 表（`subscription_providers.dart`），真正读日志的地方走
/// `dns_log` / `http_request_log`（`log_dashboard_overview_providers.dart`），
/// 服务统计走引擎计数器。留着这些常量不会让任何页面变好，只会让下一次
/// 「先补一个演示值」变得顺手——而那正是本轮要修的病。
class ServiceStats {
  const ServiceStats({
    required this.queries,
    required this.cacheHits,
    required this.blocked,
    required this.averageLatencyMs,
    required this.uptime,
  });

  final int queries;
  final int cacheHits;
  final int blocked;
  final int averageLatencyMs;
  final Duration uptime;

  double get cacheHitRate => queries == 0 ? 0 : cacheHits / queries;

  String get uptimeLabel {
    final hours = uptime.inHours;
    final minutes = uptime.inMinutes % 60;
    final seconds = uptime.inSeconds % 60;
    if (hours > 0) {
      return '$hours小时$minutes分';
    }
    if (minutes > 0) {
      return '$minutes分$seconds秒';
    }
    return '$seconds秒';
  }
}

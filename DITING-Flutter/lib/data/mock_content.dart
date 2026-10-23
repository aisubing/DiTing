part of 'mock_data.dart';

/// Service stats shared by server mode and the log overview, filled only from the real engine
/// counters by `ServiceStatsNotifier.applyNative`.
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

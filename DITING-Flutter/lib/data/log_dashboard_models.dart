library;

enum LogRowStatus { passed, filtered, failed, bypassed, cached }

/// DNS resolution quality from today's `dns_log` rows. [cacheHitRate] divides by `passed + error`
/// only.
class LogDnsQuality {
  const LogDnsQuality({
    required this.averageLatencyMs,
    required this.latencySamples,
    required this.cacheHitRate,
  });

  const LogDnsQuality.empty()
    : averageLatencyMs = null,
      latencySamples = 0,
      cacheHitRate = 0;

  final double? averageLatencyMs;
  final int latencySamples;
  final double cacheHitRate;
}

class LogTrafficBreakdown {
  const LogTrafficBreakdown({
    required this.total,
    required this.passed,
    required this.blocked,
    required this.error,
    required this.bypassed,
    required this.cached,
  });

  const LogTrafficBreakdown.empty()
    : total = 0,
      passed = 0,
      blocked = 0,
      error = 0,
      bypassed = 0,
      cached = 0;

  final int total;
  final int passed;
  final int blocked;
  final int error;
  final int bypassed;

  /// Cache hits, a subset of [passed]; the legacy UI gave it its own legend.
  final int cached;

  double get blockRate => total == 0 ? 0 : blocked / total;

  double get cacheRate => total == 0 ? 0 : cached / total;
}

class LogRaceSummary {
  const LogRaceSummary({
    required this.requests,
    required this.successes,
    required this.averageElapsedMs,
  });

  const LogRaceSummary.empty()
    : requests = 0,
      successes = 0,
      averageElapsedMs = 0;

  final int requests;
  final int successes;
  final double averageElapsedMs;

  double get successRate => requests == 0 ? 0 : successes / requests;
}

class LogBootstrapSummary {
  const LogBootstrapSummary({
    required this.attempts,
    required this.successes,
    required this.averageElapsedMs,
  });

  const LogBootstrapSummary.empty()
    : attempts = 0,
      successes = 0,
      averageElapsedMs = 0;

  final int attempts;
  final int successes;
  final double averageElapsedMs;

  double get successRate => attempts == 0 ? 0 : successes / attempts;
}

class LogOffModeStats {
  const LogOffModeStats({
    required this.cacheEntries,
    required this.cacheHits,
    required this.raceRequests,
    required this.bootstrapAttempts,
  });

  const LogOffModeStats.empty()
    : cacheEntries = 0,
      cacheHits = 0,
      raceRequests = 0,
      bootstrapAttempts = 0;

  final int cacheEntries;
  final int cacheHits;
  final int raceRequests;
  final int bootstrapAttempts;
}

/// One recent request. [time] is derived from the row `timestamp`, never a literal.
class LogRecentRequest {
  const LogRecentRequest({
    required this.time,
    required this.name,
    required this.source,
    required this.meta,
    required this.resultLabel,
    required this.status,
  });

  final String time;
  final String name;

  final String source;

  final String meta;

  final String resultLabel;
  final LogRowStatus status;
}

class LogCacheHotspot {
  const LogCacheHotspot({
    required this.queryName,
    required this.queryType,
    required this.remainingSeconds,
    required this.responseSize,
    required this.hitCount,
  });

  final String queryName;

  final String queryType;
  final int remainingSeconds;
  final int responseSize;
  final int hitCount;
}

class LogRaceWinner {
  const LogRaceWinner({
    required this.name,
    required this.wins,
    required this.averageElapsedMs,
  });

  final String name;
  final int wins;
  final double averageElapsedMs;
}

class LogBootstrapIp {
  const LogBootstrapIp({
    required this.name,
    required this.ip,
    required this.attempts,
    required this.successes,
    required this.averageElapsedMs,
  });

  final String name;
  final String ip;
  final int attempts;
  final int successes;
  final double averageElapsedMs;

  double get successRate => attempts == 0 ? 0 : successes / attempts;
}

class LogSubscriptionBlock {
  const LogSubscriptionBlock({
    required this.name,
    required this.enabled,
    required this.deleted,
    required this.hits,
    required this.rate,
  });

  final String name;
  final bool enabled;

  final bool deleted;
  final int hits;

  final double rate;

  String get statusLabel {
    if (deleted) return '已删除';
    return enabled ? '已启用' : '已禁用';
  }
}

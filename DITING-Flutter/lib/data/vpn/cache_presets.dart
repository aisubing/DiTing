/// The three DNS cache presets of DITING 1.4.3 (`DnsCachePreset`).
///
/// Each preset overwrites nine `dns_cache_*_v2` keys; the engine reads that
/// policy directly, so the UI must write exactly these values instead of a
/// single "preset name".
library;

import 'package:diting/data/prefs/legacy_settings.dart';

enum DnsCachePreset {
  conservative(
    '保守',
    '遵从服务器有效期 (TTL)',
    '遵从 DNS 服务器返回的有效期，不主动延长缓存时间，适合经常切换网络或对实时性敏感的场景。',
    storageValue: 'conservative',
    mode: 'follow_dns_ttl',
    maxTtlSeconds: 3600,
    fixedTtlSeconds: 3600,
    minTtlEnabled: false,
    minTtlSeconds: 60,
    staleFallbackEnabled: false,
    staleFallbackSeconds: 300,
  ),
  balanced(
    '标准',
    '最长 1 小时，短记录至少 1 分钟',
    '减少重复查询，同时避免记录过期滞后。解析失败时可短暂使用 5 分钟内的旧记录应急。',
    storageValue: 'balanced',
    mode: 'limit_max_ttl',
    maxTtlSeconds: 3600,
    fixedTtlSeconds: 3600,
    minTtlEnabled: true,
    minTtlSeconds: 60,
    staleFallbackEnabled: true,
    staleFallbackSeconds: 300,
  ),
  highHitRate(
    '高命中',
    '最长 6 小时，短记录至少 2 分钟',
    '更偏向降低网络请求次数和提升弱网可用性。域名变更时更新可能会稍慢一些。',
    storageValue: 'high_hit_rate',
    mode: 'limit_max_ttl',
    maxTtlSeconds: 21600,
    fixedTtlSeconds: 3600,
    minTtlEnabled: true,
    minTtlSeconds: 120,
    staleFallbackEnabled: true,
    staleFallbackSeconds: 900,
  );

  const DnsCachePreset(
    this.label,
    this.summary,
    this.description, {
    required this.storageValue,
    required this.mode,
    required this.maxTtlSeconds,
    required this.fixedTtlSeconds,
    required this.minTtlEnabled,
    required this.minTtlSeconds,
    required this.staleFallbackEnabled,
    required this.staleFallbackSeconds,
  });

  final String label;
  final String summary;
  final String description;

  /// `dns_cache_preset_v3` value.
  final String storageValue;
  final String mode;
  final int maxTtlSeconds;
  final int fixedTtlSeconds;
  final bool minTtlEnabled;
  final int minTtlSeconds;
  final bool staleFallbackEnabled;
  final int staleFallbackSeconds;

  static DnsCachePreset? fromStorage(String? value) {
    for (final preset in values) {
      if (preset.storageValue == value) return preset;
    }
    return null;
  }

  /// `DnsCachePreset.fromPolicy` semantics: derive a preset from the raw keys so
  /// installs that predate `dns_cache_preset_v3` still show a sensible option.
  static DnsCachePreset fromPolicy(LegacySettings settings) {
    if (settings.cacheModeRaw == 'follow_dns_ttl' &&
        !settings.cacheMinTtlEnabled &&
        !settings.cacheStaleFallbackEnabled) {
      return conservative;
    }
    if (settings.cacheModeRaw == 'limit_max_ttl' &&
        settings.cacheMaxTtlSeconds <= balanced.maxTtlSeconds &&
        (!settings.cacheMinTtlEnabled ||
            settings.cacheMinTtlSeconds <= balanced.minTtlSeconds) &&
        (!settings.cacheStaleFallbackEnabled ||
            settings.cacheStaleFallbackSeconds <=
                balanced.staleFallbackSeconds)) {
      return balanced;
    }
    return highHitRate;
  }

  static DnsCachePreset current(LegacySettings settings) =>
      fromStorage(settings.cachePresetRaw) ?? fromPolicy(settings);

  void applyTo(LegacySettings settings, {required bool enabled}) {
    settings.applyCachePreset(
      storageValue: storageValue,
      enabled: enabled,
      mode: mode,
      maxTtlSeconds: maxTtlSeconds,
      fixedTtlSeconds: fixedTtlSeconds,
      minTtlEnabled: minTtlEnabled,
      minTtlSeconds: minTtlSeconds,
      staleFallbackEnabled: staleFallbackEnabled,
      staleFallbackSeconds: staleFallbackSeconds,
    );
  }
}

/// One-line cache summary for the settings row (`标准：最长 1 小时…`).
String cacheSummaryOf(LegacySettings settings) {
  if (!settings.cacheEnabled) return '已关闭 · 每次解析都会请求上游';
  final preset = DnsCachePreset.current(settings);
  return '${preset.label} · ${preset.summary}';
}

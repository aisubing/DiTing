/// Block response settings of DITING 1.4.3: fixed mode + dynamic policy.
///
/// Fixed mode stores `block_response_mode`; the dynamic policy (disabled by
/// default upstream) stores four further keys with hard clamps. `buildDnsConfig`
/// publishes both, so the page must edit these keys directly rather than local
/// snapshot state.
library;

import 'package:diting/data/prefs/legacy_settings.dart';

enum BlockResponseMode {
  nxdomain(
    'nxdomain',
    '返回 NXDOMAIN',
    '返回域名不存在，并提供 5 分钟负缓存以减少重复查询',
  ),
  nodata(
    'nodata',
    '返回 NODATA',
    '返回域名存在但没有该记录，并提供 5 分钟负缓存',
  ),
  refused('refused', '返回 REFUSED', '返回服务器拒绝该查询，不提供缓存记录'),
  zeroAddress(
    'zero_address',
    '返回 0.0.0.0 / ::',
    'A 返回 0.0.0.0，AAAA 返回 ::，其他类型返回空结果',
  );

  const BlockResponseMode(this.storageValue, this.label, this.description);

  /// Value stored in `block_response_mode`.
  final String storageValue;
  final String label;
  final String description;

  static BlockResponseMode fromStorage(String? value) {
    for (final mode in values) {
      if (mode.storageValue == value) return mode;
    }
    return nxdomain;
  }
}

/// Immutable view of the persisted dynamic policy.
class DynamicBlockPolicy {
  const DynamicBlockPolicy({
    required this.enabled,
    required this.requestThreshold,
    required this.windowSeconds,
    required this.nxDomainDurationSeconds,
  });

  final bool enabled;
  final int requestThreshold;
  final int windowSeconds;
  final int nxDomainDurationSeconds;

  /// Upstream defaults: off, 5 requests / 60 s / 300 s.
  static const defaults = DynamicBlockPolicy(
    enabled: false,
    requestThreshold: 5,
    windowSeconds: 60,
    nxDomainDurationSeconds: 300,
  );

  static DynamicBlockPolicy read(LegacySettings settings) => DynamicBlockPolicy(
    enabled: settings.dynamicBlockEnabled,
    requestThreshold: settings.dynamicBlockRequestThreshold,
    windowSeconds: settings.dynamicBlockWindowSeconds,
    nxDomainDurationSeconds: settings.dynamicBlockNxDomainDurationSeconds,
  );

  DynamicBlockPolicy copyWith({
    bool? enabled,
    int? requestThreshold,
    int? windowSeconds,
    int? nxDomainDurationSeconds,
  }) => DynamicBlockPolicy(
    enabled: enabled ?? this.enabled,
    requestThreshold: requestThreshold ?? this.requestThreshold,
    windowSeconds: windowSeconds ?? this.windowSeconds,
    nxDomainDurationSeconds:
        nxDomainDurationSeconds ?? this.nxDomainDurationSeconds,
  );

  void write(LegacySettings settings) => settings.setDynamicBlockPolicy(
    enabled: enabled,
    requestThreshold: requestThreshold,
    windowSeconds: windowSeconds,
    nxDurationSeconds: nxDomainDurationSeconds,
  );
}

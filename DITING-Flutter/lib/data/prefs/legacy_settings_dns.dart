part of 'legacy_settings.dart';

/// DNS-domain settings: providers, resolution mode, cache policy, block
/// response, bootstrap and the per-app rule switches.
///
/// Split into a part because `legacy_settings.dart` crossed the 550-line limit;
/// an extension in the same library keeps every accessor callable on
/// [LegacySettings] and can still reach the private store and helpers.
extension LegacyDnsSettings on LegacySettings {
  // ------------------------------------------------------------- dns upstream

  bool get vpnRunning =>
      _bool(LegacySettings.uiContainer, 'vpn_running', false);

  void setVpnRunning(bool value) =>
      _store.putBool(LegacySettings.uiContainer, 'vpn_running', value);

  bool get expressVpnRunning => _bool(
    LegacySettings.expressRunningContainer,
    'express_vpn_running',
    false,
  );

  void setExpressVpnRunning(bool value) => _store.putBool(
    LegacySettings.expressRunningContainer,
    'express_vpn_running',
    value,
  );

  String get selectedProviderId =>
      _string(dnsContainer, 'selected_provider_id') ?? 'preset_alidns_dns';

  void setSelectedProviderId(String id) =>
      _store.putString(dnsContainer, 'selected_provider_id', id);

  String? get userProvidersJson => _string(dnsContainer, 'user_providers_json');

  /// Provider latency as last recorded by the Go resolver
  /// (`ProviderHealthStore`, key `provider_health_json`). Values are EWMA
  /// milliseconds; a provider without history is absent from the map.
  Map<String, int> get providerLatenciesMs {
    final raw = _string(dnsContainer, 'provider_health_json');
    if (raw == null || raw.isEmpty) return const {};
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const {};
    }
    if (decoded is! Map) return const {};
    final result = <String, int>{};
    decoded.forEach((key, value) {
      if (key is! String || value is! Map) return;
      final ewma = value['ewmaMs'];
      if (ewma is num && ewma > 0) {
        result[key] = ewma.round();
      }
    });
    return result;
  }

  /// Written verbatim: the JSON array shape is the 1.4.3 contract
  /// (`id`/`name`/`protocol`/`url`/`host`/`port`).
  void setUserProvidersJson(String json) =>
      _store.putString(dnsContainer, 'user_providers_json', json);

  List<String> get smartPredictionProviderIds =>
      _idList('smart_prediction_provider_ids');

  List<String> get parallelRaceProviderIds =>
      _idList('parallel_race_provider_ids');

  List<String> get primaryBackupProviderIds =>
      _idList('primary_backup_provider_ids');

  /// 竞速候选列表。1.4.3 的键是 `race_provider_ids`，与
  /// `parallel_race_provider_ids` 是两套历史遗留，备份必须按原名带回。
  List<String> get raceProviderIds => _idList('race_provider_ids');

  void setRaceProviderIds(List<String> ids) =>
      _store.putString(dnsContainer, 'race_provider_ids', jsonEncode(ids));

  /// 测速列表（`NetworkToolsSettingsStore`），新版页面不编辑它，但备份要带上。
  List<String> get latencyTestProviderIds =>
      _idList('latency_test_provider_ids');

  void setLatencyTestProviderIds(List<String> ids) => _store.putString(
    dnsContainer,
    'latency_test_provider_ids',
    jsonEncode(ids),
  );

  /// 竞速模式默认使用的协议档（`preset_dns_service`，1.4.3 只认 DNS/DoT/DoH
  /// 三个枚举名，缺省 DNS）。2.0 的界面不再暴露这个开关，但备份必须带出去，
  /// 否则导回 1.4.3 时会退回 DNS，用户选的 DoH 竞速档位就丢了。
  String get presetDnsServiceRaw =>
      _string(dnsContainer, 'preset_dns_service') ?? 'DNS';

  void setPresetDnsServiceRaw(String value) =>
      _store.putString(dnsContainer, 'preset_dns_service', value);

  /// 竞速测试域名（`ResolutionSettingsStore`），首页竞速用它做探测。
  /// 1.4.3 的缺省值是 `mihoyo.com`，备份要带出实际生效的值而不是空串。
  String get raceTestDomain => _string(dnsContainer, 'race_test_domain') ?? 'mihoyo.com';

  void setRaceTestDomain(String domain) =>
      _store.putString(dnsContainer, 'race_test_domain', domain);

  void setSmartPredictionProviderIds(List<String> ids) => _store.putString(
    dnsContainer,
    'smart_prediction_provider_ids',
    jsonEncode(ids),
  );

  void setParallelRaceProviderIds(List<String> ids) => _store.putString(
    dnsContainer,
    'parallel_race_provider_ids',
    jsonEncode(ids),
  );

  void setPrimaryBackupProviderIds(List<String> ids) => _store.putString(
    dnsContainer,
    'primary_backup_provider_ids',
    jsonEncode(ids),
  );

  /// The mode-specific candidate list the resolution UI edits. Single mode has
  /// no list: its selection lives in `selected_provider_id`.
  List<String> providerIdsOf(String resolutionMode) => switch (resolutionMode) {
    'smart_prediction' => smartPredictionProviderIds,
    'parallel_race' => parallelRaceProviderIds,
    'primary_backup' => primaryBackupProviderIds,
    _ => const [],
  };

  void setProviderIdsOf(String resolutionMode, List<String> ids) {
    switch (resolutionMode) {
      case 'smart_prediction':
        setSmartPredictionProviderIds(ids);
      case 'parallel_race':
        setParallelRaceProviderIds(ids);
      case 'primary_backup':
        setPrimaryBackupProviderIds(ids);
      default:
        break;
    }
  }

  /// Home provider-visibility filter (`ResolutionSettingsStore`). All three
  /// values are stored as sorted JSON arrays, exactly like `writeStringSet`.
  Set<String> get homeVisibleProtocols =>
      _stringSet('home_visible_protocols') ?? const {'DNS', 'DOH', 'DOT'};

  Set<String> get homeHiddenProviderIds =>
      _stringSet('home_hidden_provider_ids') ?? const {};

  Set<String> get homeVisibleProviderIds =>
      _stringSet('home_visible_provider_ids') ?? const {};

  void setHomeProviderVisibility({
    required Set<String> visibleProtocols,
    required Set<String> hiddenProviderIds,
    required Set<String> visibleProviderIds,
  }) {
    _store.putString(
      dnsContainer,
      'home_visible_protocols',
      LegacySettings._encodeSet(visibleProtocols),
    );
    _store.putString(
      dnsContainer,
      'home_hidden_provider_ids',
      LegacySettings._encodeSet(hiddenProviderIds),
    );
    _store.putString(
      dnsContainer,
      'home_visible_provider_ids',
      LegacySettings._encodeSet(visibleProviderIds),
    );
  }

  // ------------------------------------------------------------- cache policy

  bool get cacheEnabled => _bool(dnsContainer, 'dns_cache_enabled_v2', true);

  String get cacheModeRaw =>
      _string(dnsContainer, 'dns_cache_mode_v2') ?? 'limit_max_ttl';

  int get cacheMaxTtlSeconds =>
      _int(dnsContainer, 'dns_cache_max_ttl_seconds_v2', 3600);

  int get cacheFixedTtlSeconds =>
      _int(dnsContainer, 'dns_cache_fixed_ttl_seconds_v2', 3600);

  bool get cacheMinTtlEnabled =>
      _bool(dnsContainer, 'dns_cache_min_ttl_enabled_v2', false);

  int get cacheMinTtlSeconds =>
      _int(dnsContainer, 'dns_cache_min_ttl_seconds_v2', 60);

  bool get cacheStaleFallbackEnabled =>
      _bool(dnsContainer, 'dns_cache_stale_fallback_enabled_v2', false);

  int get cacheStaleFallbackSeconds =>
      _int(dnsContainer, 'dns_cache_stale_fallback_seconds_v2', 300);

  /// `dns_cache_preset_v3`; absent on installs that predate presets, in which
  /// case the UI falls back to `fromPolicy` like 1.4.3 does.
  String? get cachePresetRaw => _string(dnsContainer, 'dns_cache_preset_v3');

  /// Persists one of the three legacy presets. All nine keys are written so the
  /// engine reads a consistent policy, exactly like `DnsCacheSettingsStore`.
  void applyCachePreset({
    required String storageValue,
    required bool enabled,
    required String mode,
    required int maxTtlSeconds,
    required int fixedTtlSeconds,
    required bool minTtlEnabled,
    required int minTtlSeconds,
    required bool staleFallbackEnabled,
    required int staleFallbackSeconds,
  }) {
    int clamp(int seconds) => LegacySettings._clampSeconds(seconds);
    _store.putString(dnsContainer, 'dns_cache_preset_v3', storageValue);
    _store.putBool(dnsContainer, 'dns_cache_enabled_v2', enabled);
    _store.putString(dnsContainer, 'dns_cache_mode_v2', mode);
    _store.putLong(
      dnsContainer,
      'dns_cache_max_ttl_seconds_v2',
      clamp(maxTtlSeconds),
    );
    _store.putLong(
      dnsContainer,
      'dns_cache_fixed_ttl_seconds_v2',
      clamp(fixedTtlSeconds),
    );
    _store.putBool(dnsContainer, 'dns_cache_min_ttl_enabled_v2', minTtlEnabled);
    _store.putLong(
      dnsContainer,
      'dns_cache_min_ttl_seconds_v2',
      clamp(minTtlSeconds),
    );
    _store.putBool(
      dnsContainer,
      'dns_cache_stale_fallback_enabled_v2',
      staleFallbackEnabled,
    );
    _store.putLong(
      dnsContainer,
      'dns_cache_stale_fallback_seconds_v2',
      clamp(staleFallbackSeconds),
    );
  }

  void setCacheEnabled(bool value) =>
      _store.putBool(dnsContainer, 'dns_cache_enabled_v2', value);

  // --------------------------------------------------------- block response

  /// Raw storage value (`nxdomain`/`nodata`/`refused`/`zero_address`).
  String get blockResponseModeRaw =>
      _string(dnsContainer, 'block_response_mode') ?? 'nxdomain';

  void setBlockResponseModeRaw(String value) =>
      _store.putString(dnsContainer, 'block_response_mode', value);

  bool get dynamicBlockEnabled =>
      _bool(dnsContainer, 'dynamic_block_response_enabled', false);

  int get dynamicBlockRequestThreshold =>
      _int(dnsContainer, 'dynamic_block_request_threshold', 5);

  int get dynamicBlockWindowSeconds =>
      _int(dnsContainer, 'dynamic_block_window_seconds', 60);

  int get dynamicBlockNxDomainDurationSeconds =>
      _int(dnsContainer, 'dynamic_block_nxdomain_duration_seconds', 300);

  /// Persists the dynamic policy with the legacy clamps (2–100 / 10–300 /
  /// 60–3600); out-of-range input must never reach the engine.
  void setDynamicBlockPolicy({
    required bool enabled,
    required int requestThreshold,
    required int windowSeconds,
    required int nxDurationSeconds,
  }) {
    _store.putBool(dnsContainer, 'dynamic_block_response_enabled', enabled);
    _store.putInt(
      dnsContainer,
      'dynamic_block_request_threshold',
      requestThreshold.clamp(2, 100),
    );
    _store.putInt(
      dnsContainer,
      'dynamic_block_window_seconds',
      windowSeconds.clamp(10, 300),
    );
    _store.putInt(
      dnsContainer,
      'dynamic_block_nxdomain_duration_seconds',
      nxDurationSeconds.clamp(60, 3600),
    );
  }

  /// Domain-rule master switch (`domain_rules_enabled`, default true).
  bool get domainRulesEnabled =>
      _bool(dnsContainer, 'domain_rules_enabled', true);

  void setDomainRulesEnabled(bool value) =>
      _store.putBool(dnsContainer, 'domain_rules_enabled', value);

  // --------------------------------------------------------------- bootstrap

  bool get bootstrapEnabled => _bool(dnsContainer, 'bootstrap_enabled', true);

  List<String> get bootstrapPresetIds => _idList(
    'bootstrap_preset_ids',
    fallback: const ['preset_volcengine', 'preset_dnspod', 'preset_alidns'],
  );

  String? get bootstrapCustomJson =>
      _string(dnsContainer, 'bootstrap_custom_json');

  void setBootstrapEnabled(bool value) =>
      _store.putBool(dnsContainer, 'bootstrap_enabled', value);

  /// Preset ids are filtered against the built-in catalog by the caller before
  /// they get here, mirroring `BootstrapDnsSettingsStore.setBootstrapPresetIds`.
  void setBootstrapPresetIds(Set<String> ids) => _store.putString(
    dnsContainer,
    'bootstrap_preset_ids',
    LegacySettings._encodeSet(ids),
  );

  void setBootstrapCustomJson(String json) =>
      _store.putString(dnsContainer, 'bootstrap_custom_json', json);

  /// HTTPS inspection switches. They are global (not dataset-scoped) and default
  /// to false upstream: only the CA flow turns `http_inspection_enabled` on.
  bool get http3InspectionEnabled =>
      _bool(LegacySettings.uiContainer, 'http3_inspection_enabled', false);

  bool get encryptedDnsBlockingEnabled => _bool(
    LegacySettings.uiContainer,
    'encrypted_dns_blocking_enabled',
    false,
  );

  /// Address (CNAME/URL) rules are the second half of HTTPS inspection.
  bool get addressRulesEnabled =>
      _bool(LegacySettings.uiContainer, 'address_rules_enabled', true);

  void setHttpInspectionToggles({
    required bool http3,
    required bool encryptedDns,
    required bool addressRules,
  }) {
    _store.putBool(
      LegacySettings.uiContainer,
      'http3_inspection_enabled',
      http3,
    );
    _store.putBool(
      LegacySettings.uiContainer,
      'encrypted_dns_blocking_enabled',
      encryptedDns,
    );
    _store.putBool(
      LegacySettings.uiContainer,
      'address_rules_enabled',
      addressRules,
    );
  }

  /// Written by the native CA flow (`go-v1` backend); the page only reads it.
  bool get httpsInspectionReady =>
      _bool(LegacySettings.uiContainer, 'https_inspection_ready', false);

  /// A view over the express-mode dataset. UI keys stay global; DNS keys move
  /// to `diting_express_prefs`, exactly like `RuleDataset.EXPRESS`.
  LegacySettings forExpress() =>
      LegacySettings(_store, dnsContainer: LegacySettings.expressContainer);
}

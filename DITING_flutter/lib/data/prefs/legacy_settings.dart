/// Typed view over the preference keys documented in
/// `docs/refactor/01-foundation-and-startup-2.md` §3.1.
///
/// Keys, containers and defaults are copied from DITING 1.4.3 verbatim; the
/// `GOLD` palette still stores `indigo`, the server dataset is still called
/// `dns`, and absent values must fall back exactly as the old stores did.
library;

import 'dart:convert';

import 'package:diting/data/prefs/legacy_prefs_store.dart';

class LegacySettings {
  LegacySettings(this._store, {String? dnsContainer})
    : dnsContainer = dnsContainer ?? uiContainer;

  final LegacyPrefsStore _store;

  /// Container for the DNS/tunnel keys. Normal and express modes use the same
  /// key names in different files; an express instance only swaps this
  /// container and keeps UI keys on [uiContainer].
  final String dnsContainer;

  /// Global UI keys (`SettingsPreferencesExtensions.PREFS_NAME`).
  static const uiContainer = 'dns_vpn_prefs';

  /// Work-mode selection (`WorkModeStore`).
  static const workModeContainer = 'diting_settings';

  /// Express-mode DNS settings (`RuleDataset.EXPRESS.prefsName`).
  static const expressContainer = 'diting_express_prefs';

  /// Express-mode runtime flag (`VpnStateRegistry.isExpressRunning`).
  static const expressRunningContainer = 'express_vpn_prefs';

  /// Server-mode settings (`DnsModePreferences`).
  static const serverContainer = 'diting_dns_mode_prefs';

  static const defaultRunningSentence = '谛听万象，明察清浊';
  static const defaultStoppedSentence = '收耳静眠，归于无声';

  static const defaultBottomBarIds = ['home', 'feature_hub', 'log_dashboard'];

  /// The only ids 1.4.3 accepts. Kept here so an unknown value in a restored
  /// backup is dropped exactly like `BottomBarDestination.fromId` did; the
  /// matching test asserts it stays in sync with the enum.
  static const bottomBarIdValues = {
    'home',
    'feature_hub',
    'log_dashboard',
    'app_traffic_stats',
    'network_tools',
    'settings',
  };

  static const bottomBarMinCount = 2;
  static const bottomBarMaxCount = 4;

  static const defaultServerPort = 1053;

  // ---------------------------------------------------------------- appearance

  String? get themeModeRaw => _string(uiContainer, 'app_theme_mode');

  void setThemeModeRaw(String storageValue) =>
      _store.putString(uiContainer, 'app_theme_mode', storageValue);

  String? get paletteRaw => _string(uiContainer, 'theme_color_style');

  void setPaletteRaw(String storageValue) =>
      _store.putString(uiContainer, 'theme_color_style', storageValue);

  double get componentOpacity => _clampedOpacity(
    _double(uiContainer, 'home_component_opacity', 1),
  );

  /// Per-element opacity falls back to the shared component opacity, exactly
  /// like `AppearanceSettingsStore.getHomeOpacity`.
  double homeOpacity(String storageKey) => _clampedOpacity(
    _double(uiContainer, storageKey, componentOpacity),
  );

  void setHomeOpacity(String storageKey, double value) => _store.putFloat(
    uiContainer,
    storageKey,
    _clampedOpacity(value),
  );

  ({String running, String stopped}) get homeSentences => (
    running:
        _string(uiContainer, 'home_sentence_running') ??
        defaultRunningSentence,
    stopped:
        _string(uiContainer, 'home_sentence_stopped') ??
        defaultStoppedSentence,
  );

  void setHomeSentences({required String running, required String stopped}) {
    _store.putString(uiContainer, 'home_sentence_running', running);
    _store.putString(uiContainer, 'home_sentence_stopped', stopped);
  }

  bool get hapticEnabled => _bool(uiContainer, 'bottom_bar_haptic_enabled', true);

  void setHapticEnabled(bool value) =>
      _store.putBool(uiContainer, 'bottom_bar_haptic_enabled', value);

  bool get defaultWhitelistInitialized =>
      _bool(uiContainer, 'default_whitelist_initialized', false);

  int get defaultWhitelistSeededVersion =>
      _int(uiContainer, 'default_whitelist_seeded_version', 0);

  /// `versionCode * 1000 + presetSchemaVersion(2)`, exactly as 1.4.3 computed it.
  void markDefaultWhitelistSeeded(int versionCode) {
    _store.putBool(uiContainer, 'default_whitelist_initialized', true);
    _store.putLong(
      uiContainer,
      'default_whitelist_seeded_version',
      versionCode * 1000 + 2,
    );
  }

  /// Parses `bottom_bar_destinations` with the legacy rules: unknown ids are
  /// dropped, duplicates collapse, fewer than two entries restores defaults,
  /// and the list is cut at four.
  List<String> get bottomBarIds {
    final raw = _string(uiContainer, 'bottom_bar_destinations');
    if (raw == null || raw.trim().isEmpty) {
      return List.of(defaultBottomBarIds);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return List.of(defaultBottomBarIds);
      }
      final ids = <String>[];
      for (final item in decoded) {
        if (item is String &&
            bottomBarIdValues.contains(item) &&
            !ids.contains(item)) {
          ids.add(item);
        }
      }
      if (ids.length < bottomBarMinCount) {
        return List.of(defaultBottomBarIds);
      }
      return ids.take(bottomBarMaxCount).toList();
    } on FormatException {
      return List.of(defaultBottomBarIds);
    }
  }

  void setBottomBarIds(List<String> ids) {
    final unique = <String>[];
    for (final id in ids) {
      if (!unique.contains(id)) {
        unique.add(id);
      }
    }
    final finalIds = unique.length < bottomBarMinCount
        ? defaultBottomBarIds
        : unique.take(bottomBarMaxCount).toList();
    _store.putString(uiContainer, 'bottom_bar_destinations', jsonEncode(finalIds));
  }

  // ---------------------------------------------------------------- work mode

  String get workModeRaw =>
      _string(workModeContainer, 'app_work_mode') ?? 'normal';

  void setWorkModeRaw(String storageValue) =>
      _store.putString(workModeContainer, 'app_work_mode', storageValue);

  bool get workModeSelected =>
      _bool(workModeContainer, 'work_mode_initial_selected', false);

  void setWorkModeSelected(bool value) =>
      _store.putBool(workModeContainer, 'work_mode_initial_selected', value);

  /// Legacy `resetWorkModeSelection` removes both keys rather than storing false.
  void clearWorkModeSelection() {
    _store.remove(workModeContainer, 'app_work_mode');
    _store.remove(workModeContainer, 'work_mode_initial_selected');
  }

  // ------------------------------------------------------------- resolution

  /// Dataset-aware resolution mode; normal reads `dns_vpn_prefs`, express
  /// reads `diting_express_prefs`.
  String get resolutionModeRaw =>
      _string(dnsContainer, 'dns_resolution_mode') ?? 'single';

  void setResolutionModeRaw(String storageValue) =>
      _store.putString(dnsContainer, 'dns_resolution_mode', storageValue);

  // ------------------------------------------------------------- dns upstream

  bool get vpnRunning => _bool(uiContainer, 'vpn_running', false);

  void setVpnRunning(bool value) =>
      _store.putBool(uiContainer, 'vpn_running', value);

  bool get expressVpnRunning =>
      _bool(expressRunningContainer, 'express_vpn_running', false);

  void setExpressVpnRunning(bool value) =>
      _store.putBool(expressRunningContainer, 'express_vpn_running', value);

  String get selectedProviderId =>
      _string(dnsContainer, 'selected_provider_id') ?? 'preset_alidns_dns';

  String? get userProvidersJson =>
      _string(dnsContainer, 'user_providers_json');

  List<String> get smartPredictionProviderIds =>
      _idList('smart_prediction_provider_ids');

  List<String> get parallelRaceProviderIds =>
      _idList('parallel_race_provider_ids');

  List<String> get primaryBackupProviderIds =>
      _idList('primary_backup_provider_ids');

  String get blockResponseModeRaw =>
      _string(dnsContainer, 'block_response_mode') ?? 'nxdomain';

  bool get cacheEnabled =>
      _bool(dnsContainer, 'dns_cache_enabled_v2', true);

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

  bool get bootstrapEnabled =>
      _bool(dnsContainer, 'bootstrap_enabled', true);

  List<String> get bootstrapPresetIds => _idList(
    'bootstrap_preset_ids',
    fallback: const ['preset_volcengine', 'preset_dnspod', 'preset_alidns'],
  );

  String? get bootstrapCustomJson =>
      _string(dnsContainer, 'bootstrap_custom_json');

  /// Raw value for keys that only the Go config builder consumes.
  Object? rawValue(String key) => _store.read(dnsContainer, key);

  /// A view over the express-mode dataset. UI keys stay global; DNS keys move
  /// to `diting_express_prefs`, exactly like `RuleDataset.EXPRESS`.
  LegacySettings forExpress() =>
      LegacySettings(_store, dnsContainer: expressContainer);

  // ------------------------------------------------------------ tunnel system

  bool get bypassLanEnabled =>
      _bool(uiContainer, 'bypass_lan_enabled', true);

  String get ipv6ModeRaw => _string(dnsContainer, 'ipv6_mode') ?? 'auto';

  Set<String> get excludedPackages {
    final value = _store.read(dnsContainer, 'excluded_app_packages');
    if (value is List) {
      return {
        for (final item in value)
          if (item is String && item.isNotEmpty) item,
      };
    }
    return const {};
  }

  // ----------------------------------------------------------- server mode

  int get serverPort =>
      _clampedPort(_int(serverContainer, 'local_listen_port', defaultServerPort));

  void setServerPort(int port) =>
      _store.putInt(serverContainer, 'local_listen_port', _clampedPort(port));

  String get serverSelectedUpstreamId =>
      _stringIn(serverContainer, 'selected_upstream_id') ?? 'preset_alidns_dns';

  void setServerSelectedUpstreamId(String id) =>
      _store.putString(serverContainer, 'selected_upstream_id', id);

  String? get serverCustomUpstreamsJson =>
      _stringIn(serverContainer, 'custom_upstreams');

  bool get serverCacheEnabled =>
      _boolIn(serverContainer, 'cache_enabled', true);

  void setServerCacheEnabled(bool value) =>
      _store.putBool(serverContainer, 'cache_enabled', value);

  /// Preset values stayed `conservative` / `balanced` / `high_hit_rate`.
  String get serverCachePresetRaw =>
      _stringIn(serverContainer, 'cache_preset') ?? 'balanced';

  bool get serverAdBlockEnabled =>
      _boolIn(serverContainer, 'ad_block_enabled', false);

  void setServerAdBlockEnabled(bool value) =>
      _store.putBool(serverContainer, 'ad_block_enabled', value);

  bool get serverLogQueries =>
      _boolIn(serverContainer, 'log_queries', false);

  bool get serverServiceActive =>
      _boolIn(serverContainer, 'service_active', false);

  void setServerServiceActive(bool value) =>
      _store.putBool(serverContainer, 'service_active', value);

  String get serverBlockResponseModeRaw =>
      _stringIn(serverContainer, 'block_response_mode') ?? 'nxdomain';

  bool get serverDynamicBlockEnabled =>
      _boolIn(serverContainer, 'block_response_dynamic_enabled', false);

  int get serverDynamicBlockThreshold =>
      _intIn(serverContainer, 'block_response_dynamic_threshold', 5);

  int get serverDynamicBlockWindowSeconds =>
      _intIn(serverContainer, 'block_response_dynamic_window_seconds', 60);

  int get serverDynamicBlockNxDomainDurationSeconds => _intIn(
    serverContainer,
    'block_response_dynamic_nxdomain_duration_seconds',
    300,
  );

  void setServerLogQueries(bool value) =>
      _store.putBool(serverContainer, 'log_queries', value);

  // ----------------------------------------------------------------- helpers

  String? _string(String container, String key) {
    final value = _store.read(container, key);
    return value is String ? value : null;
  }

  String? _stringIn(String container, String key) => _string(container, key);

  bool _boolIn(String container, String key, bool fallback) {
    final value = _store.read(container, key);
    return value is bool ? value : fallback;
  }

  int _intIn(String container, String key, int fallback) {
    final value = _store.read(container, key);
    return value is int ? value : fallback;
  }

  bool _bool(String container, String key, bool fallback) {
    final value = _store.read(container, key);
    return value is bool ? value : fallback;
  }

  int _int(String container, String key, int fallback) {
    final value = _store.read(container, key);
    return value is int ? value : fallback;
  }

  /// Reads a JSON array of ids; the legacy stores fall back to the two default
  /// race providers for every resolution list when the value is missing or
  /// malformed.
  List<String> _idList(
    String key, {
    List<String> fallback = const ['preset_alidns_dns', 'preset_dnspod_dns'],
  }) {
    final raw = _string(dnsContainer, key);
    if (raw == null) return fallback;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return fallback;
      return [
        for (final item in decoded)
          if (item is String && item.isNotEmpty) item,
      ];
    } on FormatException {
      return fallback;
    }
  }

  double _double(String container, String key, double fallback) {
    final value = _store.read(container, key);
    return value is num ? value.toDouble() : fallback;
  }

  static double _clampedOpacity(double value) => value.clamp(0.1, 1.0);

  static int _clampedPort(int port) => port.clamp(1024, 65535);
}

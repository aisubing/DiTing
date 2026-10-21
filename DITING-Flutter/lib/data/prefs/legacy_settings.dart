/// Typed view over the preference keys documented in
/// `docs/refactor/01-foundation-and-startup-2.md` §3.1.
///
/// Keys, containers and defaults are copied from DITING 1.4.3 verbatim; the
/// `GOLD` palette still stores `indigo`, the server dataset is still called
/// `dns`, and absent values must fall back exactly as the old stores did.
library;

import 'dart:convert';

import 'package:diting/data/prefs/legacy_prefs_store.dart';

part 'legacy_settings_dns.dart';
part 'legacy_settings_hub.dart';
part 'legacy_settings_parity.dart';

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

  /// Notification-bar settings (`NotificationSettingsStore`).
  ///
  /// A container of its own: the foreground service reads this one, not
  /// `dns_vpn_prefs`. Writing notification keys anywhere else silently has no
  /// effect on the notification while still passing every UI test.
  static const notificationContainer = 'notification_settings_prefs';

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

  // ------------------------------------------------------- 订阅自动更新（键名）

  /// `SubscriptionAutoUpdateSettings.KEY_ENABLED`。
  static const subscriptionAutoUpdateEnabledKey =
      'subscription_auto_update_enabled';

  /// `SubscriptionAutoUpdateSettings.KEY_INTERVAL`。
  static const subscriptionAutoUpdateIntervalKey =
      'subscription_auto_update_interval_hours';

  /// `SubscriptionAutoUpdateSettings.DEFAULT_INTERVAL_HOURS`。
  static const defaultSubscriptionAutoUpdateIntervalHours = 24;

  /// `MIN_INTERVAL_HOURS` / `MAX_INTERVAL_HOURS`。
  static const minSubscriptionAutoUpdateIntervalHours = 1;
  static const maxSubscriptionAutoUpdateIntervalHours = 168;

  /// `SubscriptionAutoUpdateSettings.intervals`：预设档位（自定义档另算）。
  static const subscriptionAutoUpdatePresetHours = [6, 12, 24, 48];

  // ---------------------------------------------------------------- appearance

  String? get themeModeRaw => _string(uiContainer, 'app_theme_mode');

  void setThemeModeRaw(String storageValue) =>
      _store.putString(uiContainer, 'app_theme_mode', storageValue);

  String? get paletteRaw => _string(uiContainer, 'theme_color_style');

  void setPaletteRaw(String storageValue) =>
      _store.putString(uiContainer, 'theme_color_style', storageValue);

  // --------------------------------------------- appearance (Flutter-only)

  /// Liquid 玻璃档位（`none` / `standard` / `ultra`）。
  ///
  /// 1.4.3 没有这一项，所以键名是本仓新增的；仍放进 `dns_vpn_prefs`，与其余
  /// 外观键同容器，备份/恢复时天然一起走。
  ///
  /// **必须落盘**：这一档决定整个应用要不要走离屏合成（`LiquidGlassHost`
  /// 抓图 + 每个玻璃面折射）。只在内存里记的后果是——用户在设置里选了「极致」，
  /// 退出应用再进来就静默回到「关闭」，而设置项本身仍显示用户选过的值，
  /// 看起来像「玻璃被重置了」。（本轮真机复现：`18_ultra.png` 选完生效，
  /// 重启后 `19_home_ultra.png` 里浮条又变回实色白胶囊。）
  String get liquidGlassModeRaw =>
      _string(uiContainer, 'liquid_glass_mode') ?? 'none';

  void setLiquidGlassModeRaw(String storageValue) =>
      _store.putString(uiContainer, 'liquid_glass_mode', storageValue);

  /// 底栏形态（`floating` / `docked`）。理由同上。
  String get bottomBarStyleRaw =>
      _string(uiContainer, 'bottom_bar_style') ?? 'floating';

  void setBottomBarStyleRaw(String storageValue) =>
      _store.putString(uiContainer, 'bottom_bar_style', storageValue);

  /// tab 切换动画（`none` / `fade` / `slide` / `scale`）。理由同上。
  String get tabTransitionRaw =>
      _string(uiContainer, 'tab_transition') ?? 'slide';

  void setTabTransitionRaw(String storageValue) =>
      _store.putString(uiContainer, 'tab_transition', storageValue);

  double get componentOpacity =>
      _clampedOpacity(_double(uiContainer, 'home_component_opacity', 1));
  /// Per-element opacity falls back to the shared component opacity, exactly
  /// like `AppearanceSettingsStore.getHomeOpacity`.
  double homeOpacity(String storageKey) =>
      _clampedOpacity(_double(uiContainer, storageKey, componentOpacity));

  void setHomeOpacity(String storageKey, double value) =>
      _store.putFloat(uiContainer, storageKey, _clampedOpacity(value));

  ({String running, String stopped}) get homeSentences => (
    running:
        _string(uiContainer, 'home_sentence_running') ?? defaultRunningSentence,
    stopped:
        _string(uiContainer, 'home_sentence_stopped') ?? defaultStoppedSentence,
  );

  void setHomeSentences({required String running, required String stopped}) {
    _store.putString(uiContainer, 'home_sentence_running', running);
    _store.putString(uiContainer, 'home_sentence_stopped', stopped);
  }

  bool get hapticEnabled =>
      _bool(uiContainer, 'bottom_bar_haptic_enabled', true);

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
    _store.putString(
      uiContainer,
      'bottom_bar_destinations',
      jsonEncode(finalIds),
    );
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

  /// Raw value for keys that only the Go config builder consumes.
  Object? rawValue(String key) => _store.read(dnsContainer, key);

  // ------------------------------------------------------------ tunnel system
  bool get bypassLanEnabled => _bool(uiContainer, 'bypass_lan_enabled', true);

  String get ipv6ModeRaw => _string(dnsContainer, 'ipv6_mode') ?? 'auto';

  Set<String> get excludedPackages {
    final value = _store.read(uiContainer, 'excluded_app_packages');
    if (value is List) {
      return {
        for (final item in value)
          if (item is String && item.isNotEmpty) item,
      };
    }
    return const {};
  }

  /// Stored as a SharedPreferences string set (`putStringSet`), which the
  /// bridge serialises as a string array.
  void setExcludedPackages(Set<String> packages) =>
      _store.putStringSet(uiContainer, 'excluded_app_packages', {
        for (final item in packages)
          if (item.trim().isNotEmpty) item,
      });

  /// `app_allowlist_rules_json`: package -> allowed domains, the per-app rules
  /// behind `Engine.setAppAllowlist`. Stored as a JSON **object** (not a string
  /// set), so it needs its own decoder; a malformed blob must yield an empty map
  /// rather than throwing, otherwise one corrupt write bricks every tunnel start.
  ///
  /// Blank packages and this app's own id are dropped, exactly like
  /// `AppRulesSettingsStore.getAppAllowlistRuleMap`.
  Map<String, Set<String>> get appAllowlistRules {
    final raw = _string(uiContainer, 'app_allowlist_rules_json');
    if (raw == null || raw.trim().isEmpty) return const {};
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const {};
    }
    if (decoded is! Map) return const {};
    final result = <String, Set<String>>{};
    decoded.forEach((key, value) {
      if (key is! String || key.trim().isEmpty) return;
      if (value is! List) return;
      final domains = {
        for (final item in value)
          if (item is String && item.trim().isNotEmpty) item.trim(),
      };
      if (domains.isNotEmpty) result[key] = domains;
    });
    return result;
  }

  void setAppAllowlistRules(Map<String, Set<String>> rules) {
    final cleaned = <String, List<String>>{};
    rules.forEach((packageName, domains) {
      if (packageName.trim().isEmpty) return;
      final values = [
        for (final domain in domains)
          if (domain.trim().isNotEmpty) domain.trim(),
      ];
      if (values.isNotEmpty) cleaned[packageName] = values;
    });
    _store.putString(
      uiContainer,
      'app_allowlist_rules_json',
      jsonEncode(cleaned),
    );
  }

  bool get appAllowlistEnabled =>
      _bool(uiContainer, 'app_allowlist_enabled', false);

  void setAppAllowlistEnabled(bool value) =>
      _store.putBool(uiContainer, 'app_allowlist_enabled', value);

  /// `blocked_app_packages` + `blocked_apps_enabled`; the app itself is always
  /// stripped, exactly like `AppRulesSettingsStore.getBlockedAppPackages`.
  Set<String> get blockedAppPackages =>
      _stringSet('blocked_app_packages', container: uiContainer) ?? const {};
  bool get blockedAppsEnabled =>
      _bool(uiContainer, 'blocked_apps_enabled', false);

  void setBlockedApps({required Set<String> packages, required bool enabled}) {
    _store.putStringSet(uiContainer, 'blocked_app_packages', {
      for (final item in packages)
        if (item.trim().isNotEmpty) item,
    });
    _store.putBool(uiContainer, 'blocked_apps_enabled', enabled);
  }

  /// `http_inspection_app_packages` + `http_inspection_enabled`.
  Set<String> get httpInspectionPackages =>
      _stringSet('http_inspection_app_packages', container: uiContainer) ??
      const {};

  bool get httpInspectionEnabled =>
      _bool(uiContainer, 'http_inspection_enabled', false);

  /// `https_inspection_ready` + `https_inspection_ca_backend`. 1.4.3's
  /// `isHttpsInspectionReady` requires BOTH: the boolean alone can survive a
  /// CA reset, so the backend marker is what proves the current engine wrote
  /// the certificate the trust store now holds.
  bool get httpsInspectionReady =>
      _bool(uiContainer, 'https_inspection_ready', false) &&
      _string(uiContainer, 'https_inspection_ca_backend') == 'go-v1';

  void setHttpsInspectionReady(bool ready) {
    _store.putBool(uiContainer, 'https_inspection_ready', ready);
    _store.putString(
      uiContainer,
      'https_inspection_ca_backend',
      ready ? 'go-v1' : '',
    );
  }

  /// `isHttpsInspectionOperational`: ready AND enabled AND at least one app
  /// selected. MITM with an empty app list inspects nothing, so treating it as
  /// "operational" would let the engine start a CA-less interception path.
  bool get httpsInspectionOperational =>
      httpsInspectionReady &&
      httpInspectionEnabled &&
      httpInspectionPackages.isNotEmpty;

  void setHttpInspectionApps({
    required Set<String> packages,
    required bool enabled,
  }) {
    _store.putStringSet(uiContainer, 'http_inspection_app_packages', {
      for (final item in packages)
        if (item.trim().isNotEmpty) item,
    });
    _store.putBool(uiContainer, 'http_inspection_enabled', enabled);
  }

  // ----------------------------------------------------------- server mode

  int get serverPort => _clampedPort(
    _int(serverContainer, 'local_listen_port', defaultServerPort),
  );

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

  bool get serverLogQueries => _boolIn(serverContainer, 'log_queries', false);

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

  /// Reads a JSON array string; also accepts the list form the bridge returns
  /// for `putStringSet` values.
  Set<String>? _stringSet(String key, {String? container}) {
    final value = _store.read(container ?? dnsContainer, key);
    if (value is List) {
      return {
        for (final item in value)
          if (item is String && item.isNotEmpty) item,
      };
    }
    if (value is! String) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return null;
      return {
        for (final item in decoded)
          if (item is String && item.isNotEmpty) item,
      };
    } on FormatException {
      return null;
    }
  }

  /// Sorted JSON array, matching `writeStringSet`'s output byte for byte.
  static String _encodeSet(Set<String> values) =>
      jsonEncode(values.toList()..sort());

  static int _clampSeconds(int seconds) => seconds.clamp(30, 86400);

  static double _clampedOpacity(double value) => value.clamp(0.1, 1.0);

  static int _clampedPort(int port) => port.clamp(1024, 65535);
}

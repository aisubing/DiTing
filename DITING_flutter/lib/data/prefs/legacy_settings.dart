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
  LegacySettings(this._store);

  final LegacyPrefsStore _store;

  /// Global UI keys (`SettingsPreferencesExtensions.PREFS_NAME`).
  static const uiContainer = 'dns_vpn_prefs';

  /// Work-mode selection (`WorkModeStore`).
  static const workModeContainer = 'diting_settings';

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

  /// Normal dataset's resolution mode (the dataset-aware key lives in the
  /// same container as the global UI keys).
  String get resolutionModeRaw =>
      _string(uiContainer, 'dns_resolution_mode') ?? 'single';

  void setResolutionModeRaw(String storageValue) =>
      _store.putString(uiContainer, 'dns_resolution_mode', storageValue);

  // ----------------------------------------------------------- server mode

  int get serverPort =>
      _clampedPort(_int(serverContainer, 'local_listen_port', defaultServerPort));

  void setServerPort(int port) =>
      _store.putInt(serverContainer, 'local_listen_port', _clampedPort(port));

  void setServerLogQueries(bool value) =>
      _store.putBool(serverContainer, 'log_queries', value);

  // ----------------------------------------------------------------- helpers

  String? _string(String container, String key) {
    final value = _store.read(container, key);
    return value is String ? value : null;
  }

  bool _bool(String container, String key, bool fallback) {
    final value = _store.read(container, key);
    return value is bool ? value : fallback;
  }

  int _int(String container, String key, int fallback) {
    final value = _store.read(container, key);
    return value is int ? value : fallback;
  }

  double _double(String container, String key, double fallback) {
    final value = _store.read(container, key);
    return value is num ? value.toDouble() : fallback;
  }

  static double _clampedOpacity(double value) => value.clamp(0.1, 1.0);

  static int _clampedPort(int port) => port.clamp(1024, 65535);
}

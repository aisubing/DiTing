/// Appearance state: theme, palette, text scale, opacity, home text and bottom bar, under the 1.4.3
/// keys.
library;

import 'package:diting/app/theme/colors.dart';
import 'package:diting/app/theme/layout.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/ui/icons/icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

LegacySettings _settings(Ref ref) => ref.read(legacySettingsProvider);

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() =>
      AppThemeMode.fromStorageValue(_settings(ref).themeModeRaw);

  void select(AppThemeMode mode) {
    state = mode;
    _settings(ref).setThemeModeRaw(mode.storageValue);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);

class PaletteNotifier extends Notifier<AppPalette> {
  @override
  AppPalette build() => AppPalette.fromStorageValue(_settings(ref).paletteRaw);

  void select(AppPalette palette) {
    state = palette;
    _settings(ref).setPaletteRaw(palette.storageValue);
  }
}

final paletteProvider = NotifierProvider<PaletteNotifier, AppPalette>(
  PaletteNotifier.new,
);

class PureBlackNotifier extends Notifier<bool> {
  @override
  bool build() => _settings(ref).pureBlackEnabled;

  void toggle(bool value) {
    state = value;
    _settings(ref).setPureBlackEnabled(value);
  }
}

final pureBlackProvider = NotifierProvider<PureBlackNotifier, bool>(
  PureBlackNotifier.new,
);

/// Raw user text scale, before [clampTextScale].
class TextScaleNotifier extends Notifier<double> {
  @override
  double build() => clampTextScale(_settings(ref).textScale);

  void set(double value) {
    state = clampTextScale(value);
    _settings(ref).setTextScale(state);
  }
}

final textScaleProvider = NotifierProvider<TextScaleNotifier, double>(
  TextScaleNotifier.new,
);

/// Opacity of the five home widgets (`home_*_opacity`); keep `dnsDetail` in step with its widget.
enum HomeLayer {
  powerButton('启动按钮', 'home_power_button_opacity'),
  providerSelector('解析服务选择框', 'home_provider_selector_opacity'),
  modeButton('模式切换按钮', 'home_mode_button_opacity'),
  poem('首页古诗', 'home_poem_opacity'),
  dnsDetail('DNS 服务详情', 'home_dns_detail_opacity');

  const HomeLayer(this.label, this.storageKey);

  final String label;

  /// Legacy `AppearanceSettingsStore` key names.
  final String storageKey;
}

class HomeOpacityNotifier extends Notifier<Map<HomeLayer, double>> {
  static const _defaults = {
    HomeLayer.powerButton: 1.0,
    HomeLayer.providerSelector: 1.0,
    HomeLayer.modeButton: 1.0,
    HomeLayer.poem: 1.0,
    HomeLayer.dnsDetail: 1.0,
  };

  @override
  Map<HomeLayer, double> build() {
    final settings = _settings(ref);
    return {
      for (final layer in HomeLayer.values)
        layer: settings.homeOpacity(layer.storageKey),
    };
  }

  void set(HomeLayer layer, double value) {
    final clamped = value.clamp(0.1, 1.0);
    state = {...state, layer: clamped};
    _settings(ref).setHomeOpacity(layer.storageKey, clamped);
  }

  void resetAll() {
    state = _defaults;
    final settings = _settings(ref);
    for (final layer in HomeLayer.values) {
      settings.setHomeOpacity(layer.storageKey, 1);
    }
  }
}

final homeOpacityProvider =
    NotifierProvider<HomeOpacityNotifier, Map<HomeLayer, double>>(
      HomeOpacityNotifier.new,
    );

/// Home sentence per run state (running / stopped); empty hides it.
class HomeSentenceNotifier
    extends Notifier<({String running, String stopped})> {
  @override
  ({String running, String stopped}) build() => _settings(ref).homeSentences;

  void set({String? running, String? stopped}) {
    state = (
      running: running ?? state.running,
      stopped: stopped ?? state.stopped,
    );
    _settings(ref)
        .setHomeSentences(running: state.running, stopped: state.stopped);
  }

  void reset() {
    state = (
      running: LegacySettings.defaultRunningSentence,
      stopped: LegacySettings.defaultStoppedSentence,
    );
    _settings(ref)
        .setHomeSentences(running: state.running, stopped: state.stopped);
  }
}

final homeSentenceProvider =
    NotifierProvider<HomeSentenceNotifier, ({String running, String stopped})>(
      HomeSentenceNotifier.new,
    );

/// Selectable bottom bar tabs: 2 to [maxDockDestinations].
enum BottomBarDestination {
  home('首页', 'home', AppGlyphs.dashboard),
  featureHub('功能中心', 'feature_hub', AppGlyphs.puzzle),
  logDashboard('日志仪表盘', 'log_dashboard', AppGlyphs.logs),
  appTraffic('应用流量', 'app_traffic_stats', AppGlyphs.dataUsage),
  networkTools('网络工具', 'network_tools', AppGlyphs.tools),
  settings('设置', 'settings', AppGlyphs.settings);

  const BottomBarDestination(this.label, this.storageValue, this.glyph);

  final String label;

  /// Ids as stored in the legacy `bottom_bar_destinations` array.
  final String storageValue;

  final Glyph glyph;

  static BottomBarDestination? fromStorageValue(String value) {
    for (final destination in values) {
      if (destination.storageValue == value) {
        return destination;
      }
    }
    return null;
  }
}

class BottomBarNotifier extends Notifier<List<BottomBarDestination>> {
  static const _defaults = [
    BottomBarDestination.home,
    BottomBarDestination.featureHub,
    BottomBarDestination.logDashboard,
  ];

  @override
  List<BottomBarDestination> build() {
    final restored = [
      for (final id in _settings(ref).bottomBarIds)
        ?BottomBarDestination.fromStorageValue(id),
    ];
    return restored.length < 2 ? _defaults : restored;
  }

  void _save(List<BottomBarDestination> destinations) {
    _settings(ref).setBottomBarIds([
      for (final destination in destinations) destination.storageValue,
    ]);
  }

  /// Keeps 2 to [maxDockDestinations] items; out-of-range edits are ignored.
  bool toggle(BottomBarDestination destination) {
    final current = state;
    if (current.contains(destination)) {
      if (current.length <= 2) {
        return false;
      }
      state = [...current]..remove(destination);
      _save(state);
      return true;
    }
    if (current.length >= maxDockDestinations) {
      return false;
    }
    state = [...current, destination];
    _save(state);
    return true;
  }

  void reset() {
    state = _defaults;
    _save(_defaults);
  }
}

final bottomBarProvider =
    NotifierProvider<BottomBarNotifier, List<BottomBarDestination>>(
      BottomBarNotifier.new,
    );

class HapticNotifier extends Notifier<bool> {
  @override
  bool build() => _settings(ref).hapticEnabled;

  void toggle(bool value) {
    state = value;
    _settings(ref).setHapticEnabled(value);
  }
}

final hapticProvider = NotifierProvider<HapticNotifier, bool>(
  HapticNotifier.new,
);

/// Resolution mode: single resolver or race (upstream `ResolutionSettingsStore`).
enum ResolutionMode {
  single('单服务商', 'single'),
  smart('智能选择', 'smart_prediction'),
  parallel('并行竞速', 'parallel_race'),
  primaryBackup('主备切换', 'primary_backup');

  const ResolutionMode(this.label, this.storageValue);

  final String label;

  /// Legacy `dns_resolution_mode` values; enum names differ from stored values.
  final String storageValue;

  bool get isSingle => this == single;

  static ResolutionMode fromStorageValue(String? value) => values.firstWhere(
    (mode) => mode.storageValue == value,
    orElse: () => single,
  );
}

class ResolutionModeNotifier extends Notifier<ResolutionMode> {
  @override
  ResolutionMode build() =>
      ResolutionMode.fromStorageValue(_settings(ref).resolutionModeRaw);

  void select(ResolutionMode mode) {
    state = mode;
    _settings(ref).setResolutionModeRaw(mode.storageValue);
  }
}

final resolutionModeProvider =
    NotifierProvider<ResolutionModeNotifier, ResolutionMode>(
      ResolutionModeNotifier.new,
    );

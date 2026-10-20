/// 演示用状态：外观（主题 / 色板 / 字号 / 透明度 / 首页句子 / 底栏）。
///
/// 主题、色板、首页透明度/句子、底栏与触感直接读写旧版 `dns_vpn_prefs`
/// 的同名键，保证 1.4.3 用户升级后设置原样保留；其余（纯黑、字号）是
/// Flutter 版新增项，暂不落盘。
library;

import 'package:diting/app/theme/colors.dart';
import 'package:diting/app/theme/layout.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/ui/icons/icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

LegacySettings _settings(Ref ref) => ref.read(legacySettingsProvider);

/// 日夜模式。
class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() =>
      AppThemeMode.fromStorageValue(_settings(ref).themeModeRaw);

  void select(AppThemeMode mode) {
    state = mode;
    _settings(ref).setThemeModeRaw(mode.storageValue);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);

/// 主题色九选一。
class PaletteNotifier extends Notifier<AppPalette> {
  @override
  AppPalette build() =>
      AppPalette.fromStorageValue(_settings(ref).paletteRaw);

  void select(AppPalette palette) {
    state = palette;
    _settings(ref).setPaletteRaw(palette.storageValue);
  }
}

final paletteProvider =
    NotifierProvider<PaletteNotifier, AppPalette>(PaletteNotifier.new);

/// 纯黑（仅深色模式生效）。
class PureBlackNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle(bool value) => state = value;
}

final pureBlackProvider =
    NotifierProvider<PureBlackNotifier, bool>(PureBlackNotifier.new);

/// 用户选的文本缩放，进 [clampTextScale] 前是原始值。
class TextScaleNotifier extends Notifier<double> {
  @override
  double build() => 1;

  void set(double value) => state = clampTextScale(value);
}

final textScaleProvider =
    NotifierProvider<TextScaleNotifier, double>(TextScaleNotifier.new);

/// 首页四类元素的透明度（`home_*_opacity`，0.1–1.0）。
enum HomeLayer {
  powerButton('电源按钮', 'home_power_button_opacity'),
  providerSelector('服务商选择', 'home_provider_selector_opacity'),
  modeButton('模式按钮', 'home_mode_button_opacity'),
  poem('首页句子', 'home_poem_opacity');

  const HomeLayer(this.label, this.storageKey);

  final String label;

  /// 旧版 `AppearanceSettingsStore` 的键名。
  final String storageKey;
}

class HomeOpacityNotifier extends Notifier<Map<HomeLayer, double>> {
  static const _defaults = {
    HomeLayer.powerButton: 1.0,
    HomeLayer.providerSelector: 1.0,
    HomeLayer.modeButton: 1.0,
    HomeLayer.poem: 1.0,
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

/// 首页句子：运行 / 停止两态各一条，留空即不显示。
class HomeSentenceNotifier extends Notifier<({String running, String stopped})> {
  @override
  ({String running, String stopped}) build() => _settings(ref).homeSentences;

  void set({String? running, String? stopped}) {
    state = (
      running: running ?? state.running,
      stopped: stopped ?? state.stopped,
    );
    _settings(ref).setHomeSentences(
      running: state.running,
      stopped: state.stopped,
    );
  }

  void reset() {
    state = (
      running: LegacySettings.defaultRunningSentence,
      stopped: LegacySettings.defaultStoppedSentence,
    );
    _settings(ref).setHomeSentences(
      running: state.running,
      stopped: state.stopped,
    );
  }
}

final homeSentenceProvider =
    NotifierProvider<HomeSentenceNotifier, ({String running, String stopped})>(
      HomeSentenceNotifier.new,
    );

/// 底栏可选项。上游 6 选 2–4；这里允许 2–[maxDockDestinations]。
enum BottomBarDestination {
  home('首页', 'home', AppGlyphs.dashboard),
  featureHub('功能中心', 'feature_hub', AppGlyphs.puzzle),
  logDashboard('日志仪表盘', 'log_dashboard', AppGlyphs.logs),
  appTraffic('应用流量', 'app_traffic_stats', AppGlyphs.dataUsage),
  networkTools('网络工具', 'network_tools', AppGlyphs.tools),
  settings('设置', 'settings', AppGlyphs.settings);

  const BottomBarDestination(this.label, this.storageValue, this.glyph);

  final String label;

  /// 旧版 `bottom_bar_destinations` 数组里的 id。
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
    _settings(ref).setBottomBarIds(
      [for (final destination in destinations) destination.storageValue],
    );
  }

  /// 至少留 2 项，最多 [maxDockDestinations] 项；越界的操作被忽略。
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

/// 底栏触感反馈开关。
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

/// 解析模式：单服务商 / 多路竞速（上游 `ResolutionSettingsStore`）。
enum ResolutionMode {
  single('单服务商', 'single'),
  smart('智能选择', 'smart_prediction'),
  parallel('并行竞速', 'parallel_race'),
  primaryBackup('主备切换', 'primary_backup');

  const ResolutionMode(this.label, this.storageValue);

  final String label;

  /// 旧版 `dns_resolution_mode` 的落盘值；枚举名与落盘值并不同名。
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

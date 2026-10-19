/// 演示用状态：外观（主题 / 色板 / 字号 / 透明度 / 首页句子 / 底栏）。
///
/// 全部是纯内存状态，不落盘——本阶段是 UI 演示，没有业务持久化。
/// 每个 Notifier 只改自己的一小块，页面通过 `ref.watch` 精确订阅，
/// 避免改一个滑杆就重建整棵树。
library;

import 'package:diting/app/theme/colors.dart';
import 'package:diting/app/theme/layout.dart';
import 'package:diting/ui/icons/icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 日夜模式。
class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => AppThemeMode.system;

  void select(AppThemeMode mode) => state = mode;
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);

/// 主题色九选一。
class PaletteNotifier extends Notifier<AppPalette> {
  @override
  AppPalette build() => AppPalette.blue;

  void select(AppPalette palette) => state = palette;
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
  powerButton('电源按钮'),
  providerSelector('服务商选择'),
  modeButton('模式按钮'),
  poem('首页句子');

  const HomeLayer(this.label);

  final String label;
}

class HomeOpacityNotifier extends Notifier<Map<HomeLayer, double>> {
  static const _defaults = {
    HomeLayer.powerButton: 1.0,
    HomeLayer.providerSelector: 1.0,
    HomeLayer.modeButton: 1.0,
    HomeLayer.poem: 1.0,
  };

  @override
  Map<HomeLayer, double> build() => _defaults;

  void set(HomeLayer layer, double value) {
    state = {...state, layer: value.clamp(0.1, 1.0)};
  }

  void resetAll() => state = _defaults;
}

final homeOpacityProvider =
    NotifierProvider<HomeOpacityNotifier, Map<HomeLayer, double>>(
      HomeOpacityNotifier.new,
    );

/// 首页句子：运行 / 停止两态各一条，留空即不显示。
class HomeSentenceNotifier extends Notifier<({String running, String stopped})> {
  @override
  ({String running, String stopped}) build() => (
    running: '谛听万象，明察清浊',
    stopped: '收耳静眠，归于无声',
  );

  void set({String? running, String? stopped}) {
    state = (
      running: running ?? state.running,
      stopped: stopped ?? state.stopped,
    );
  }

  void reset() => state = build();
}

final homeSentenceProvider =
    NotifierProvider<HomeSentenceNotifier, ({String running, String stopped})>(
      HomeSentenceNotifier.new,
    );

/// 底栏可选项。上游 6 选 2–4；这里允许 2–[maxDockDestinations]。
enum BottomBarDestination {
  home('首页', AppGlyphs.dashboard),
  featureHub('功能中心', AppGlyphs.puzzle),
  logDashboard('日志仪表盘', AppGlyphs.logs),
  appTraffic('应用流量', AppGlyphs.dataUsage),
  networkTools('网络工具', AppGlyphs.tools),
  settings('设置', AppGlyphs.settings);

  const BottomBarDestination(this.label, this.glyph);

  final String label;
  final Glyph glyph;
}

class BottomBarNotifier extends Notifier<List<BottomBarDestination>> {
  static const _defaults = [
    BottomBarDestination.home,
    BottomBarDestination.featureHub,
    BottomBarDestination.logDashboard,
  ];

  @override
  List<BottomBarDestination> build() => _defaults;

  /// 至少留 2 项，最多 [maxDockDestinations] 项；越界的操作被忽略。
  bool toggle(BottomBarDestination destination) {
    final current = state;
    if (current.contains(destination)) {
      if (current.length <= 2) {
        return false;
      }
      state = [...current]..remove(destination);
      return true;
    }
    if (current.length >= maxDockDestinations) {
      return false;
    }
    state = [...current, destination];
    return true;
  }

  void reset() => state = _defaults;
}

final bottomBarProvider =
    NotifierProvider<BottomBarNotifier, List<BottomBarDestination>>(
      BottomBarNotifier.new,
    );

/// 底栏触感反馈开关。
class HapticNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle(bool value) => state = value;
}

final hapticProvider = NotifierProvider<HapticNotifier, bool>(
  HapticNotifier.new,
);

/// 解析模式：单服务商 / 多路竞速（上游 `ResolutionSettingsStore`）。
enum ResolutionMode {
  single('单服务商'),
  smart('智能选择'),
  parallel('并行竞速'),
  primaryBackup('主备切换');

  const ResolutionMode(this.label);

  final String label;

  bool get isSingle => this == single;
}

class ResolutionModeNotifier extends Notifier<ResolutionMode> {
  @override
  ResolutionMode build() => ResolutionMode.single;

  void select(ResolutionMode mode) => state = mode;
}

final resolutionModeProvider =
    NotifierProvider<ResolutionModeNotifier, ResolutionMode>(
      ResolutionModeNotifier.new,
    );

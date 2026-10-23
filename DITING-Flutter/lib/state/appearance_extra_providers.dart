/// Bottom bar style, tab transition and liquid glass: in memory only, so they reset on restart.
library;

import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

LegacySettings _settings(Ref ref) => ref.read(legacySettingsProvider);

/// Bottom bar look; [BottomBarDestination] decides which tabs exist, not how they are drawn.
enum BottomBarStyle {
  floating('浮条'),
  docked('普通');

  const BottomBarStyle(this.label);

  final String label;

  bool get isFloating => this == floating;

  static BottomBarStyle fromStorageValue(String? raw) =>
      values.firstWhere((v) => v.name == raw, orElse: () => floating);
}

class BottomBarStyleNotifier extends Notifier<BottomBarStyle> {
  @override
  BottomBarStyle build() =>
      BottomBarStyle.fromStorageValue(_settings(ref).bottomBarStyleRaw);

  void select(BottomBarStyle style) {
    state = style;
    _settings(ref).setBottomBarStyleRaw(style.name);
  }
}

final bottomBarStyleProvider =
    NotifierProvider<BottomBarStyleNotifier, BottomBarStyle>(
      BottomBarStyleNotifier.new,
    );

/// Tab switch animation; `none` and `scale` extend the upstream slide/fade so all four can be
/// previewed.
enum TabTransition {
  none('无'),
  fade('淡入'),
  slide('滑动'),
  scale('缩放');

  const TabTransition(this.label);

  final String label;

  static TabTransition fromStorageValue(String? raw) =>
      values.firstWhere((v) => v.name == raw, orElse: () => slide);
}

class TabTransitionNotifier extends Notifier<TabTransition> {
  @override
  TabTransition build() =>
      TabTransition.fromStorageValue(_settings(ref).tabTransitionRaw);

  void select(TabTransition transition) {
    state = transition;
    _settings(ref).setTabTransitionRaw(transition.name);
  }
}

final tabTransitionProvider =
    NotifierProvider<TabTransitionNotifier, TabTransition>(
      TabTransitionNotifier.new,
    );

/// Liquid glass: off / standard / ultra (quality tiers live in `lib/ui/liquid_glass.dart`).
enum LiquidGlassMode {
  none('关闭'),
  standard('标准'),
  ultra('极致');

  const LiquidGlassMode(this.label);

  final String label;

  bool get enabled => this != none;

  LiquidGlassQuality get quality =>
      this == ultra ? LiquidGlassQuality.ultra : LiquidGlassQuality.standard;

  static LiquidGlassMode fromStorageValue(String? raw) =>
      values.firstWhere((v) => v.name == raw, orElse: () => none);
}

class LiquidGlassModeNotifier extends Notifier<LiquidGlassMode> {
  @override
  LiquidGlassMode build() =>
      LiquidGlassMode.fromStorageValue(_settings(ref).liquidGlassModeRaw);

  void select(LiquidGlassMode mode) {
    state = mode;
    _settings(ref).setLiquidGlassModeRaw(mode.name);
  }
}

final liquidGlassModeProvider =
    NotifierProvider<LiquidGlassModeNotifier, LiquidGlassMode>(
      LiquidGlassModeNotifier.new,
    );

/// Selected font family; null means the system default. Persisted, and applied app-wide in
/// `lib/app/theme/manager.dart`.
class FontFamilyNotifier extends Notifier<String?> {
  @override
  String? build() => _settings(ref).fontFamily;

  void select(String? family) {
    state = family;
    _settings(ref).setFontFamily(family);
  }
}

final selectedFontFamilyProvider =
    NotifierProvider<FontFamilyNotifier, String?>(FontFamilyNotifier.new);

/// Brightness the theme preview page compares: light / dark.
enum PreviewBrightness {
  light('浅色', Brightness.light),
  dark('深色', Brightness.dark);

  const PreviewBrightness(this.label, this.brightness);

  final String label;
  final Brightness brightness;
}

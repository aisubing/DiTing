/// 演示用状态：主题页里上游有、但 `appearance_providers.dart` 尚未覆盖的几项。
///
/// `appearance_providers.dart` 被设置页与多个页面共用，并行期不在这里改它；
/// 本轮新增的开关（底栏形态 / tab 动画 / Liquid 玻璃 / 字体族 / 自定义主色）
/// 单独成一份，页面只订阅自己需要的那一小块。
library;

import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 底栏形态：浮条（`NavigationDock`）或普通底栏（`NavigationBar` 形态）。
///
/// 与 `appearance_providers.dart` 的 [BottomBarDestination] 是两件事：那一份
/// 决定「底栏有哪几个 tab」，这一份决定「底栏长什么样」。
enum BottomBarStyle {
  floating('浮条'),
  docked('普通');

  const BottomBarStyle(this.label);

  final String label;

  bool get isFloating => this == floating;
}

class BottomBarStyleNotifier extends Notifier<BottomBarStyle> {
  @override
  BottomBarStyle build() => BottomBarStyle.floating;

  void select(BottomBarStyle style) => state = style;
}

final bottomBarStyleProvider =
    NotifierProvider<BottomBarStyleNotifier, BottomBarStyle>(
      BottomBarStyleNotifier.new,
    );

/// tab 切换动画。
///
/// 上游只有滑动与淡入；这里补上「无」和「缩放」，四种都能在缩略图里预览，
/// 否则用户只能靠文字猜「缩放」到底缩的是页面还是 tab 图标。
enum TabTransition {
  none('无'),
  fade('淡入'),
  slide('滑动'),
  scale('缩放');

  const TabTransition(this.label);

  final String label;
}

class TabTransitionNotifier extends Notifier<TabTransition> {
  @override
  TabTransition build() => TabTransition.slide;

  void select(TabTransition transition) => state = transition;
}

final tabTransitionProvider =
    NotifierProvider<TabTransitionNotifier, TabTransition>(
      TabTransitionNotifier.new,
    );

/// Liquid 玻璃：关闭 / 标准 / 极致（质量档位见 `lib/ui/liquid_glass.dart`）。
enum LiquidGlassMode {
  none('关闭'),
  standard('标准'),
  ultra('极致');

  const LiquidGlassMode(this.label);

  final String label;

  bool get enabled => this != none;

  LiquidGlassQuality get quality =>
      this == ultra ? LiquidGlassQuality.ultra : LiquidGlassQuality.standard;
}

class LiquidGlassModeNotifier extends Notifier<LiquidGlassMode> {
  @override
  LiquidGlassMode build() => LiquidGlassMode.none;

  void select(LiquidGlassMode mode) => state = mode;
}

final liquidGlassModeProvider =
    NotifierProvider<LiquidGlassModeNotifier, LiquidGlassMode>(
      LiquidGlassModeNotifier.new,
    );

/// 选中的字体族；`null` 表示用系统默认字体。
class FontFamilyNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? family) => state = family;
}

final selectedFontFamilyProvider =
    NotifierProvider<FontFamilyNotifier, String?>(FontFamilyNotifier.new);

/// 自定义主色（取色浮层确认后落在这里）。
///
/// `appearance_providers.dart` 的九色板是 `AppPalette` 枚举，装不下任意颜色，
/// 所以自定义色只影响本页与主题预览页里由 `seededColorScheme` 推导出来的
/// 预览色板；应用级 `ThemeData` 仍只跟随九色板。这是演示层的有意简化。
class CustomPrimaryColorNotifier extends Notifier<Color?> {
  @override
  Color? build() => null;

  void select(Color color) => state = color;

  void clear() => state = null;
}

final customPrimaryColorProvider =
    NotifierProvider<CustomPrimaryColorNotifier, Color?>(
      CustomPrimaryColorNotifier.new,
    );

/// 主题预览页要对比的几个对象：日间 / 夜间 / 当前自定义色。
enum PreviewBrightness {
  light('浅色', Brightness.light),
  dark('深色', Brightness.dark);

  const PreviewBrightness(this.label, this.brightness);

  final String label;
  final Brightness brightness;
}

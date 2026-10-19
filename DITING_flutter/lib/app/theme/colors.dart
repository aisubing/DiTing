import 'package:material_ui/material_ui.dart';

/// 默认种子色：Apple 系统蓝。`seededColorScheme` 只把它当种子，最终色板由
/// HCT 推导，因此这里改值不会破坏任何组件的对比度假设。
const defaultPrimaryColor = Color(0xFF007AFF);

/// 设置页「主题色」的九选一（`docs/refactor/03-navigation-and-main-ui.md` §5.2）。
///
/// `system` 表示跟随系统动态取色，在纯 UI 演示里退化为 [defaultPrimaryColor]；
/// 其余八项是 Apple 系统色。上游枚举名与 storageValue 有一处历史错位
/// （`GOLD` 的 storageValue 是 `indigo`），演示层直接按语义命名为 [gold]。
enum AppPalette {
  system('跟随系统', null),
  purple('鸢尾紫', Color(0xFFAF52DE)),
  blue('睡莲蓝', Color(0xFF007AFF)),
  cyan('池水青', Color(0xFF32ADE6)),
  green('柳叶绿', Color(0xFF34C759)),
  orange('暮光赭', Color(0xFFFF9500)),
  red('罂粟红', Color(0xFFFF3B30)),
  pink('暮霞粉', Color(0xFFFF2D55)),
  gold('麦穗金', Color(0xFFD4A017));

  const AppPalette(this.label, this.seed);

  /// 设置页显示名。
  final String label;

  /// 种子色；`null` 表示跟随系统。
  final Color? seed;

  /// 实际用于 `seededColorScheme` 的种子色。
  Color get effectiveSeed => seed ?? defaultPrimaryColor;

  /// 色板圆点用色；`system` 需要一个可见颜色，取默认蓝。
  Color get swatch => seed ?? defaultPrimaryColor;

  static AppPalette fromSeed(Color color) {
    for (final palette in values) {
      if (palette.seed == color) {
        return palette;
      }
    }
    return system;
  }
}

/// 日夜模式三选一（上游 `app_theme_mode`）。
enum AppThemeMode {
  system('跟随系统'),
  light('浅色模式'),
  dark('深色模式');

  const AppThemeMode(this.label);

  final String label;
}

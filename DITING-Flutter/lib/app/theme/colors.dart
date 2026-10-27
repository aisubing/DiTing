import 'package:material_ui/material_ui.dart';

/// Default seed colour: Apple system blue. `seededColorScheme` derives the final
/// palette from HCT, so changing this cannot break contrast assumptions.
const defaultPrimaryColor = Color(0xFF007AFF);

/// The nine palette choices on the settings page. `system` follows platform dynamic colour and
/// falls back to [defaultPrimaryColor]. `gold` keeps the legacy storage value `indigo`.
enum AppPalette {
  system('跟随系统', 'system', null),
  purple('鸢尾紫', 'purple', Color(0xFFAF52DE)),
  blue('睡莲蓝', 'blue', Color(0xFF007AFF)),
  cyan('池水青', 'cyan', Color(0xFF32ADE6)),
  green('柳叶绿', 'green', Color(0xFF34C759)),
  orange('暮光赭', 'orange', Color(0xFFFF9500)),
  red('罂粟红', 'red', Color(0xFFFF3B30)),
  pink('暮霞粉', 'pink', Color(0xFFFF2D55)),
  gold('麦穗金', 'indigo', Color(0xFFD4A017));

  const AppPalette(this.label, this.storageValue, this.seed);

  /// Display name.
  final String label;

  /// Legacy `theme_color_style` value; `gold` keeps `indigo`, do not change.
  final String storageValue;

  /// Seed colour; `null` follows the system.
  final Color? seed;

  static AppPalette fromStorageValue(String? value) => values.firstWhere(
    (palette) => palette.storageValue == value,
    orElse: () => system,
  );

  /// Seed actually passed to `seededColorScheme`.
  Color get effectiveSeed => seed ?? defaultPrimaryColor;

  /// Colour used for the palette swatch; `system` needs a visible one.
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

/// Light/dark/system choice (legacy `app_theme_mode`).
enum AppThemeMode {
  system('跟随系统', 'system'),
  light('浅色模式', 'light'),
  dark('深色模式', 'dark');

  const AppThemeMode(this.label, this.storageValue);

  final String label;

  /// Legacy `app_theme_mode` value.
  final String storageValue;

  static AppThemeMode fromStorageValue(String? value) => values.firstWhere(
    (mode) => mode.storageValue == value,
    orElse: () => system,
  );
}

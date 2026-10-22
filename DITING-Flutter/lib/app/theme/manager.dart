import 'package:diting/ui/ui.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';

/// The inputs a theme is assembled from. Two states with equal [AppThemeSpec]s
/// must produce the same [ThemeData], which is what lets [AppThemeCache] skip a
/// rebuild.
@immutable
class AppThemeSpec {
  const AppThemeSpec({
    required this.seedColor,
    required this.brightness,
    this.pureBlack = false,
    this.style = ColorStyle.vivid,
    this.transparentPage = false,
  });

  final Color seedColor;
  final Brightness brightness;
  final bool pureBlack;
  final ColorStyle style;

  /// 开启自定义背景时把页面底色设为透明，让根部的壁纸层透出来
  /// （1.4.3 `DITINGTheme(transparentBackground)` 同义）。
  final bool transparentPage;

  /// Only used by the settings previews; the app itself always builds both
  /// specs from an [AppThemePair].
  AppThemeSpec copyWith({
    Color? seedColor,
    Brightness? brightness,
    bool? pureBlack,
    ColorStyle? style,
    bool? transparentPage,
  }) => AppThemeSpec(
    seedColor: seedColor ?? this.seedColor,
    brightness: brightness ?? this.brightness,
    pureBlack: pureBlack ?? this.pureBlack,
    style: style ?? this.style,
    transparentPage: transparentPage ?? this.transparentPage,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppThemeSpec &&
          other.seedColor == seedColor &&
          other.brightness == brightness &&
          other.pureBlack == pureBlack &&
          other.style == style &&
          other.transparentPage == transparentPage;

  @override
  int get hashCode =>
      Object.hash(seedColor, brightness, pureBlack, style, transparentPage);
}

/// Builds the app theme exactly as upstream `lib/manager/theme_manager.dart`
/// does, in the same order:
///
/// 1. seed → `seededColorScheme`;
/// 2. `.toPureBlack` on the scheme (dark only);
/// 3. `elevated` colour scheme as a [ThemeExtension] when dark;
/// 4. `.withAppShapes` → `.withAppSurfaces` → `.withAppTypography`.
///
/// The order is load-bearing: `withAppSurfaces` reads the resolved
/// `colorScheme` to derive scaffold/dialog/sheet fills, so applying it before
/// `toPureBlack` would bake the unshifted tones into every surface theme.
ThemeData buildAppTheme(
  AppThemeSpec spec, {
  TargetPlatform? platform,
  List<Locale> locales = const [Locale('zh', 'CN')],
}) {
  final dark = spec.brightness == Brightness.dark;
  final scheme = seededColorScheme(
    seedColor: spec.seedColor,
    brightness: spec.brightness,
    style: spec.style,
  ).toPureBlack(spec.pureBlack);
  final target = platform ?? defaultTargetPlatform;
  final transparent = spec.transparentPage;
  return ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: commonSharedXPageTransitions,
        TargetPlatform.iOS: commonSharedXPageTransitions,
        TargetPlatform.windows: commonSharedXPageTransitions,
        TargetPlatform.macOS: commonSharedXPageTransitions,
        TargetPlatform.linux: commonSharedXPageTransitions,
        TargetPlatform.fuchsia: commonSharedXPageTransitions,
      },
    ),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (_) => const GlyphIcon(AppGlyphs.chevronBack),
      closeButtonIconBuilder: (_) => const GlyphIcon(AppGlyphs.close),
    ),
    // 透明背景：把页面底色设为透明（卡片/浮层仍是实色），根部壁纸层才能透出。
    // 与 1.4.3 `DITINGTheme(transparentBackground)` 的效果一致。
    colorScheme: scheme,
    fontFamilyFallback: appFontFamilyFallback(
      platform: target,
      locales: locales,
    ),
    extensions: [
      if (dark) ElevatedColorScheme(scheme.elevated),
    ],
  ).withAppShapes.withAppSurfaces.withAppTypography.copyWith(
    scaffoldBackgroundColor: transparent ? Colors.transparent : null,
  );
}

/// Caches the last theme per brightness.
///
/// [ThemeData] never compares equal to a freshly built one, and
/// [ThemeCrossFade] keys its cross-fade off exactly that inequality — so an
/// uncached rebuild on every unrelated state change would flash the whole
/// screen. Upstream keeps the same cache for the same reason.
class AppThemeCache {
  /// Bounded so that a long drag across the palette picker can't grow the map
  /// without limit; 16 covers 9 palettes × 2 brightness with room to spare.
  static const maxEntries = 16;

  final Map<AppThemeSpec, ThemeData> _themes = {};

  /// Number of cached themes; tests assert the bound.
  int get length => _themes.length;

  ThemeData of(
    AppThemeSpec spec, {
    TargetPlatform? platform,
    List<Locale> locales = const [Locale('zh', 'CN')],
  }) {
    final cached = _themes[spec];
    if (cached != null) {
      return cached;
    }
    // Insertion order is the eviction order: the oldest entry goes first.
    // Re-inserting the hottest spec would need a LinkedHashMap re-insert, and
    // the working set here is tiny, so plain FIFO is enough.
    if (_themes.length >= maxEntries) {
      _themes.remove(_themes.keys.first);
    }
    return _themes[spec] = buildAppTheme(
      spec,
      platform: platform,
      locales: locales,
    );
  }

  /// Drops everything; only tests and a locale switch need this.
  void clear() => _themes.clear();
}

/// A convenience wrapper: the light and dark themes a `MaterialApp` wants.
class AppThemePair {
  AppThemePair({
    required this.seedColor,
    required this.pureBlack,
    this.style = ColorStyle.vivid,
    this.transparentPage = false,
  });

  final Color seedColor;
  final bool pureBlack;
  final ColorStyle style;

  /// 开启自定义背景时为 true：页面底色透明，让根部的壁纸层透出。
  final bool transparentPage;

  AppThemeSpec get lightSpec => AppThemeSpec(
    seedColor: seedColor,
    brightness: Brightness.light,
    style: style,
    transparentPage: transparentPage,
  );

  AppThemeSpec get darkSpec => AppThemeSpec(
    seedColor: seedColor,
    brightness: Brightness.dark,
    pureBlack: pureBlack,
    style: style,
    transparentPage: transparentPage,
  );
}

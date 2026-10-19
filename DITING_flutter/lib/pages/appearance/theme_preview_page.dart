/// 主题实时预览页（上游 `views/theme_preview.dart`，850 行）。
///
/// 上游这一页是「大号手机预览 + 一组分组选项」：选项不写进主题页，而是在预览
/// 旁边直接改，这样每次点击都能立刻在大屏上看到结果。这里保留同样的结构，
/// 但把状态换成与主题页共用的一组 provider——两个页面改同一份状态，来回切换
/// 不会出现「这里选了、那里没同步」。
library;

import 'package:diting/app/theme/colors.dart';
import 'package:diting/app/theme/manager.dart';
import 'package:diting/pages/appearance/mini_screen.dart';
import 'package:diting/pages/appearance/preview_choice.dart';
import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 主题实时预览页。
class ThemePreviewPage extends ConsumerWidget {
  const ThemePreviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommonScaffold(
      title: '预览',
      body: PageBody(
        dockSpacer: false,
        children: const [
          SizedBox(height: 8),
          _SplitComparison(),
          SizedBox(height: 20),
          _ModeGroup(),
          SizedBox(height: 8),
          _PrimaryColorGroup(),
          SizedBox(height: 8),
          _BottomBarGroup(),
          SizedBox(height: 8),
          _GlassGroup(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 顶部对比屏：左浅右深，同一种子色并排，用来判断「这套配色在两种明暗下
/// 是否都成立」。分割线不是装饰——它标出两侧各自的完整性。
class _SplitComparison extends ConsumerWidget {
  const _SplitComparison();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = ref.watch(customPrimaryColorProvider) ??
        ref.watch(paletteProvider).effectiveSeed;
    final pureBlack = ref.watch(pureBlackProvider);
    final floating = ref.watch(bottomBarStyleProvider).isFloating;
    final glass = ref.watch(liquidGlassModeProvider).enabled;
    final light = buildAppTheme(
      AppThemeSpec(seedColor: seed, brightness: Brightness.light),
    ).colorScheme;
    final dark = buildAppTheme(
      AppThemeSpec(
        seedColor: seed,
        brightness: Brightness.dark,
        pureBlack: pureBlack,
      ),
    ).colorScheme;
    Widget screen(ColorScheme scheme, int selected) => MiniScreen(
      colorScheme: scheme,
      floatingBar: floating,
      liquidGlass: glass,
      selected: selected,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CommonCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Row(
              children: [
                Text('浅色 / 深色并排', style: context.cardHeaderStyle),
                const Spacer(),
                MetaChip(label: '种子 ${_hex(seed)}'),
              ],
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRSuperellipse(
                borderRadius: AppRadius.lg,
                child: MiniSplitScreen(
                  light: screen(light, 0),
                  dark: screen(dark, 0),
                ),
              ),
            ),
            Text(
              '左侧浅色、右侧深色，同一颗种子推导两套角色色。'
              '纯黑开关只折叠深色那一侧。',
              style: context.listCaptionStyle,
            ),
          ],
        ),
      ),
    );
  }
}

String _hex(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// 日夜模式三选一。
class _ModeGroup extends ConsumerWidget {
  const _ModeGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final seed = ref.watch(customPrimaryColorProvider) ??
        ref.watch(paletteProvider).effectiveSeed;
    final pureBlack = ref.watch(pureBlackProvider);
    final light = buildAppTheme(
      AppThemeSpec(seedColor: seed, brightness: Brightness.light),
    ).colorScheme;
    final dark = buildAppTheme(
      AppThemeSpec(
        seedColor: seed,
        brightness: Brightness.dark,
        pureBlack: pureBlack,
      ),
    ).colorScheme;
    final floating = ref.watch(bottomBarStyleProvider).isFloating;
    Widget thumb(ColorScheme scheme) => MiniScreenThumb(
      screen: MiniScreen(colorScheme: scheme, floatingBar: floating),
    );
    return PreviewChoiceGroup<AppThemeMode>(
      info: const Info(label: '日夜模式', glyph: AppGlyphs.sun),
      value: mode,
      choices: [
        for (final value in AppThemeMode.values)
          PreviewChoice(
            value: value,
            label: value.label,
            pictogram: switch (value) {
              AppThemeMode.light => thumb(light),
              AppThemeMode.dark => thumb(dark),
              AppThemeMode.system => MiniScreenThumb(
                screen: MiniSplitScreen(
                  light: MiniScreen(colorScheme: light, floatingBar: floating),
                  dark: MiniScreen(colorScheme: dark, floatingBar: floating),
                ),
              ),
            },
          ),
      ],
      onChanged: (value) => ref.read(themeModeProvider.notifier).select(value),
    );
  }
}

/// 主题色九选一，每一项缩略图用它自己的种子推导。
class _PrimaryColorGroup extends ConsumerWidget {
  const _PrimaryColorGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final custom = ref.watch(customPrimaryColorProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PreviewChoiceGroup<AppPalette>(
      info: const Info(label: '主题色', glyph: AppGlyphs.palette),
      value: palette,
      choices: [
        for (final value in AppPalette.values)
          PreviewChoice(
            value: value,
            label: value.label,
            pictogram: MiniScreenThumb(
              screen: MiniScreen(
                colorScheme: buildAppTheme(
                  AppThemeSpec(
                    seedColor: value.effectiveSeed,
                    brightness: dark ? Brightness.dark : Brightness.light,
                  ),
                ).colorScheme,
                floatingBar: true,
              ),
            ),
          ),
      ],
      onChanged: (value) {
        ref.read(customPrimaryColorProvider.notifier).clear();
        ref.read(paletteProvider.notifier).select(value);
      },
      footer: custom == null
          ? null
          : '当前显示的是自定义色 ${_hex(custom)}；选任一色板会丢弃它。',
    );
  }
}

/// 底栏形态。
class _BottomBarGroup extends ConsumerWidget {
  const _BottomBarGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(bottomBarStyleProvider);
    final seed = ref.watch(customPrimaryColorProvider) ??
        ref.watch(paletteProvider).effectiveSeed;
    final scheme = buildAppTheme(
      AppThemeSpec(seedColor: seed, brightness: Theme.of(context).brightness),
    ).colorScheme;
    final glass = ref.watch(liquidGlassModeProvider).enabled;
    return PreviewChoiceGroup<BottomBarStyle>(
      info: const Info(label: '底栏样式', glyph: AppGlyphs.dashboard),
      value: style,
      choices: [
        for (final value in BottomBarStyle.values)
          PreviewChoice(
            value: value,
            label: value.label,
            pictogram: MiniScreenThumb(
              screen: MiniScreen(
                colorScheme: scheme,
                floatingBar: value.isFloating,
                liquidGlass: glass,
              ),
            ),
          ),
      ],
      onChanged: (value) =>
          ref.read(bottomBarStyleProvider.notifier).select(value),
    );
  }
}

/// Liquid 玻璃三档。
class _GlassGroup extends ConsumerWidget {
  const _GlassGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(liquidGlassModeProvider);
    final seed = ref.watch(customPrimaryColorProvider) ??
        ref.watch(paletteProvider).effectiveSeed;
    final scheme = buildAppTheme(
      AppThemeSpec(seedColor: seed, brightness: Theme.of(context).brightness),
    ).colorScheme;
    return PreviewChoiceGroup<LiquidGlassMode>(
      info: const Info(label: 'Liquid 玻璃', glyph: AppGlyphs.liquidGlass),
      value: mode,
      choices: [
        for (final value in LiquidGlassMode.values)
          PreviewChoice(
            value: value,
            label: value.label,
            pictogram: MiniScreenThumb(
              screen: MiniScreen(
                colorScheme: scheme,
                floatingBar: true,
                liquidGlass: value.enabled,
              ),
            ),
          ),
      ],
      onChanged: (value) =>
          ref.read(liquidGlassModeProvider.notifier).select(value),
      footer: '缩略图里玻璃只体现在浮条上：页头与卡片的玻璃要整棵树打开才有意义。',
    );
  }
}

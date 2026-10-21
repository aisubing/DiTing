/// 主题色配置页（旧版 `APPEARANCE_SETTINGS` 的「主题色配置」项）。
///
/// 九个色板圆点 + 缩略图预览。1.4.3 的 `ThemeColorStyle` 也是九项，其中 GOLD
/// 的落盘值仍然是 `indigo`（历史包袱），这一点由 `AppPalette.storageValue`
/// 承担，页面不需要知道。
///
/// 上一轮这一块还带「自定义取色」（色相/饱和度调色板）。旧版没有取色器，
/// 本轮随 `theme_color_sheet.dart` 一并删除——`customPrimaryColorProvider`
/// 也随之退场，主题色只由九色板决定。
library;

import 'package:diting/app/theme/colors.dart';
import 'package:diting/pages/appearance/preview_choice.dart';
import 'package:diting/pages/appearance/theme_page.dart';
import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 主题色：九选一，每项带一张按该色推导出的缩略图。
class ThemeColorPage extends ConsumerWidget {
  const ThemeColorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final pureBlack = ref.watch(pureBlackProvider);
    final floating = ref.watch(bottomBarStyleProvider).isFloating;
    final glass = ref.watch(liquidGlassModeProvider).enabled;
    final brightness = switch (ref.watch(themeModeProvider)) {
      AppThemeMode.light => Brightness.light,
      AppThemeMode.dark => Brightness.dark,
      AppThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
    return CommonScaffold(
      title: '主题色配置',
      body: PageBody(
        children: [
          PreviewChoiceGroup<AppPalette>(
            info: const Info(label: '色板'),
            value: palette,
            choices: [
              for (final option in AppPalette.values)
                PreviewChoice(
                  value: option,
                  label: option.label,
                  description: option == AppPalette.gold
                      ? '落盘值沿用旧版的 indigo'
                      : null,
                  pictogram: miniScreenThumb(
                    colorScheme: demoColorScheme(
                      seed: option.effectiveSeed,
                      brightness: brightness,
                      pureBlack: pureBlack,
                    ),
                    floatingBar: floating,
                    liquidGlass: glass,
                  ),
                ),
            ],
            onChanged: (value) =>
                ref.read(paletteProvider.notifier).select(value),
            footer:
                '色板只提供种子，上屏的是 HCT 推导出的整套角色色。'
                '旧版没有自定义取色，因此这里也不提供。',
          ),
        ],
      ),
    );
  }
}

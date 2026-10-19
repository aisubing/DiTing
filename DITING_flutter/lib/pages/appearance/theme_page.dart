/// 主题设置页（上游 `views/theme.dart`，1209 行）。
///
/// 页面结构照抄上游的条目顺序：实时预览 → 日夜模式 → 纯黑 → 主题色 →
/// 底栏样式 → tab 动画 → Liquid 玻璃 → 字体 → 字号。顺序本身就是信息：
/// 上面每一项都会立刻反映到最顶上的预览里，所以预览必须在最上面。
///
/// 按 AGENTS.md 的 550 行上限拆成库根 + part：本文件是页面骨架与预览区，
/// 选项区在 `theme_sections.dart`，自定义取色浮层在 `theme_color_sheet.dart`。
library;

import 'dart:async';

import 'package:diting/app/theme/colors.dart';
import 'package:diting/app/theme/layout.dart';
import 'package:diting/app/theme/manager.dart';
import 'package:diting/pages/appearance/mini_screen.dart';
import 'package:diting/pages/appearance/preview_choice.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

part 'theme_sections.dart';
part 'theme_color_section.dart';
part 'theme_color_sheet.dart';

/// 一个演示用主题（种子色 + 明暗），预览与缩略图都用它推导角色色。
ColorScheme demoColorScheme({
  required Color seed,
  required Brightness brightness,
  bool pureBlack = false,
}) => buildAppTheme(
  AppThemeSpec(
    seedColor: seed,
    brightness: brightness,
    pureBlack: pureBlack,
  ),
).colorScheme;

/// 主题设置页。
class ThemePage extends ConsumerWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final custom = ref.watch(customPrimaryColorProvider);
    final seed = custom ?? palette.effectiveSeed;
    return CommonScaffold(
      title: '主题',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.split,
          tooltip: '打开完整预览',
          onPressed: () => context.push(SystemPaths.themePreview),
        ),
      ],
      body: PageBody(
        children: [
          _ThemeLivePreview(seed: seed),
          const SizedBox(height: 8),
          const _ThemeModeSection(),
          const SizedBox(height: 8),
          const _PureBlackSection(),
          const SizedBox(height: 8),
          _PrimaryColorSection(seed: seed),
          const SizedBox(height: 8),
          const _BottomBarStyleSection(),
          const SizedBox(height: 8),
          const _TabTransitionSection(),
          const SizedBox(height: 8),
          const _LiquidGlassSection(),
          const SizedBox(height: 8),
          _FontFamilyEntry(family: ref.watch(selectedFontFamilyProvider)),
          const SizedBox(height: 8),
          const _TextScaleSection(),
          const SizedBox(height: 8),
          const _ResetSection(),
        ],
      ),
    );
  }
}

/// 顶部的实时预览：一台小手机，可以点底栏换页，切换方式就是当前选中的
/// tab 动画——开关的效果不用靠想象。
class _ThemeLivePreview extends ConsumerStatefulWidget {
  const _ThemeLivePreview({required this.seed});

  final Color seed;

  @override
  ConsumerState<_ThemeLivePreview> createState() => _ThemeLivePreviewState();
}

class _ThemeLivePreviewState extends ConsumerState<_ThemeLivePreview>
    with SingleTickerProviderStateMixin {
  static const double _phoneWidth = 168;
  static const _duration = Duration(milliseconds: 300);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: 1,
  );

  int _selected = 0;
  int? _previous;

  Future<void> _select(int index) async {
    if (index == _selected || _controller.isAnimating) {
      return;
    }
    final transition = ref.read(tabTransitionProvider);
    setState(() {
      _previous = _selected;
      _selected = index;
    });
    if (transition == TabTransition.none) {
      setState(() => _previous = null);
      return;
    }
    await _controller.forward(from: 0).orCancel.catchError((_) {});
    if (mounted && _selected == index) {
      setState(() => _previous = null);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final pureBlack = ref.watch(pureBlackProvider);
    final floating = ref.watch(bottomBarStyleProvider).isFloating;
    final glass = ref.watch(liquidGlassModeProvider).enabled;
    final transition = ref.watch(tabTransitionProvider);
    final brightness = switch (mode) {
      AppThemeMode.light => Brightness.light,
      AppThemeMode.dark => Brightness.dark,
      AppThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
    final scheme = demoColorScheme(
      seed: widget.seed,
      brightness: brightness,
      pureBlack: pureBlack,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: _phoneWidth,
            child: AspectRatio(
              aspectRatio: 9 / 17,
              child: ClipRSuperellipse(
                borderRadius: AppRadius.all(AppCorner.fit(_phoneWidth)),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, _) => MiniScreen(
                    colorScheme: scheme,
                    floatingBar: floating,
                    liquidGlass: glass,
                    selected: _selected,
                    previous: _previous,
                    progress: _previous == null ? 1 : _controller.value,
                    transition: transition,
                    onSelect: _select,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 把一组预览需要的明暗两套色板算出来，供各选项的缩略图复用。
///
/// 上游每个条目各自 `ref.watch(genColorSchemeProvider(...))`；这里合成一处，
/// 避免同一屏里为同一组参数反复建 `ThemeData`（`buildAppTheme` 不便宜）。
({ColorScheme light, ColorScheme dark}) previewSchemes({
  required Color seed,
  required bool pureBlack,
}) => (
  light: demoColorScheme(seed: seed, brightness: Brightness.light),
  dark: demoColorScheme(
    seed: seed,
    brightness: Brightness.dark,
    pureBlack: pureBlack,
  ),
);

/// 缩略图：给一组选择项用的固定尺寸容器。
Widget miniScreenThumb({
  required ColorScheme colorScheme,
  required bool floatingBar,
  bool liquidGlass = false,
  int selected = 0,
  int? previous,
  double progress = 1,
  TabTransition transition = TabTransition.slide,
}) => MiniScreenThumb(
  screen: MiniScreen(
    colorScheme: colorScheme,
    floatingBar: floatingBar,
    liquidGlass: liquidGlass,
    selected: selected,
    previous: previous,
    progress: progress,
    transition: transition,
  ),
);

/// 外观设置页（旧版 `APPEARANCE_SETTINGS`，3 组 8 项菜单）。
///
/// 1.4.3 的 `AppearanceSettingsScreen.kt` 是一页菜单，不是一屏控件：
///
/// | 组 | 项 | 落点 |
/// |---|---|---|
/// | 界面显示 | 日夜模式 | `/theme/day-night` |
/// | | 主题色配置 | `/theme/color` |
/// | | 首页透明度 | `/theme/home-opacity` |
/// | | 底栏自定义 | `/theme/bottom-bar` |
/// | 首页内容 | 首页句子 | `/theme/home-sentence` |
/// | | 通知栏设置 | `/theme/notification` |
/// | 背景与动效 | 软件背景 | `/theme/background` |
/// | | 底栏触感反馈 | 内联开关 |
///
/// 上一轮这一页是「实时预览 + 九个控件同屏」，与旧版层级完全不同。本轮按旧版
/// 拆成菜单 + 二级页；大预览（`MiniScreen` 手机框）保留在菜单顶部——它是既有的
/// 设计资产，且 `MiniScreen` 在九个二级页的缩略图里仍被复用。
///
/// **保留项的落点**（用户要求保留、旧版无对应项）：纯黑、字号、字体都并入
/// 「界面显示」组，排在旧版四项之后，旧版项的文案、顺序、落盘键一字不动；
/// 底栏样式 / tab 动画 / 液态玻璃放进「背景与动效」组同样排在最后。这样既满足
/// 「旧版项严格对齐」，也不新增菜单层级。
library;

import 'package:diting/app/theme/colors.dart';
import 'package:diting/app/theme/layout.dart';
import 'package:diting/app/theme/manager.dart';
import 'package:diting/pages/appearance/mini_screen.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 一个演示用主题（种子色 + 明暗），预览与缩略图都用它推导角色色。
ColorScheme demoColorScheme({
  required Color seed,
  required Brightness brightness,
  bool pureBlack = false,
}) => buildAppTheme(
  AppThemeSpec(seedColor: seed, brightness: brightness, pureBlack: pureBlack),
).colorScheme;

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

/// 外观设置页：三组菜单。
class ThemePage extends ConsumerWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pureBlack = ref.watch(pureBlackProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final transition = ref.watch(tabTransitionProvider);
    final glass = ref.watch(liquidGlassModeProvider);
    final barStyle = ref.watch(bottomBarStyleProvider);
    return CommonScaffold(
      title: '外观设置',
      body: PageBody(
        children: [
          // 大预览：旧版没有整页预览，但它是上一轮既有的设计资产，且九个二级页
          // 的缩略图都建立在同一套 MiniScreen 上，删掉等于把缩略图也一起废掉。
          const _ThemePreview(),
          generateSection(
            title: '界面显示',
            items: [
              // —— 旧版四项：文案与顺序一字不动 ——
              _MenuRow(
                glyph: AppGlyphs.sun,
                title: '日夜模式',
                subtitle: _themeModeLabel(ref.watch(themeModeProvider)),
                route: SystemPaths.dayNight,
              ),
              _MenuRow(
                glyph: AppGlyphs.palette,
                title: '主题色配置',
                subtitle: ref.watch(paletteProvider).label,
                route: SystemPaths.colorStyle,
              ),
              _MenuRow(
                glyph: AppGlyphs.blur,
                title: '首页透明度',
                subtitle: '交互组件与文字的透明度',
                route: SystemPaths.homeOpacity,
              ),
              _MenuRow(
                glyph: AppGlyphs.dashboard,
                title: '底栏自定义',
                subtitle:
                    '已选 ${ref.watch(bottomBarProvider).length} 项，可配置 2–4 项',
                route: SystemPaths.bottomBar,
              ),
              // —— 保留项：纯黑 / 字号 / 字体，排在旧版项之后 ——
              ListItem.toggle(
                title: const Text('纯黑'),
                subtitle: Text(dark ? '深色表面折叠为纯黑，OLED 更省电' : '切到深色模式后才可开启'),
                leading: const GlyphIcon(AppGlyphs.pureBlack),
                value: pureBlack,
                onChanged: dark
                    ? (value) =>
                          ref.read(pureBlackProvider.notifier).toggle(value)
                    : null,
              ),
              _TextScaleRow(),
              _MenuRow(
                glyph: AppGlyphs.font,
                title: '字体',
                subtitle: ref.watch(selectedFontFamilyProvider) ?? '系统默认',
                route: SystemPaths.fontFamily,
              ),
            ],
          ),
          generateSection(
            title: '首页内容',
            items: [
              _MenuRow(
                glyph: AppGlyphs.textShort,
                title: '首页句子',
                subtitle: '运行与停止两种状态各一句',
                route: SystemPaths.homeSentence,
              ),
              _MenuRow(
                glyph: AppGlyphs.status,
                title: '通知栏设置',
                subtitle: '常驻通知、实时速率与自定义文案',
                route: SystemPaths.notification,
              ),
            ],
          ),
          generateSection(
            title: '背景与动效',
            items: [
              _MenuRow(
                glyph: AppGlyphs.photos,
                title: '软件背景',
                subtitle: ref.watch(customBackgroundProvider).enabled
                    ? '已启用'
                    : '未启用',
                route: SystemPaths.background,
              ),
              ListItem.toggle(
                title: const Text('底栏触感反馈'),
                subtitle: const Text('切换 tab 时给一次轻震'),
                leading: const GlyphIcon(AppGlyphs.motion),
                value: ref.watch(hapticProvider),
                onChanged: (value) =>
                    ref.read(hapticProvider.notifier).toggle(value),
              ),
              // —— 保留项：底栏样式 / tab 动画 / 液态玻璃 ——
              ListItem<BottomBarStyle>.options(
                title: const Text('底栏样式'),
                subtitle: Text(barStyle.isFloating ? '浮在页面之上' : '贴底排列'),
                leading: const GlyphIcon(AppGlyphs.sliders),
                options: BottomBarStyle.values,
                value: barStyle,
                textBuilder: (value) => value.label,
                onChanged: (value) =>
                    ref.read(bottomBarStyleProvider.notifier).select(value),
              ),
              ListItem<TabTransition>.options(
                title: const Text('tab 切换动画'),
                subtitle: const Text('切换底部标签时的动画方式'),
                leading: const GlyphIcon(AppGlyphs.motion),
                options: TabTransition.values,
                value: transition,
                textBuilder: (value) => value.label,
                onChanged: (value) =>
                    ref.read(tabTransitionProvider.notifier).select(value),
              ),
              ListItem<LiquidGlassMode>.options(
                title: const Text('Liquid 玻璃'),
                subtitle: Text(glass.label),
                leading: const GlyphIcon(AppGlyphs.liquidGlass),
                options: LiquidGlassMode.values,
                value: glass,
                textBuilder: (value) => value.label,
                onChanged: (value) =>
                    ref.read(liquidGlassModeProvider.notifier).select(value),
              ),
            ],
            footer: '底栏样式、动画与玻璃只作用于浮条；普通底栏始终是实色。',
          ),
        ],
      ),
    );
  }

  static String _themeModeLabel(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => '跟随系统',
    AppThemeMode.light => '浅色模式',
    AppThemeMode.dark => '深色模式',
  };
}

/// 一行菜单入口。
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final Glyph glyph;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: GlyphIcon(glyph),
      trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
      onTap: () => context.push(route),
    );
  }
}

/// 字号滑杆行：直接嵌在「界面显示」组里，不另开二级页。
class _TextScaleRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(textScaleProvider);
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 2,
        children: [
          Row(
            spacing: 10,
            children: [
              GlyphIcon(
                AppGlyphs.textSize,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              Expanded(child: Text('字号', style: context.listTitleStyle)),
              Text(
                '${(scale * 100).round()}%',
                style: context.listSubtitleStyle.copyWith(
                  fontFamily: 'JetBrainsMono',
                ),
              ),
            ],
          ),
          Slider(
            value: scale,
            min: minTextScale,
            max: maxTextScale,
            divisions: ((maxTextScale - minTextScale) / 0.1).round(),
            label: '${(scale * 100).round()}%',
            onChanged: (value) =>
                ref.read(textScaleProvider.notifier).set(value),
          ),
        ],
      ),
    );
  }
}

/// 顶部大预览：手机框里的迷你界面，随外观选择实时变化。
class _ThemePreview extends ConsumerStatefulWidget {
  const _ThemePreview();

  @override
  ConsumerState<_ThemePreview> createState() => _ThemePreviewState();
}

class _ThemePreviewState extends ConsumerState<_ThemePreview>
    with SingleTickerProviderStateMixin {
  static const _phoneWidth = 180.0;

  late final AnimationController _controller;
  int _selected = 0;
  int? _previous;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 1,
    );
  }

  void _select(int index) {
    if (index == _selected) {
      return;
    }
    setState(() {
      _previous = _selected;
      _selected = index;
    });
    _controller.forward(from: 0).whenComplete(() {
      if (mounted) {
        setState(() => _previous = null);
      }
    });
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
      seed: ref.watch(paletteProvider).effectiveSeed,
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

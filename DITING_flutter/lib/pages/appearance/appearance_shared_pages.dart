/// 外观子树的二级页（上半）：日夜模式 / 首页透明度 / 底栏自定义 / 首页句子。
///
/// 1.4.3 的 `APPEARANCE_SETTINGS` 是「3 组 8 项」的菜单，每项点进自己的二级页。
/// 上一轮这些项几乎全堆在 `/theme` 一屏里，与旧版层级完全不同。本轮按旧版拆开：
///
/// - 界面显示：日夜模式 / 主题色配置 / 首页透明度 / 底栏自定义（+ 保留的细节项）
/// - 首页内容：首页句子 / 通知栏设置
/// - 背景与动效：软件背景 / 底栏触感反馈
///
/// 主题色在 `appearance_color_page.dart`；通知栏 / 背景 / 前后台行为 / 语言在
/// `settings_parity_pages.dart`。拆成两个文件的唯一原因是 550 行上限。
library;

import 'package:diting/app/theme/colors.dart';
import 'package:diting/app/theme/layout.dart';
import 'package:diting/pages/appearance/mini_screen.dart';
import 'package:diting/pages/appearance/preview_choice.dart';
import 'package:diting/pages/appearance/theme_page.dart';
import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

// ---------------------------------------------------------------------------
// 日夜模式（旧版「界面显示」第一项）
// ---------------------------------------------------------------------------

/// 日夜模式：跟随系统 / 浅色 / 深色，各配一张缩略图。
class ThemeDayNightPage extends ConsumerWidget {
  const ThemeDayNightPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final pureBlack = ref.watch(pureBlackProvider);
    final seed = ref.watch(paletteProvider).effectiveSeed;
    final floating = ref.watch(bottomBarStyleProvider).isFloating;
    final glass = ref.watch(liquidGlassModeProvider).enabled;
    final schemes = previewSchemes(seed: seed, pureBlack: pureBlack);
    Widget thumb(Brightness brightness) => miniScreenThumb(
      colorScheme: brightness == Brightness.light
          ? schemes.light
          : schemes.dark,
      floatingBar: floating,
      liquidGlass: glass,
    );
    return CommonScaffold(
      title: '日夜模式',
      body: PageBody(
        children: [
          PreviewChoiceGroup<AppThemeMode>(
            info: const Info(label: '模式'),
            value: mode,
            choices: [
              PreviewChoice(
                value: AppThemeMode.system,
                label: '跟随系统',
                description: '系统切换深色时一起切换',
                pictogram: MiniScreenThumb(
                  screen: MiniSplitScreen(
                    light: MiniScreen(
                      colorScheme: schemes.light,
                      floatingBar: floating,
                      liquidGlass: glass,
                    ),
                    dark: MiniScreen(
                      colorScheme: schemes.dark,
                      floatingBar: floating,
                      liquidGlass: glass,
                    ),
                  ),
                ),
              ),
              PreviewChoice(
                value: AppThemeMode.light,
                label: '浅色模式',
                pictogram: thumb(Brightness.light),
              ),
              PreviewChoice(
                value: AppThemeMode.dark,
                label: '深色模式',
                pictogram: thumb(Brightness.dark),
              ),
            ],
            onChanged: (value) =>
                ref.read(themeModeProvider.notifier).select(value),
            footer: '纯黑只在深色模式下生效，开关在「外观设置」的界面显示组里。',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 首页透明度（旧版 HomeComponentOpacityScreen）
// ---------------------------------------------------------------------------

/// 首页元素透明度：交互组件三项 + 文字两项，共五条滑杆。
///
/// 旧版按「交互组件 / 文字」两组渲染，顺序与文案照抄；每条键取自
/// [HomeLayer.storageKey]（`home_*_opacity`）。第 5 项
/// `home_dns_detail_opacity` 是本轮才补上的——上一轮 `HomeLayer` 少了它，
/// 滑杆与首页的「DNS 服务详情」块都无从谈起。
class ThemeHomeOpacityPage extends ConsumerWidget {
  const ThemeHomeOpacityPage({super.key});

  /// 旧版分组：交互组件 3 条。
  static const _interactive = [
    HomeLayer.powerButton,
    HomeLayer.providerSelector,
    HomeLayer.modeButton,
  ];

  /// 旧版分组：文字 2 条。
  static const _text = [HomeLayer.poem, HomeLayer.dnsDetail];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opacity = ref.watch(homeOpacityProvider);
    final notifier = ref.read(homeOpacityProvider.notifier);
    return CommonScaffold(
      title: '首页透明度',
      body: PageBody(
        children: [
          generateSection(
            title: '交互组件',
            footer: '透明度只影响可见度，不影响这些组件的点击区域。',
            items: [
              for (final layer in _interactive)
                _OpacitySlider(
                  layer: layer,
                  value: opacity[layer] ?? 1,
                  onChanged: (value) => notifier.set(layer, value),
                ),
            ],
          ),
          generateSection(
            title: '文字',
            items: [
              for (final layer in _text)
                _OpacitySlider(
                  layer: layer,
                  value: opacity[layer] ?? 1,
                  onChanged: (value) => notifier.set(layer, value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 一条透明度滑杆。
class _OpacitySlider extends StatelessWidget {
  const _OpacitySlider({
    required this.layer,
    required this.value,
    required this.onChanged,
  });

  final HomeLayer layer;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Text(layer.label, style: context.listTitleStyle),
                Text(
                  '${(value * 100).round()}%',
                  style: context.listCaptionStyle.copyWith(
                    fontFamily: 'JetBrainsMono',
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 150,
            child: Slider(
              value: value,
              min: 0.1,
              max: 1,
              divisions: 18,
              label: '${(value * 100).round()}%',
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 底栏自定义（旧版 BottomBarCustomizationScreen）
// ---------------------------------------------------------------------------

/// 底栏六项的一句话说明。旧版底栏页每行带副标题，枚举里没有这个字段。
const _destinationSubtitles = {
  BottomBarDestination.home: '首页与仪表盘',
  BottomBarDestination.featureHub: '全部功能入口',
  BottomBarDestination.logDashboard: '日志仪表盘',
  BottomBarDestination.appTraffic: '应用流量排行',
  BottomBarDestination.networkTools: '测速与网络诊断',
  BottomBarDestination.settings: '全部设置项',
};

/// 底栏自定义：六项开关，至少 2 项、最多 4 项。
///
/// 上限来自 [maxDockDestinations]（本轮从 5 改回旧版的 4）。被拒绝时给一句话
/// 说明——否则用户只看到开关弹回去，会以为点坏了。
class ThemeBottomBarPage extends ConsumerWidget {
  const ThemeBottomBarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(bottomBarProvider);
    final notifier = ref.read(bottomBarProvider.notifier);
    final haptic = ref.watch(hapticProvider);
    return CommonScaffold(
      title: '底栏自定义',
      body: PageBody(
        children: [
          generateSection(
            title: '底栏项（${destinations.length}/$maxDockDestinations）',
            footer:
                '至少 2 项、最多 $maxDockDestinations 项：浮条按项数等比分配宽度，'
                '再多就挤到看不清图标。',
            items: [
              for (final destination in BottomBarDestination.values)
                ListItem.toggle(
                  title: Text(destination.label),
                  subtitle: Text(_destinationSubtitles[destination] ?? ''),
                  leading: GlyphIcon(destination.glyph),
                  value: destinations.contains(destination),
                  onChanged: (_) {
                    final selected = destinations.contains(destination);
                    if (!notifier.toggle(destination)) {
                      showSettingHint(
                        context,
                        selected ? '底栏至少保留 2 项' : '底栏最多 $maxDockDestinations 项',
                      );
                    }
                  },
                ),
            ],
          ),
          generateSection(
            title: '手感',
            items: [
              ListItem.toggle(
                title: const Text('底栏触感反馈'),
                subtitle: const Text('切换 tab 时给一次轻震'),
                leading: const GlyphIcon(AppGlyphs.motion),
                value: haptic,
                onChanged: (value) =>
                    ref.read(hapticProvider.notifier).toggle(value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 首页句子（旧版 HomeSentenceScreen）
// ---------------------------------------------------------------------------

/// 首页句子：运行 / 停止两态各一条，留空即不显示。
class ThemeHomeSentencePage extends ConsumerStatefulWidget {
  const ThemeHomeSentencePage({super.key});

  @override
  ConsumerState<ThemeHomeSentencePage> createState() =>
      _ThemeHomeSentencePageState();
}

class _ThemeHomeSentencePageState extends ConsumerState<ThemeHomeSentencePage> {
  late final TextEditingController _running;
  late final TextEditingController _stopped;

  @override
  void initState() {
    super.initState();
    final sentences = ref.read(homeSentenceProvider);
    _running = TextEditingController(text: sentences.running);
    _stopped = TextEditingController(text: sentences.stopped);
  }

  @override
  void dispose() {
    _running.dispose();
    _stopped.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '首页句子',
      body: PageBody(
        children: [
          generateSection(
            title: '两句文案',
            footer: '留空则不显示那一句。句子只在首页电源区下方出现一次。',
            items: [
              InlineTextFieldRow(
                title: '运行中',
                controller: _running,
                onChanged: (value) =>
                    ref.read(homeSentenceProvider.notifier).set(running: value),
              ),
              InlineTextFieldRow(
                title: '已停止',
                controller: _stopped,
                onChanged: (value) =>
                    ref.read(homeSentenceProvider.notifier).set(stopped: value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 两个文件共用的小部件
// ---------------------------------------------------------------------------

/// 一次性的 SnackBar 提示。
///
/// 设置页的大量动作是「改了就生效」，被规则拒绝时除了开关弹回去没有任何痕迹，
/// 用户会以为点坏了——必须补一句说明（这条经验写在本仓 AGENT_MISTAKES 里）。
void showSettingHint(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1800),
    ),
  );
}

/// 「上标签 + 下输入框」的内联编辑行。
///
/// 不复用 `ListItem.input`：那个自带点击弹出的对话框，而这里是内联编辑，
/// 行为完全不同。
class InlineTextFieldRow extends StatelessWidget {
  const InlineTextFieldRow({
    super.key,
    required this.title,
    required this.controller,
    required this.onChanged,
    this.hintText,
  });

  final String title;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(title, style: context.listTitleStyle),
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: hintText,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

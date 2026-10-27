/// Appearance sub pages: day/night, opacity, dock, sentences. Rest in `settings_parity_pages`.
library;

import 'package:diting/app/theme/colors.dart';
import 'package:diting/app/theme/layout.dart';
import 'package:diting/pages/appearance/appearance_inputs.dart';
import 'package:diting/pages/appearance/mini_screen.dart';
import 'package:diting/pages/appearance/preview_choice.dart';
import 'package:diting/pages/appearance/theme_page.dart';
import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

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

/// Home element opacity. Keys come from [HomeLayer.storageKey] (`home_*_opacity`);
/// `home_dns_detail_opacity` is not a [HomeLayer] but the DNS detail block requires it.
class ThemeHomeOpacityPage extends ConsumerWidget {
  const ThemeHomeOpacityPage({super.key});

  static const _interactive = [
    HomeLayer.powerButton,
    HomeLayer.providerSelector,
    HomeLayer.modeButton,
  ];

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
                SliderCardRow(
                  label: layer.label,
                  value: opacity[layer] ?? 1,
                  onChanged: (value) => notifier.set(layer, value),
                ),
            ],
          ),
          generateSection(
            title: '文字',
            items: [
              for (final layer in _text)
                SliderCardRow(
                  label: layer.label,
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

/// One-line description per dock destination; the enum has no such field.
const _destinationSubtitles = {
  BottomBarDestination.home: '首页与仪表盘',
  BottomBarDestination.featureHub: '全部功能入口',
  BottomBarDestination.logDashboard: '日志仪表盘',
  BottomBarDestination.appTraffic: '应用流量排行',
  BottomBarDestination.networkTools: '测速与网络诊断',
  BottomBarDestination.settings: '全部设置项',
};

/// Dock customization: six switches, at least 2 and at most 4 enabled
/// ([maxDockDestinations]). Rejections must explain themselves.
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

/// Home sentences: one each for running and stopped; empty hides them.
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: FieldGroupCard(
              children: [
                LabeledTextField(
                  label: 'DNS 服务开启时',
                  controller: _running,
                  minLines: 2,
                  onChanged: (value) => ref
                      .read(homeSentenceProvider.notifier)
                      .set(running: value),
                ),
                LabeledTextField(
                  label: 'DNS 服务关闭时',
                  controller: _stopped,
                  minLines: 2,
                  onChanged: (value) => ref
                      .read(homeSentenceProvider.notifier)
                      .set(stopped: value),
                ),
              ],
            ),
          ),
          const ListFooter(text: '两项均可留空；留空后对应状态下首页不显示句子，句子只在首页电源区下方出现一次。'),
        ],
      ),
    );
  }
}

/// One-shot SnackBar notice for rule rejections, which otherwise leave no trace
/// beyond the switch bouncing back.
void showSettingHint(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1800),
    ),
  );
}

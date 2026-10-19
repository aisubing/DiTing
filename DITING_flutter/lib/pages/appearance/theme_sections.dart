part of 'theme_page.dart';

/// 日夜模式：三项各配一张缩略图，跟随系统那项是左右分割屏。
class _ThemeModeSection extends ConsumerWidget {
  const _ThemeModeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final pureBlack = ref.watch(pureBlackProvider);
    final seed = ref.watch(customPrimaryColorProvider) ??
        ref.watch(paletteProvider).effectiveSeed;
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
    return PreviewChoiceGroup<AppThemeMode>(
      info: const Info(label: '日夜模式', glyph: AppGlyphs.sun),
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
      onChanged: (value) => ref.read(themeModeProvider.notifier).select(value),
    );
  }
}

/// 纯黑：只在深色下有意义，浅色时禁用并说明原因。
class _PureBlackSection extends ConsumerWidget {
  const _PureBlackSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(pureBlackProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return generateSection(
      title: '省电',
      footer: '纯黑只在深色模式生效：它把深色表面折叠为 #000，浅色主题没有对应物。',
      items: [
        ListItem.toggle(
          title: const Text('纯黑'),
          subtitle: Text(dark ? '深色表面折叠为纯黑，OLED 更省电' : '切到深色模式后才可开启'),
          leading: const GlyphIcon(AppGlyphs.pureBlack),
          value: enabled,
          onChanged: dark
              ? (value) => ref.read(pureBlackProvider.notifier).toggle(value)
              : null,
        ),
      ],
    );
  }
}

/// 底栏样式：浮条 / 普通。
class _BottomBarStyleSection extends ConsumerWidget {
  const _BottomBarStyleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(bottomBarStyleProvider);
    final scheme = context.colorScheme;
    final glass = ref.watch(liquidGlassModeProvider).enabled;
    Widget thumb(BottomBarStyle value) => miniScreenThumb(
      colorScheme: scheme,
      floatingBar: value.isFloating,
      liquidGlass: glass,
    );
    return PreviewChoiceGroup<BottomBarStyle>(
      info: const Info(label: '底栏样式', glyph: AppGlyphs.dashboard),
      value: style,
      choices: [
        for (final value in BottomBarStyle.values)
          PreviewChoice(
            value: value,
            label: value.label,
            description: value.isFloating
                ? '浮在页面之上，内容从它下面透出'
                : '贴底排列，页面内容到它为止',
            pictogram: thumb(value),
          ),
      ],
      onChanged: (value) =>
          ref.read(bottomBarStyleProvider.notifier).select(value),
      footer: '浮条会盖住页面最后一行，页面正文统一留出浮条高度的空白。',
    );
  }
}

/// tab 切换动画：四种，缩略图停在切换的半途，能看出「怎么动」。
class _TabTransitionSection extends ConsumerWidget {
  const _TabTransitionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transition = ref.watch(tabTransitionProvider);
    final scheme = context.colorScheme;
    final floating = ref.watch(bottomBarStyleProvider).isFloating;
    final glass = ref.watch(liquidGlassModeProvider).enabled;
    Widget thumb(TabTransition value) => miniScreenThumb(
      colorScheme: scheme,
      floatingBar: floating,
      liquidGlass: glass,
      selected: 1,
      previous: value == TabTransition.none ? null : 0,
      progress: value == TabTransition.none ? 1 : 0.55,
      transition: value,
    );
    return PreviewChoiceGroup<TabTransition>(
      info: const Info(label: 'tab 切换动画', glyph: AppGlyphs.motion),
      value: transition,
      choices: [
        for (final value in TabTransition.values)
          PreviewChoice(
            value: value,
            label: value.label,
            pictogram: thumb(value),
          ),
      ],
      onChanged: (value) =>
          ref.read(tabTransitionProvider.notifier).select(value),
      footer: '缩略图停在切换的半途；上面的大预览可以直接点底栏试手感。',
    );
  }
}

/// Liquid 玻璃：关闭 / 标准 / 极致，质量档位决定折射精度。
class _LiquidGlassSection extends ConsumerWidget {
  const _LiquidGlassSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(liquidGlassModeProvider);
    final scheme = context.colorScheme;
    Widget thumb(LiquidGlassMode value) => miniScreenThumb(
      colorScheme: scheme,
      floatingBar: true,
      liquidGlass: value.enabled,
    );
    return PreviewChoiceGroup<LiquidGlassMode>(
      info: const Info(label: 'Liquid 玻璃', glyph: AppGlyphs.liquidGlass),
      value: mode,
      choices: [
        for (final value in LiquidGlassMode.values)
          PreviewChoice(
            value: value,
            label: value.label,
            description: switch (value) {
              LiquidGlassMode.none => '纯实色，兼容性最好',
              LiquidGlassMode.standard => '标准折射与模糊，多数机型流畅',
              LiquidGlassMode.ultra => '逐帧采样背景，观感最好也最费电',
            },
            pictogram: thumb(value),
          ),
      ],
      onChanged: (value) =>
          ref.read(liquidGlassModeProvider.notifier).select(value),
      footer: '玻璃只作用于浮条与其上的按钮；普通底栏始终是实色。',
    );
  }
}

/// 字体族入口：一行，点进 `/font-family`。
class _FontFamilyEntry extends StatelessWidget {
  const _FontFamilyEntry({required this.family});

  final String? family;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return generateSection(
      title: '字体',
      footer: '字体只在当前设备上生效：选择未安装的字族会静默回退到系统字体。',
      items: [
        ListItem(
          title: const Text('字体族'),
          subtitle: Text(family ?? '系统默认'),
          leading: const GlyphIcon(AppGlyphs.font),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Text(
                'Aa',
                style: AppTextStyle.headline.of(context).copyWith(
                  fontFamily: family,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const GlyphIcon(AppGlyphs.chevronForward, size: 20),
            ],
          ),
          onTap: () => context.push(SystemPaths.fontFamily),
        ),
      ],
    );
  }
}

/// 字号：滑杆 + 实时百分比。
class _TextScaleSection extends ConsumerWidget {
  const _TextScaleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(textScaleProvider);
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListHeader(title: '字号'),
        CommonCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 4,
            children: [
              Row(
                children: [
                  GlyphIcon(
                    AppGlyphs.textSize,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '全局文本缩放',
                      style: context.listTitleStyle,
                    ),
                  ),
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
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '只缩放字号，不改变间距比例；$minTextScale–$maxTextScale 之外'
                  '会把浮条与统计带挤出边界，因此被钳住。',
                  style: context.listCaptionStyle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 重置：危险色按钮 + 确认弹窗。
class _ResetSection extends ConsumerWidget {
  const _ResetSection();

  Future<void> _handleReset(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '重置外观设置',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('重置'),
          ),
        ],
        child: const Text('将把主题色、纯黑、底栏样式、tab 动画、玻璃、字体与字号'
            '全部恢复为默认值。该操作不可撤销。'),
      ),
    );
    if (confirmed != true) {
      return;
    }
    ref.read(paletteProvider.notifier).select(AppPalette.blue);
    ref.read(pureBlackProvider.notifier).toggle(false);
    ref.read(textScaleProvider.notifier).set(1);
    ref.read(customPrimaryColorProvider.notifier).clear();
    ref.read(bottomBarStyleProvider.notifier).select(BottomBarStyle.floating);
    ref.read(tabTransitionProvider.notifier).select(TabTransition.slide);
    ref.read(liquidGlassModeProvider.notifier).select(LiquidGlassMode.none);
    ref.read(selectedFontFamilyProvider.notifier).select(null);
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('外观设置已恢复默认'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1600),
      ),
    );
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
          ),
          onPressed: () => _handleReset(context, ref),
          child: const Text('重置外观设置'),
        ),
      ),
    );
  }
}

part of 'demo_page.dart';

/// 按钮分区：验证 [TonalButton] 三档尺寸、[TonalButtonGroup] 的共享胶囊底、
/// Material 三种原生按钮在本主题下的形态，以及 [MoreActionButton] 的
/// 「更多操作」整行入口。
///
/// 三档尺寸并排是必要的：44/36/32 的差异靠单看一张截图判断不出来，
/// 但并排时一旦有一档高度漂移，胶囊的垂直居中会立刻歪。
class _DemoButtonSection extends StatelessWidget {
  const _DemoButtonSection();

  @override
  Widget build(BuildContext context) {
    return _DemoSectionBody(
      children: [
        const _DemoLabel('TonalButton 三档', trailing: 'TonalButtonSize'),
        const _DemoTonalSizes(),
        const _DemoLabel('带字形', trailing: 'TonalButton(glyph:)'),
        const _DemoTonalGlyphs(),
        const _DemoLabel('TonalButtonGroup', trailing: '共享一个胶囊底'),
        const _DemoTonalGroups(),
        const _DemoLabel('Material 原生按钮', trailing: 'Filled / Outlined / Text'),
        const _DemoMaterialButtons(),
        const _DemoLabel('禁用态', trailing: 'onPressed: null'),
        const _DemoDisabledButtons(),
        const _DemoLabel('MoreActionButton', trailing: '整行「更多」入口'),
        _DemoMoreActions(),
      ],
    );
  }
}

/// 三档尺寸：bar 44（工具栏）、section 36（卡片底部）、compact 32（行内）。
class _DemoTonalSizes extends StatelessWidget {
  const _DemoTonalSizes();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final size in TonalButtonSize.values)
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TonalButton(
                    size: size,
                    label: '${size.name} ${size.button.toStringAsFixed(0)}',
                    onPressed: () {},
                  ),
                ),
              ),
              Text(
                'icon ${size.icon.toStringAsFixed(0)}',
                style: AppTextStyle.caption2.of(context).copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'JetBrainsMono',
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// 带字形的三种：字形按 size 自动取 24/20/20。
class _DemoTonalGlyphs extends StatelessWidget {
  const _DemoTonalGlyphs();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TonalButton(
          size: TonalButtonSize.bar,
          glyph: AppGlyphs.add,
          label: '新建',
          onPressed: () {},
        ),
        TonalButton(
          size: TonalButtonSize.section,
          glyph: AppGlyphs.sync,
          label: '同步',
          onPressed: () {},
        ),
        TonalButton(
          size: TonalButtonSize.compact,
          glyph: AppGlyphs.copy,
          label: '复制',
          onPressed: () {},
        ),
      ],
    );
  }
}

/// 按钮组：三档各一组。组内按钮的按下反馈由组统一接管（同按一个按钮），
/// 所以连按边缘时不该出现两个按钮同时亮起。
class _DemoTonalGroups extends StatelessWidget {
  const _DemoTonalGroups();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final size in TonalButtonSize.values)
          Row(
            spacing: 10,
            children: [
              TonalButtonGroup(
                size: size,
                children: [
                  TonalButton(
                    size: size,
                    glyph: AppGlyphs.delete,
                    label: '清除',
                    onPressed: () {},
                  ),
                  TonalButton(
                    size: size,
                    glyph: AppGlyphs.refresh,
                    label: '刷新',
                    onPressed: () {},
                  ),
                  TonalButton(
                    size: size,
                    glyph: AppGlyphs.export,
                    label: '导出',
                    onPressed: () {},
                  ),
                ],
              ),
              Expanded(
                child: Text(
                  size.name,
                  textAlign: TextAlign.end,
                  style: AppTextStyle.caption2.of(context).copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Material 原生三种按钮：由 [TonalButtonTheme] 之外的默认主题渲染，
/// 用来确认本项目的 theme 没有把它们改成胶囊之外的怪形状。
class _DemoMaterialButtons extends StatelessWidget {
  const _DemoMaterialButtons();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () {},
                child: const Text('Filled'),
              ),
            ),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () {},
                child: const Text('Tonal'),
              ),
            ),
          ],
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('Outlined'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () {},
                child: const Text('Text'),
              ),
            ),
          ],
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {},
                icon: const GlyphIcon(AppGlyphs.check, size: 18),
                label: const Text('Filled.icon'),
              ),
            ),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const GlyphIcon(AppGlyphs.close, size: 18),
                label: const Text('Outlined.icon'),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('destructive'),
            ),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
              child: const Text('error'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 禁用态：前景应降到 38% 不透明度，且不响应点按。
class _DemoDisabledButtons extends StatelessWidget {
  const _DemoDisabledButtons();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TonalButton(
          size: TonalButtonSize.section,
          glyph: AppGlyphs.block,
          label: '禁用 Tonal',
          onPressed: null,
        ),
        const TonalButton(
          size: TonalButtonSize.section,
          label: '禁用无字形',
          onPressed: null,
        ),
        const FilledButton(onPressed: null, child: Text('禁用 Filled')),
        const OutlinedButton(onPressed: null, child: Text('禁用 Outlined')),
        const TextButton(onPressed: null, child: Text('禁用 Text')),
      ],
    );
  }
}

/// 「更多操作」整行：本身就是一张卡片 + 一行列表，所以单独占满宽度。
class _DemoMoreActions extends StatelessWidget {
  const _DemoMoreActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        MoreActionButton(
          label: '更多操作（默认箭头）',
          onPressed: () => _demoToast(context, 'MoreActionButton'),
        ),
        MoreActionButton(
          label: '自定义 trailing',
          trailing: const GlyphIcon(AppGlyphs.settings, size: 18),
          onPressed: () => _demoToast(context, 'MoreActionButton · trailing'),
        ),
        MoreActionButton(label: '禁用态', onPressed: null),
      ],
    );
  }
}

/// 画廊里所有「点了应该发生点什么」的地方统一走这里：只弹一个 SnackBar，
/// 不导航、不改全局状态，避免验收时误触进别的页面。
void _demoToast(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1200),
    ),
  );
}

part of 'demo_page.dart';

/// Buttons: the three [TonalButton] sizes, the shared capsule of
/// [TonalButtonGroup], the Material buttons and [MoreActionButton].
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

/// Three sizes: bar 44 (toolbars), section 36 (card footers), compact 32 (inline).
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
                style: AppTextStyle.caption2
                    .of(context)
                    .copyWith(
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

/// The three glyph variants; the glyph follows size at 24/20/20.
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
                  style: AppTextStyle.caption2
                      .of(context)
                      .copyWith(
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
              child: TextButton(onPressed: () {}, child: const Text('Text')),
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

/// Disabled state: foreground drops to 38% opacity and taps are ignored.
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

/// Shared gallery tap handler: a SnackBar only, so reviewing never navigates away.
void _demoToast(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1200),
    ),
  );
}
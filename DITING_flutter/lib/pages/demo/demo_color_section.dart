part of 'demo_page.dart';

/// 颜色与表面分区：验证四级表面色阶、九种种子色、[ColorStyle] 四种取色风格，
/// 以及 [ColorScheme.toPureBlack] 的纯黑折叠。
///
/// 色块下面一律标出十六进制值：色偏是最难凭肉眼判定的回归，有 hex 就能直接
/// 和设计稿核对。角色色的成对对比见 [_DemoSchemeSection]。
class _DemoColorSection extends StatelessWidget {
  const _DemoColorSection();

  @override
  Widget build(BuildContext context) {
    return _DemoSectionBody(
      children: [
        const _DemoLabel('SurfaceLevel 四级', trailing: 'colorOf(scheme)'),
        const _DemoSurfaceLevels(),
        const _DemoLabel(
          'surfaceLevel / raisedSurfaceLevel',
          trailing: 'context 扩展',
        ),
        const _DemoSurfaceContext(),
        const _DemoLabel('AppPalette 九个种子色', trailing: '设置页九选一'),
        const _DemoPaletteSeeds(),
        const _DemoLabel('ColorStyle 四种取色风格', trailing: '同一颗种子'),
        const _DemoColorStyles(),
        const _DemoLabel('toPureBlack', trailing: '深色折叠为纯黑'),
        const _DemoPureBlack(),
        const ListFooter(
          text: '四级表面在深色模式下是逐级「提亮」，不是逐级压暗；'
              '把 page 当成最暗一层看，card/block/inset 才会往上浮。',
        ),
      ],
    );
  }
}

/// 四级表面：page → card → block → inset。深色模式下这四级是往上「提亮」，
/// 而不是往下压暗，所以必须并排看才能判断层级是否读得出来。
class _DemoSurfaceLevels extends StatelessWidget {
  const _DemoSurfaceLevels();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Row(
      spacing: 8,
      children: [
        for (final level in SurfaceLevel.values)
          Expanded(
            child: Column(
              spacing: 6,
              children: [
                Container(
                  height: 62,
                  decoration: ShapeDecoration(
                    color: level.colorOf(colorScheme),
                    shape: AppShape.md,
                  ),
                  child: Center(
                    child: Text(
                      level.name,
                      style: AppTextStyle.caption1.of(
                        context,
                        emphasized: true,
                      ),
                    ),
                  ),
                ),
                Text(
                  level.colorOf(colorScheme).hex,
                  style: AppTextStyle.caption2.of(context).copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 当前所处的表面层级，以及它往上一级是什么颜色。这决定「卡片里的卡片」
/// 该用哪个填充色——本页正文在 page 上，所以 raised 是 card。
class _DemoSurfaceContext extends StatelessWidget {
  const _DemoSurfaceContext();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final level = context.surfaceLevel;
    final raised = context.raisedSurfaceLevel;
    return CommonCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: _DemoColorTile(
              label: 'surfaceLevel',
              caption: level.name,
              color: level.colorOf(colorScheme),
            ),
          ),
          const GlyphIcon(AppGlyphs.chevronForward, size: 16),
          Expanded(
            child: _DemoColorTile(
              label: 'raisedSurfaceLevel',
              caption: raised.name,
              color: raised.colorOf(colorScheme),
            ),
          ),
        ],
      ),
    );
  }
}

/// 九个种子色。种子本身只是输入，真正上屏的是 HCT 推导后的色板，所以这里
/// 同时给出种子圆点和「用它生成的 primary」——两者不一样才是对的。
class _DemoPaletteSeeds extends StatelessWidget {
  const _DemoPaletteSeeds();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final palette in AppPalette.values)
              _DemoSeedDot(
                label: palette.label,
                seed: palette.swatch,
                derived: seededColorScheme(
                  seedColor: palette.effectiveSeed,
                  brightness: brightness,
                ).primary,
              ),
          ],
        ),
        Text(
          '左半为种子色，右半为 HCT 推导出的 primary。',
          style: AppTextStyle.caption2.of(context).copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DemoSeedDot extends StatelessWidget {
  const _DemoSeedDot({
    required this.label,
    required this.seed,
    required this.derived,
  });

  final String label;
  final Color seed;
  final Color derived;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return SizedBox(
      width: 64,
      child: Column(
        spacing: 4,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              spacing: 2,
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: seed,
                      shape: AppShape.full,
                    ),
                  ),
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: derived,
                      shape: AppShape.full,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.caption2.of(context).copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 四种取色风格：vivid/tinted 走 content 变体并自己压色度，soft 走 tonalSpot，
/// monochrome 走 monochrome。同一颗种子下四行应当明显不同，否则说明
/// `seededColorScheme(style:)` 的开关没接上。
class _DemoColorStyles extends StatelessWidget {
  const _DemoColorStyles();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final brightness = Theme.of(context).brightness;
    return Column(
      spacing: 6,
      children: [
        for (final style in ColorStyle.values)
          Row(
            spacing: 8,
            children: [
              SizedBox(
                width: 82,
                child: Text(
                  style.name,
                  style: AppTextStyle.caption1.of(context).copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ),
              for (final role in _colorStyleRoles)
                Expanded(
                  child: _DemoStyleSwatch(
                    color: role.$2(
                      seededColorScheme(
                        seedColor: const Color(0xFF007AFF),
                        brightness: brightness,
                        style: style,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// 每种风格取哪几个角色来看：primary 看主色，container 看容器色阶，
/// surfaceContainer 看中性色被种子带偏了多少。
const _colorStyleRoles = <(String, Color Function(ColorScheme))>[
  ('primary', _rolePrimary),
  ('primaryContainer', _rolePrimaryContainer),
  ('surfaceContainer', _roleSurfaceContainer),
  ('onSurfaceVariant', _roleOnSurfaceVariant),
];

Color _rolePrimary(ColorScheme scheme) => scheme.primary;

Color _rolePrimaryContainer(ColorScheme scheme) => scheme.primaryContainer;

Color _roleSurfaceContainer(ColorScheme scheme) => scheme.surfaceContainer;

Color _roleOnSurfaceVariant(ColorScheme scheme) => scheme.onSurfaceVariant;

class _DemoStyleSwatch extends StatelessWidget {
  const _DemoStyleSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: ShapeDecoration(color: color, shape: AppShape.sm),
    );
  }
}

/// 纯黑折叠：深色主题下 surface 系列被压到 `#000000`，其余角色不动。
/// 这一行必须在深色主题下看；浅色主题里 `toPureBlack` 是恒等变换。
class _DemoPureBlack extends StatelessWidget {
  const _DemoPureBlack();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final folded = scheme.toPureBlack(true);
    final isDark = scheme.brightness == Brightness.dark;
    final before = scheme.surface;
    final after = folded.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: _DemoColorTile(
                label: 'surface',
                caption: before.hex,
                color: before,
              ),
            ),
            const GlyphIcon(AppGlyphs.chevronForward, size: 16),
            Expanded(
              child: _DemoColorTile(
                label: 'toPureBlack(true)',
                caption: after.hex,
                color: after,
              ),
            ),
          ],
        ),
        Text(
          isDark
              ? '深色主题：surface 已折叠为纯黑，容器色阶整体下移 surface 的色度。'
              : '浅色主题：toPureBlack 是恒等变换，切换深色模式后再看这一行。',
          style: AppTextStyle.caption2.of(context).copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

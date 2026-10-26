part of 'demo_page.dart';

/// Colors and surfaces: four surface levels, nine seed colors, four [ColorStyle] variants
/// and the [ColorScheme.toPureBlack] collapse. Every swatch prints its hex, since hue drift
/// is the hardest regression to judge by eye.
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
          text:
              '四级表面在深色模式下是逐级「提亮」，不是逐级压暗；'
              '把 page 当成最暗一层看，card/block/inset 才会往上浮。',
        ),
      ],
    );
  }
}

/// Dark mode brightens the four surface levels instead of darkening, so they read side by side.
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
                  style: AppTextStyle.caption2
                      .of(context)
                      .copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: appMonospaceFontFamily,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The current surface level and the one step up, which decides nested card fills.
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
          style: AppTextStyle.caption2
              .of(context)
              .copyWith(color: colorScheme.onSurfaceVariant),
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
            style: AppTextStyle.caption2
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Four color styles: vivid and tinted use the content variant with their own
/// chroma, soft uses tonalSpot, monochrome uses monochrome.
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
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: appMonospaceFontFamily,
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

/// Roles shown per style: primary for the main color, container for the container
/// ramp and surfaceContainer for how far the seed tints neutrals.
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

/// Pure black collapse: dark mode pushes the surface ramp to `#000000`; light mode
/// leaves `toPureBlack` as identity.
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
          style: AppTextStyle.caption2
              .of(context)
              .copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
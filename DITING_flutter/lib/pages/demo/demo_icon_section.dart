part of 'demo_page.dart';

/// 图标分区：验证 [GlyphIcon] 的描边宽度、尺寸档位与填色，[AnimatedGlyph]
/// 的填充过渡，以及 [CaptionIcon] 的角标定位。
///
/// 图标全量铺开的价值在于「成对」：eye/eyeOff、lock/lockOpen、
/// playPause(0)/playPause(1) 这些互补字形必须笔画密度一致，只挑一个看是查不出
/// 来的。
class _DemoIconSection extends StatelessWidget {
  const _DemoIconSection();

  @override
  Widget build(BuildContext context) {
    return _DemoSectionBody(
      children: [
        const _DemoLabel('尺寸档位', trailing: 'GlyphIcon(size:)'),
        const _DemoGlyphSizes(),
        const _DemoLabel('填色与描边', trailing: 'fill: 0 → 1'),
        const _DemoGlyphFills(),
        const _DemoLabel('AnimatedGlyph', trailing: '填充状态切换动画'),
        const _DemoAnimatedGlyphRow(),
        const _DemoLabel('按参数生成的字形', trailing: 'sidebar / playPause / backFor'),
        _DemoParametricGlyphs(),
        const _DemoLabel('CaptionIcon', trailing: 'CaptionGlyph 四枚窗口按钮'),
        const _DemoCaptionIcons(),
        _DemoLabel(
          'AppGlyphs 全量 ${demoGlyphCatalog.length} 个',
          trailing: '点按查看名字',
        ),
        const _DemoGlyphGrid(),
      ],
    );
  }
}

/// 窗口标题栏四枚字形：10×10、1px 描边、半像素对齐，放大看不能糊。
class _DemoCaptionIcons extends StatelessWidget {
  const _DemoCaptionIcons();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Row(
      spacing: 10,
      children: [
        for (final glyph in CaptionGlyph.values)
          Expanded(
            child: Column(
              spacing: 6,
              children: [
                Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: context.raisedSurfaceLevel.colorOf(colorScheme),
                    shape: AppShape.xs,
                  ),
                  child: IconTheme(
                    data: IconThemeData(color: colorScheme.onSurface),
                    child: CaptionIcon(glyph),
                  ),
                ),
                Text(
                  glyph.name,
                  style: AppTextStyle.caption2
                      .of(context)
                      .copyWith(
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

/// 四档尺寸并排：16 用于行尾箭头，20 用于卡片图标，24 是默认，32 用于空态。
class _DemoGlyphSizes extends StatelessWidget {
  const _DemoGlyphSizes();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Row(
      spacing: 10,
      children: [
        for (final size in const [16.0, 20.0, 24.0, 32.0, 44.0])
          Expanded(
            child: Column(
              spacing: 6,
              children: [
                SizedBox(
                  height: 48,
                  child: Center(
                    child: GlyphIcon(
                      AppGlyphs.palette,
                      size: size,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                Text(
                  size.toStringAsFixed(0),
                  style: AppTextStyle.caption2
                      .of(context)
                      .copyWith(
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

/// fill 从 0 到 1 的中间态：`GlyphIcon(fill:)` 支持小数，用于开关图标
/// 在滑动过程中跟着进度填充。
class _DemoGlyphFills extends StatelessWidget {
  const _DemoGlyphFills();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Row(
      spacing: 10,
      children: [
        for (final fill in const [0.0, 0.25, 0.5, 0.75, 1.0])
          Expanded(
            child: Column(
              spacing: 6,
              children: [
                SizedBox(
                  height: 40,
                  child: Center(
                    child: GlyphIcon(
                      AppGlyphs.star,
                      fill: fill,
                      size: 26,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                Text(
                  fill.toStringAsFixed(2),
                  style: AppTextStyle.caption2
                      .of(context)
                      .copyWith(
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

/// 动画填充：点一下在实心与描边之间过渡，用来验证 [AnimatedGlyph] 的
/// 过渡时长与曲线是否和主题的 motionDuration 对齐。
class _DemoAnimatedGlyphRow extends StatefulWidget {
  const _DemoAnimatedGlyphRow();

  @override
  State<_DemoAnimatedGlyphRow> createState() => _DemoAnimatedGlyphRowState();
}

class _DemoAnimatedGlyphRowState extends State<_DemoAnimatedGlyphRow> {
  bool _filled = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onPressed: () => setState(() => _filled = !_filled),
      child: Row(
        spacing: 12,
        children: [
          AnimatedGlyph(glyph: AppGlyphs.star, filled: _filled),
          Expanded(
            child: Text(
              _filled ? 'filled: true' : 'filled: false',
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'JetBrainsMono',
                  ),
            ),
          ),
          Text(
            '点按切换',
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

/// 三个按参数生成的字形：sidebar 的进度、playPause 的进度、backFor 的平台。
class _DemoParametricGlyphs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, glyph) in demoParametricGlyphs)
          SizedBox(
            width: 108,
            child: Column(
              spacing: 4,
              children: [
                Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: context.raisedSurfaceLevel.colorOf(colorScheme),
                    shape: AppShape.sm,
                  ),
                  child: GlyphIcon(glyph, size: 24),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.caption2
                      .of(context)
                      .copyWith(
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

/// 全量字形网格：每格一个图标 + 名字。名字用等宽体且强制两行，
/// 保证网格行高一致，不会因为名字长短跳动。
class _DemoGlyphGrid extends StatelessWidget {
  const _DemoGlyphGrid();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (name, glyph) in demoGlyphCatalog)
          SizedBox(
            width: 72,
            child: Column(
              spacing: 3,
              children: [
                Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: context.raisedSurfaceLevel.colorOf(colorScheme),
                    shape: AppShape.sm,
                  ),
                  child: GlyphIcon(glyph, size: 22),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.caption2
                      .of(context)
                      .copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'JetBrainsMono',
                        fontSize: 9,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

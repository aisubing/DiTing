/// 主题色区块与色板圆点（`theme_page.dart` 的 part 文件）。
///
/// 从 `theme_sections.dart` 拆出：颜色选择器自带取色入口、圆点与亮度判定，
/// 是这一族里最长的一块；放在一起会顶到 550 行上限。
part of 'theme_page.dart';

/// 主题色：九个色板圆点 + 「自定义」入口。
class _PrimaryColorSection extends ConsumerWidget {
  const _PrimaryColorSection({required this.seed});

  final Color seed;

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final color = await showSheet<Color>(
      context: context,
      props: const SheetProps(detents: [0.88]),
      builder: (_) => CustomColorSheet(initial: seed),
    );
    if (color == null || !context.mounted) {
      return;
    }
    ref.read(customPrimaryColorProvider.notifier).select(color);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final custom = ref.watch(customPrimaryColorProvider);
    final colorScheme = context.colorScheme;
    return SectionBlock(
      title: '主题色',
      footer: '色板只提供种子，上屏的是 HCT 推导出的整套角色色。自定义色只影响'
          '预览与缩略图：演示层的应用级主题仍跟随九色板。',
      child: CommonCard(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 8,
              children: [
                for (final option in AppPalette.values)
                  _PaletteDot(
                    color: option.swatch,
                    label: option.label,
                    selected: custom == null && option == palette,
                    onPressed: () {
                      ref.read(customPrimaryColorProvider.notifier).clear();
                      ref.read(paletteProvider.notifier).select(option);
                    },
                  ),
                _CustomColorDot(
                  color: custom,
                  onPressed: () => _openSheet(context, ref),
                ),
              ],
            ),
            Row(
              spacing: 6,
              children: [
                GlyphIcon(
                  AppGlyphs.eyedropper,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Text(
                    custom == null
                        ? '点击调色板图标可用色相 / 饱和度自行取色'
                        : '自定义色 ${_hex(custom)}（点一下可继续调整）',
                    style: context.listCaptionStyle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _hex(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// 一个色板圆点。选中时外圈加一道主色描边，不靠颜色本身区分。
class _PaletteDot extends StatelessWidget {
  const _PaletteDot({
    required this.color,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: midDuration,
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: ShapeDecoration(
            shape: AppShape.circle,
            color: selected ? colorScheme.primary : Colors.transparent,
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: AppShape.circle.copyWith(
                side: BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
              color: color,
            ),
            child: selected
                ? GlyphIcon(
                    AppGlyphs.check,
                    size: 18,
                    fill: 1,
                    color: _onColor(color),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// 自定义取色入口：已选过就显示那个颜色，否则显示取色图标。
class _CustomColorDot extends StatelessWidget {
  const _CustomColorDot({required this.color, required this.onPressed});

  final Color? color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final color = this.color;
    return Semantics(
      button: true,
      label: '自定义颜色',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: ShapeDecoration(
            shape: AppShape.circle,
            color: color == null ? Colors.transparent : colorScheme.primary,
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: AppShape.circle.copyWith(
                side: BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
              color: color ??
                  context.raisedSurfaceLevel.colorOf(colorScheme),
            ),
            child: color == null
                ? GlyphIcon(
                    AppGlyphs.eyedropper,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  )
                : GlyphIcon(
                    AppGlyphs.check,
                    size: 18,
                    fill: 1,
                    color: _onColor(color),
                  ),
          ),
        ),
      ),
    );
  }
}

/// 深色底配白字、浅色底配黑字——取色板可能选到任何颜色，用亮度判断。
Color _onColor(Color color) =>
    color.computeLuminance() > 0.55 ? Colors.black : Colors.white;

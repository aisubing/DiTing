part of 'settings_page.dart';

/// 外观分组：日夜模式、主题色、纯黑、字号。
///
/// 这一组是「同一份状态喂给两条渲染路径」的典型：改色板 / 纯黑会重建整套
/// `ThemeData`（`lib/app/theme/manager.dart`），而改字号只是换
/// `MediaQuery.textScaler`。所以字号用滑杆连续调不会闪主题，色板必须等选完
/// 才提交——这也是色板做成「点一下就落定」而不是拖拽的原因。
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final pureBlack = ref.watch(pureBlackProvider);
    final textScale = ref.watch(textScaleProvider);
    // 纯黑是深色方案的折叠，浅色下没有可折叠的表面，因此直接禁用而不是隐藏：
    // 隐藏会让用户以为这项不存在，禁用 + 说明才知道「先切深色」。
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        generateSection(
          title: '外观',
          footer: '纯黑只在深色模式下生效：它把深色表面折叠为 #000，浅色主题没有对应物。',
          items: [
            ListItem<AppThemeMode>.options(
              title: const Text('日夜模式'),
              subtitle: const Text('跟随系统时由系统深色开关决定'),
              leading: const GlyphIcon(AppGlyphs.sun),
              options: AppThemeMode.values,
              value: themeMode,
              textBuilder: (mode) => mode.label,
              onChanged: (mode) =>
                  ref.read(themeModeProvider.notifier).select(mode),
            ),
            ListItem.toggle(
              title: const Text('纯黑'),
              subtitle: Text(dark ? '深色表面折叠为纯黑，OLED 更省电' : '切到深色模式后才可开启'),
              leading: const GlyphIcon(AppGlyphs.pureBlack),
              value: pureBlack,
              onChanged: dark
                  ? (value) => ref.read(pureBlackProvider.notifier).toggle(value)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        const SectionBlock(
          title: '主题色',
          footer: '色板只提供种子，上屏的是 HCT 推导出的整套角色色；'
              '「跟随系统」在纯演示层退化为默认蓝。',
          child: _PalettePicker(),
        ),
        const SizedBox(height: 6),
        const ListHeader(title: '字号'),
        _SliderCard(
          label: '全局文本缩放',
          leading: AppGlyphs.textSize,
          value: textScale,
          min: minTextScale,
          max: maxTextScale,
          divisions: 6,
          valueLabel: '${textScale.toStringAsFixed(1)}×',
          hint: '只缩放字号，不改变间距比例；浮条与统计带按缩放后的行高重新排版。',
          onChanged: (value) => ref.read(textScaleProvider.notifier).set(value),
        ),
        const ListFooter(
          text: '缩放会被钳在 $minTextScale–$maxTextScale 之间：再小读不清、再大会把'
              '浮条和统计带挤出边界。',
        ),
      ],
    );
  }
}

/// 九个色板圆点。
///
/// 圆点本身就是这一项的控件形态（上游 `ThemeColorSettingsScreen` 同款），
/// 用 `ListItem.options` 反而看不出颜色，所以这里不套行组件；但外层仍然是
/// `SectionBlock` + `CommonCard`，标题与脚注和其他分组保持同一节奏。
class _PalettePicker extends ConsumerWidget {
  const _PalettePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    return CommonCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final option in AppPalette.values)
                _PaletteDot(
                  palette: option,
                  selected: option == palette,
                  onPressed: () =>
                      ref.read(paletteProvider.notifier).select(option),
                ),
            ],
          ),
          Text('当前：${palette.label}', style: context.listSubtitleStyle),
        ],
      ),
    );
  }
}

/// 单个色板圆点：选中时放大并盖一个对勾。
///
/// 对勾颜色按种子色的亮度取黑或白——固定用白色会在「麦穗金」这类浅色上消失。
class _PaletteDot extends StatelessWidget {
  const _PaletteDot({
    required this.palette,
    required this.selected,
    required this.onPressed,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final checkColor = palette.swatch.computeLuminance() > 0.55
        ? Colors.black
        : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: palette.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: midDuration,
                curve: Curves.easeOut,
                width: selected ? 40 : 32,
                height: selected ? 40 : 32,
                decoration: ShapeDecoration(
                  shape: AppShape.circle,
                  color: palette.swatch,
                  shadows: [
                    BoxShadow(
                      color: palette.swatch.withValues(alpha: 0.28),
                      blurRadius: selected ? 12 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
              if (selected)
                GlyphIcon(
                  AppGlyphs.check,
                  size: 20,
                  fill: 1,
                  color: checkColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「标题 + 数值 + 滑杆」的通用块。
///
/// 滑杆不是列表行，没法塞进 `ListItem` 的七种构造器，因此单独做成一张卡片；
/// 但左右缩进、行高节奏必须和 `ListItem` 一致，否则一页里两种密度会打架。
class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
    this.leading,
    this.hint,
  });

  final String label;
  final Glyph? leading;
  final double value;
  final double min;
  final double max;
  final int divisions;

  /// 滑杆右上角的读数，同时作为拖动时气泡里的文字。
  final String valueLabel;
  final ValueChanged<double> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: CommonCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              spacing: 10,
              children: [
                if (leading case final leading?)
                  GlyphIcon(leading, size: 20, color: colorScheme.primary),
                Expanded(child: Text(label, style: context.listTitleStyle)),
                Text(
                  valueLabel,
                  style: context.listSubtitleStyle.copyWith(
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              onChanged: onChanged,
            ),
            if (hint case final hint?)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(hint, style: context.listCaptionStyle),
              ),
          ],
        ),
      ),
    );
  }
}

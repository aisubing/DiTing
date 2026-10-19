part of 'theme_page.dart';

/// 自定义取色浮层（上游 `_CustomColorSheet`）。
///
/// 上游用色轮 + 十六进制输入框；这里换成「色相条 + 饱和度条」两个滑杆：
/// 色轮要自己画并处理命中测试，收益只是好看一点，而滑杆在演示里能更直接地
/// 说明「种子色是怎么来的」。吸管徽标保留为装饰，不接平台取色器。
class CustomColorSheet extends StatefulWidget {
  const CustomColorSheet({super.key, required this.initial});

  final Color initial;

  @override
  State<CustomColorSheet> createState() => _CustomColorSheetState();
}

class _CustomColorSheetState extends State<CustomColorSheet> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  Color get _color => _hsv.toColor();

  void _setHue(double hue) => setState(() {
    _hsv = _hsv.withHue(hue);
  });

  void _setSaturation(double saturation) => setState(() {
    _hsv = _hsv.withSaturation(saturation);
  });

  void _setValue(double value) => setState(() {
    _hsv = _hsv.withValue(value);
  });

  @override
  Widget build(BuildContext context) {
    final seed = _color;
    final light = demoColorScheme(seed: seed, brightness: Brightness.light);
    final dark = demoColorScheme(seed: seed, brightness: Brightness.dark);
    return CommonScaffold(
      title: '自定义主题色',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '使用该颜色',
        onPressed: () => Navigator.of(context).pop(seed),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _ColorHero(color: seed, hsv: _hsv),
          const SizedBox(height: 16),
          _RampSlider(
            label: '色相',
            value: _hsv.hue,
            max: 360,
            thumbColor: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
            // 色相条本身要显示整条彩虹，否则拖到哪里没有参照。
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ],
            ),
            onChanged: _setHue,
          ),
          _RampSlider(
            label: '饱和度',
            value: _hsv.saturation,
            max: 1,
            thumbColor: seed,
            gradient: LinearGradient(
              colors: [
                HSVColor.fromAHSV(1, _hsv.hue, 0, _hsv.value).toColor(),
                HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
              ],
            ),
            onChanged: _setSaturation,
          ),
          _RampSlider(
            label: '明度',
            value: _hsv.value,
            max: 1,
            thumbColor: seed,
            gradient: LinearGradient(
              colors: [
                Colors.black,
                HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
              ],
            ),
            onChanged: _setValue,
          ),
          const SizedBox(height: 8),
          Text('实时预览', style: context.cardHeaderStyle),
          const SizedBox(height: 8),
          Row(
            spacing: 12,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SchemePreview(
                  scheme: light,
                  label: '浅色',
                  selected: false,
                  onTap: () {},
                ),
              ),
              Expanded(
                child: _SchemePreview(
                  scheme: dark,
                  label: '深色',
                  selected: true,
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TonalButton(
                  label: '取消',
                  size: TonalButtonSize.section,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TonalButton(
                  label: '确定',
                  glyph: AppGlyphs.check,
                  size: TonalButtonSize.section,
                  onPressed: () => Navigator.of(context).pop(seed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '演示层只取色，不写回应用级主题：确认后色板圆点显示该颜色，'
            '预览与缩略图按它重新推导角色色。',
            style: context.listCaptionStyle,
          ),
        ],
      ),
    );
  }
}

/// 顶部：一个大的色块 + 吸管徽标 + 十六进制文本。
class _ColorHero extends StatelessWidget {
  const _ColorHero({required this.color, required this.hsv});

  final Color color;
  final HSVColor hsv;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(color: color, shape: AppShape.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: AppShape.circle,
              color: Colors.white.withValues(alpha: 0.28),
            ),
            child: GlyphIcon(
              AppGlyphs.eyedropper,
              size: 18,
              color: _onColor(color),
            ),
          ),
          Text(
            _hex(color),
            style: AppTextStyle.title2.of(context, emphasized: true).copyWith(
              color: _onColor(color),
              fontFamily: 'JetBrainsMono',
            ),
          ),
          Text(
            'H ${hsv.hue.round()}° · S ${(hsv.saturation * 100).round()}% · '
            'V ${(hsv.value * 100).round()}%',
            style: AppTextStyle.footnote.of(context).copyWith(
              color: _onColor(color).withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一条带渐变背景的滑杆。
class _RampSlider extends StatelessWidget {
  const _RampSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.thumbColor,
    required this.gradient,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final Color thumbColor;
  final Gradient gradient;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 26,
          child: Row(
            children: [
              Text(label, style: context.listTitleStyle),
              const Spacer(),
              Text(
                max == 360 ? '${value.round()}' : '${(value * 100).round()}%',
                style: context.listSubtitleStyle.copyWith(
                  fontFamily: 'JetBrainsMono',
                ),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 10,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
            thumbColor: thumbColor,
            overlayColor: thumbColor.withValues(alpha: 0.16),
            trackShape: _GradientTrackShape(gradient: gradient),
          ),
          child: Slider(
            value: value.clamp(0, max),
            max: max,
            onChanged: onChanged,
          ),
        ),
        Divider(
          height: 1,
          color: colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ],
    );
  }
}

/// 渐变轨道：`SliderTheme` 没有现成的渐变轨道，自己画一条。
class _GradientTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const _GradientTrackShape({required this.gradient});

  final Gradient gradient;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final canvas = context.canvas;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      Paint()..shader = gradient.createShader(rect),
    );
  }
}

/// 浅色 / 深色两套推导色板的小预览。
class _SchemePreview extends StatelessWidget {
  const _SchemePreview({
    required this.scheme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ColorScheme scheme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final roles = <(String, Color, Color)>[
      ('主色', scheme.primary, scheme.onPrimary),
      ('容器', scheme.primaryContainer, scheme.onPrimaryContainer),
      ('表面', scheme.surface, scheme.onSurface),
    ];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: ShapeDecoration(
          color: scheme.surface,
          shape: selected
              ? AppShape.lg.copyWith(
                  side: BorderSide(color: scheme.primary, width: 2),
                )
              : AppShape.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(
              label,
              style: AppTextStyle.footnote.of(context).copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            for (final (role, background, foreground) in roles)
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                decoration: ShapeDecoration(
                  color: background,
                  shape: AppShape.sm,
                ),
                child: Text(
                  role,
                  style: AppTextStyle.caption1.of(context).copyWith(
                    color: foreground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

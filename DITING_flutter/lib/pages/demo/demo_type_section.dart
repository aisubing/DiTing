part of 'demo_page.dart';

/// 排版分区：验证 13 档字号的字号、行高、字重，以及 [AppTextStyle.custom]
/// 按容器尺寸临时取字的能力。
///
/// 每行同时给出「档名 / 示例字 / 尺寸」，因为字号回归最难用肉眼判断——
/// 17 和 16 摆在一起看不出来，但「body 17/22」这行字会立刻暴露。
class _DemoTypeSection extends StatelessWidget {
  const _DemoTypeSection();

  @override
  Widget build(BuildContext context) {
    return _DemoSectionBody(
      children: [
        const _DemoLabel(
          'AppTextStyle · 13 档',
          trailing: 'size / leading / weight',
        ),
        for (final style in AppTextStyle.values) _DemoTypeRow(style: style),
        const _DemoLabel(
          'custom(context, size:, leading:)',
          trailing: 'AppTextStyle.custom',
        ),
        _DemoCustomTypeRow(),
        const ListFooter(
          text:
              '字形来自 textTheme 的 13 个槽位：display/largeTitle 走 headlineLarge，'
              'body/callout 走 bodyLarge，caption2 走 labelSmall。',
        ),
      ],
    );
  }
}

/// 单档字号：左边档名，中间示例，右边尺寸与字重。
class _DemoTypeRow extends StatelessWidget {
  const _DemoTypeRow({required this.style});

  final AppTextStyle style;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final weight = style.weight.value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 10,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              style.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.caption2
                  .of(context)
                  .copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'JetBrainsMono',
                  ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '谛听 DITING Aa 0123',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.of(context),
              ),
            ),
          ),
          Text(
            '${_trim(style.size)}/${_trim(style.leading)} · w$weight',
            maxLines: 1,
            style: AppTextStyle.caption2
                .of(context)
                .copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'JetBrainsMono',
                ),
          ),
        ],
      ),
    );
  }

  /// 整数尺寸不写小数点，省下两列宽度给示例字。
  static String _trim(double value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';
}

/// 自定义字号：容器多高，字就多大——这是 [AppTextStyle.custom] 的用途，
/// 也是图标内嵌字母、圆形徽标数字唯一正确的取字方式。
class _DemoCustomTypeRow extends StatefulWidget {
  @override
  State<_DemoCustomTypeRow> createState() => _DemoCustomTypeRowState();
}

class _DemoCustomTypeRowState extends State<_DemoCustomTypeRow> {
  double _size = 28;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          spacing: 12,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: colorScheme.primary,
                shape: AppShape.circle,
              ),
              child: Text(
                '7',
                style: AppTextStyle.custom(
                  context,
                  size: _size,
                  leading: _size * 1.1,
                  weight: FontWeight.w700,
                ).copyWith(color: colorScheme.onPrimary),
              ),
            ),
            Expanded(
              child: Text(
                'custom(size: ${_size.toStringAsFixed(0)}, leading: '
                '${(_size * 1.1).toStringAsFixed(0)})',
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'JetBrainsMono',
                    ),
              ),
            ),
          ],
        ),
        Slider(
          value: _size,
          min: 12,
          max: 40,
          divisions: 28,
          label: '${_size.toStringAsFixed(0)} pt',
          onChanged: (value) => setState(() => _size = value),
        ),
      ],
    );
  }
}

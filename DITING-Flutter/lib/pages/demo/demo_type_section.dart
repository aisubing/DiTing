part of 'demo_page.dart';

/// Typography: the 13 steps with size, line height and weight, plus [AppTextStyle.custom]. Each row
/// prints its numbers, since 17 next to 16 is invisible while "body 17/22" exposes a regression.
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

  /// Integer sizes drop the decimal point to save two columns for the sample.
  static String _trim(double value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';
}

/// The text follows the container height, the only correct way to size glyph letters.
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
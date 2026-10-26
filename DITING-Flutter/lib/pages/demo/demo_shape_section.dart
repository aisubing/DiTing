part of 'demo_page.dart';

/// Shapes: the nine [AppCorner] steps, [AppRadius] to [AppShape] and the [AppInputBorder]
/// stroke. Corners are the easiest regression to miss, so all nine sit side by side.
class _DemoShapeSection extends StatelessWidget {
  const _DemoShapeSection();

  @override
  Widget build(BuildContext context) {
    return _DemoSectionBody(
      children: [
        const _DemoLabel(
          'AppCorner 九档',
          trailing: 'AppShape.of(AppRadius.xxx)',
        ),
        const _DemoCornerGrid(),
        const _DemoLabel('AppRadius 组合', trailing: 'all / top / vertical'),
        const _DemoRadiusCombos(),
        const _DemoLabel('AppShape.circle / AppInputBorder', trailing: '特殊形状'),
        const _DemoSpecialShapes(),
        const ListFooter(
          text:
              'AppShape 全部是 RoundedSuperellipseBorder（超椭圆），不是 '
              'BorderRadius.circular 的圆弧——直线段的曲率连续性在这里看得出来。',
        ),
      ],
    );
  }
}

/// `full` uses 1000 for half the short side, so it looks circular but means the corner limit.
class _DemoCornerGrid extends StatelessWidget {
  const _DemoCornerGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final corner in _demoCorners)
          _DemoCornerCell(label: corner.$1, value: corner.$2),
      ],
    );
  }
}

/// The nine (name, value) pairs, taken from [AppCorner] rather than copied.
const _demoCorners = <(String, double)>[
  ('none', AppCorner.none),
  ('xs', AppCorner.xs),
  ('sm', AppCorner.sm),
  ('md', AppCorner.md),
  ('lg', AppCorner.lg),
  ('xl', AppCorner.xl),
  ('xxl', AppCorner.xxl),
  ('alert', AppCorner.alert),
  ('full', AppCorner.full),
];

class _DemoCornerCell extends StatelessWidget {
  const _DemoCornerCell({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return SizedBox(
      width: 74,
      child: Column(
        spacing: 4,
        children: [
          Container(
            height: 56,
            decoration: ShapeDecoration(
              color: colorScheme.primaryContainer,
              shape: AppShape.of(AppRadius.all(value)),
            ),
            child: Center(
              child: Text(
                label,
                style: AppTextStyle.caption1
                    .of(context, emphasized: true)
                    .copyWith(color: colorScheme.onPrimaryContainer),
              ),
            ),
          ),
          Text(
            value == AppCorner.full ? '1000' : value.toStringAsFixed(0),
            style: AppTextStyle.caption2
                .of(context)
                .copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: appMonospaceFontFamily,
                ),
          ),
        ],
      ),
    );
  }
}

class _DemoRadiusCombos extends StatelessWidget {
  const _DemoRadiusCombos();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final combos = <(String, RoundedSuperellipseBorder)>[
      ('AppRadius.all(xl)', AppShape.all(AppCorner.xl)),
      ('AppShape.top(xl)', AppShape.top(AppCorner.xl)),
      (
        'vertical(top: xl, bottom: sm)',
        AppShape.vertical(top: AppCorner.xl, bottom: AppCorner.sm),
      ),
      ('AppShape.of(AppRadius.md)', AppShape.of(AppRadius.md)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final (label, shape) in combos)
          Row(
            spacing: 10,
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  height: 46,
                  decoration: ShapeDecoration(
                    color: colorScheme.secondaryContainer,
                    shape: shape,
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Text(
                  label,
                  maxLines: 2,
                  style: AppTextStyle.caption2
                      .of(context)
                      .copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: appMonospaceFontFamily,
                      ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _DemoSpecialShapes extends StatelessWidget {
  const _DemoSpecialShapes();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Row(
      spacing: 10,
      children: [
        Expanded(
          child: Column(
            spacing: 6,
            children: [
              Container(
                height: 56,
                decoration: ShapeDecoration(
                  color: colorScheme.tertiaryContainer,
                  shape: AppShape.circle,
                ),
              ),
              const Text('circle'),
            ],
          ),
        ),
        Expanded(
          child: Column(
            spacing: 6,
            children: [
              Container(
                height: 56,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: colorScheme.tertiaryContainer,
                  shape: AppShape.full,
                ),
                child: const Text('full'),
              ),
              const Text('full'),
            ],
          ),
        ),
        Expanded(
          child: Column(
            spacing: 6,
            children: [
              Container(
                height: 56,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  shape: AppShape.input.copyWith(
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                child: const Text('input'),
              ),
              const Text('AppInputBorder'),
            ],
          ),
        ),
      ],
    );
  }
}
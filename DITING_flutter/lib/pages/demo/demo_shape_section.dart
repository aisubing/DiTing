part of 'demo_page.dart';

/// 形状分区：验证 [AppCorner] 九档、[AppRadius] 与 [AppShape] 的对应关系，
/// 以及 [AppInputBorder] 的描边/内边距。
///
/// 圆角是最容易「看起来差不多」的回归点：md 16 被写成 12，肉眼几乎看不出来，
/// 但把九档并排、标上数值，任何一档掉队都会立刻破坏等差数列的观感。
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
          text: 'AppShape 全部是 RoundedSuperellipseBorder（超椭圆），不是 '
              'BorderRadius.circular 的圆弧——直线段的曲率连续性在这里看得出来。',
        ),
      ],
    );
  }
}

/// 九档圆角：每格一个方块 + 档名 + 数值。full 用 1000 表示「取短边一半」，
/// 所以它和 circle 视觉上一致，但语义不同（前者是圆角上限，后者是圆）。
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

/// 九档的 (名字, 数值) 表。数值直接取 [AppCorner] 常量，不抄字面量。
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
            style: AppTextStyle.caption2.of(context).copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ],
      ),
    );
  }
}

/// 只圆一边/两边的组合：卡片拼接（列表首行只圆上边）与分段控件都靠它。
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
                  style: AppTextStyle.caption2.of(context).copyWith(
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

/// 圆、胶囊、输入框描边三种特殊形状。
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
                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
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

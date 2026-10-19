part of 'demo_page.dart';

/// 标签与选择标记分区：验证 [CommonChip]、[TonalChip]、[MetaChip] 三种标签的
/// 高度与字号差异，以及 [SelectionCheck] / [SelectionBadge] 两套勾选标记。
///
/// 三者的区别只在「一像素级」的 padding 与字号（caption1 强调 vs caption2
/// 强调），必须并排在同一行才看得出谁该用在哪里。
class _DemoChipSection extends StatelessWidget {
  const _DemoChipSection();

  @override
  Widget build(BuildContext context) {
    return _DemoSectionBody(
      children: [
        const _DemoLabel('CommonChip', trailing: '可带删除按钮'),
        const _DemoCommonChips(),
        const _DemoLabel('TonalChip', trailing: 'label + color + foregroundColor'),
        const _DemoTonalChips(),
        const _DemoLabel('MetaChip', trailing: '最小号的元信息标签'),
        const _DemoMetaChips(),
        const _DemoLabel('SelectionCheck / SelectionBadge', trailing: '勾选标记'),
        const _DemoSelectionMarks(),
        const ListFooter(
          text: 'TonalChip 内部用 _CapCentered 按 cap height 居中，所以它比同字号的 '
              'CommonChip 略矮——这是刻意的，别去「修正」它。',
        ),
      ],
    );
  }
}

/// 普通标签：单个、带删除、长文本截断、以及一条能换行的标签流。
class _DemoCommonChips extends StatelessWidget {
  const _DemoCommonChips();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            const CommonChip(label: '默认'),
            CommonChip(label: '可删除', onDeleted: () {}),
            const CommonChip(label: 'DIRECT'),
            const CommonChip(label: '这是一个很长的标签会被省略号截断'),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final label in const [
              '香港',
              '日本',
              '新加坡',
              '美国',
              '台湾',
              '韩国',
              '德国',
              '英国',
            ])
              CommonChip(label: label),
          ],
        ),
      ],
    );
  }
}

/// 色调标签：底色与前景色成对传入，用于延迟/协议/类型这类需要按值着色的场合。
class _DemoTonalChips extends StatelessWidget {
  const _DemoTonalChips();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final tones = <(String, Color, Color)>[
      ('primary', colorScheme.primary, colorScheme.onPrimary),
      (
        'secondary',
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
      ),
      ('tertiary', colorScheme.tertiary, colorScheme.onTertiary),
      ('error', colorScheme.error, colorScheme.onError),
      ('success', colorScheme.success, colorScheme.onPrimary),
      (
        'surface',
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (label, color, foreground) in tones)
              TonalChip(
                label: label,
                color: color,
                foregroundColor: foreground,
                onPressed: () => _demoToast(context, 'TonalChip · $label'),
              ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (delay, label) in const [
              (12, '12ms'),
              (86, '86ms'),
              (240, '240ms'),
              (780, '780ms'),
              (1600, '1.6s'),
            ])
              TonalChip(
                label: label,
                color:
                    colorScheme.delayColor(delay) ??
                    colorScheme.surfaceContainerHighest,
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ],
    );
  }
}

/// 元信息标签：列表行里跟在标题后的最小标签（协议、类型、计数）。
class _DemoMetaChips extends StatelessWidget {
  const _DemoMetaChips();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final label in const [
          'TCP',
          'UDP',
          'HTTP',
          'HTTPS',
          'DIRECT',
          'REJECT',
          'x12',
          '3 条',
        ])
          MetaChip(label: label),
        Text(
          '↑ MetaChip 与正文基线对齐',
          style: AppTextStyle.caption2.of(context).copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 选择标记：单勾、圆形徽标、preferred 两种状态（tonal / 实心）。
///
/// 用 [Wrap] 而不是 [Row]：四枚标记加说明文字在窄屏放不下一行，Wrap 会换行，
/// 而 Row 只会溢出。
class _DemoSelectionMarks extends StatelessWidget {
  const _DemoSelectionMarks();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: const [
            _DemoMarkCell(label: 'SelectionCheck', child: SelectionCheck()),
            _DemoMarkCell(label: 'SelectionBadge', child: SelectionBadge()),
            _DemoMarkCell(
              label: 'preferred()',
              child: SelectionBadge.preferred(),
            ),
            _DemoMarkCell(
              label: 'preferred(inUse)',
              child: SelectionBadge.preferred(inUse: true),
            ),
          ],
        ),
        Text(
          'pin 标记代理组当前偏好的节点；tonal 表示只是候选。',
          style: AppTextStyle.caption2.of(context).copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DemoMarkCell extends StatelessWidget {
  const _DemoMarkCell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 4,
      children: [
        SizedBox(height: 24, child: Center(child: child)),
        Text(
          label,
          style: AppTextStyle.caption2.of(context).copyWith(
            color: context.colorScheme.onSurfaceVariant,
            fontFamily: 'JetBrainsMono',
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

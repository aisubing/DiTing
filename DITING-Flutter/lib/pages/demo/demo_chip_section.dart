part of 'demo_page.dart';

/// Chips and selection marks: [CommonChip], [TonalChip], [MetaChip], [SelectionCheck] and
/// [SelectionBadge], which differ only in padding and caption emphasis.
class _DemoChipSection extends StatelessWidget {
  const _DemoChipSection();

  @override
  Widget build(BuildContext context) {
    return _DemoSectionBody(
      children: [
        const _DemoLabel('CommonChip', trailing: '可带删除按钮'),
        const _DemoCommonChips(),
        const _DemoLabel(
          'TonalChip',
          trailing: 'label + color + foregroundColor',
        ),
        const _DemoTonalChips(),
        const _DemoLabel('MetaChip', trailing: '最小号的元信息标签'),
        const _DemoMetaChips(),
        const _DemoLabel('SelectionCheck / SelectionBadge', trailing: '勾选标记'),
        const _DemoSelectionMarks(),
        const ListFooter(
          text:
              'TonalChip 内部用 _CapCentered 按 cap height 居中，所以它比同字号的 '
              'CommonChip 略矮——这是刻意的，别去「修正」它。',
        ),
      ],
    );
  }
}

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

/// Background + foreground pair, for where the color encodes latency, protocol or type.
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
          style: AppTextStyle.caption2
              .of(context)
              .copyWith(color: context.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// [Wrap] instead of [Row] because four marks do not fit one narrow line.
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
          style: AppTextStyle.caption2
              .of(context)
              .copyWith(color: colorScheme.onSurfaceVariant),
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
          style: AppTextStyle.caption2
              .of(context)
              .copyWith(
                color: context.colorScheme.onSurfaceVariant,
                fontFamily: appMonospaceFontFamily,
                fontSize: 9,
              ),
        ),
      ],
    );
  }
}
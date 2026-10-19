part of 'demo_page.dart';

/// ColorScheme 角色色分区：验证前景/背景成对角色、项目扩展的三个语义色，
/// 以及色块上的自动对比字色。
///
/// 每个角色都成对出现（primary 挨着 onPrimary），因为对比度回归只有并排才
/// 看得出：单独看 primary 永远是「一个蓝色」，看不出它上面的字是否已经糊了。
class _DemoSchemeSection extends StatelessWidget {
  const _DemoSchemeSection();

  @override
  Widget build(BuildContext context) {
    return _DemoSectionBody(
      children: [
        const _DemoLabel('ColorScheme 角色色', trailing: '前景/背景成对'),
        const _DemoSchemeRoles(),
        const _DemoLabel('扩展角色', trailing: 'success / warning / destructive'),
        const _DemoExtraRoles(),
        const ListFooter(
          text: '色块上的字用对方角色的颜色（onPrimary 写在 primary 上），'
              '对比度不足时字会直接糊进底色里。',
        ),
      ],
    );
  }
}

/// ColorScheme 的主要角色：前景/背景成对排，才能看出对比度是否成立。
class _DemoSchemeRoles extends StatelessWidget {
  const _DemoSchemeRoles();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final pairs = <(String, Color, String, Color)>[
      ('primary', scheme.primary, 'onPrimary', scheme.onPrimary),
      (
        'primaryContainer',
        scheme.primaryContainer,
        'onPrimaryContainer',
        scheme.onPrimaryContainer,
      ),
      ('secondary', scheme.secondary, 'onSecondary', scheme.onSecondary),
      (
        'secondaryContainer',
        scheme.secondaryContainer,
        'onSecondaryContainer',
        scheme.onSecondaryContainer,
      ),
      ('tertiary', scheme.tertiary, 'onTertiary', scheme.onTertiary),
      ('error', scheme.error, 'onError', scheme.onError),
      (
        'errorContainer',
        scheme.errorContainer,
        'onErrorContainer',
        scheme.onErrorContainer,
      ),
      ('surface', scheme.surface, 'onSurface', scheme.onSurface),
      (
        'surfaceContainer',
        scheme.surfaceContainer,
        'onSurfaceVariant',
        scheme.onSurfaceVariant,
      ),
      ('outline', scheme.outline, 'outlineVariant', scheme.outlineVariant),
      (
        'inverseSurface',
        scheme.inverseSurface,
        'onInverseSurface',
        scheme.onInverseSurface,
      ),
    ];
    return Column(
      spacing: 6,
      children: [
        for (final (label, color, otherLabel, other) in pairs)
          _DemoColorPairRow(
            label: label,
            color: color,
            otherLabel: otherLabel,
            other: other,
          ),
      ],
    );
  }
}

/// 一对角色色：左边大色块，右边色块内写对方角色的名字，用对方色当字色——
/// 对比度不足时字会糊在底色里，一眼可见。
class _DemoColorPairRow extends StatelessWidget {
  const _DemoColorPairRow({
    required this.label,
    required this.color,
    required this.otherLabel,
    required this.other,
  });

  final String label;
  final Color color;
  final String otherLabel;
  final Color other;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Row(
      spacing: 8,
      children: [
        Expanded(
          flex: 5,
          child: Container(
            height: 40,
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: ShapeDecoration(color: color, shape: AppShape.sm),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.caption1
                  .of(context, emphasized: true)
                  .copyWith(color: other),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            '$otherLabel ${other.hex}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.caption2.of(context).copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ),
      ],
    );
  }
}

/// Material 没有、但项目处处在用的三个语义色，以及按延迟取色的
/// [delayColor]——后者是日志/服务商列表的共同判据。
class _DemoExtraRoles extends StatelessWidget {
  const _DemoExtraRoles();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final extras = <(String, Color)>[
      ('success', scheme.success),
      ('successContainer', scheme.successContainer),
      ('warning', scheme.warning),
      ('warningContainer', scheme.warningContainer),
      ('destructive', scheme.destructive),
      ('modalScrim', scheme.modalScrim),
      ('alertScrim', scheme.alertScrim),
      ('chromeSurface', scheme.chromeSurface),
    ];
    final delays = <int?>[null, -1, 0, 120, 599, 600, 1200];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, color) in extras)
              _DemoSwatch(label: label, color: color, width: 96),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final delay in delays)
              MetaChip(label: 'delay ${delay ?? 'null'}'),
            for (final delay in delays)
              Container(
                width: 22,
                height: 22,
                decoration: ShapeDecoration(
                  color:
                      scheme.delayColor(delay) ??
                      scheme.onSurface.withValues(alpha: 0.12),
                  shape: AppShape.xs,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 通用小色块：色 + 名字 + hex，颜色分区的积木。
class _DemoColorTile extends StatelessWidget {
  const _DemoColorTile({
    required this.label,
    required this.color,
    this.caption,
  });

  final String label;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Container(
          height: 44,
          alignment: Alignment.center,
          decoration: ShapeDecoration(color: color, shape: AppShape.sm),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.caption1
                .of(context, emphasized: true)
                .copyWith(color: _readableOn(color)),
          ),
        ),
        if (caption case final caption?)
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.caption2.of(context).copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'JetBrainsMono',
            ),
          ),
      ],
    );
  }
}

/// 色块上的文字：按亮度选黑或白，别让深色底上的深色字消失。
Color _readableOn(Color background) => background.computeLuminance() > 0.5
    ? const Color(0xFF000000)
    : const Color(0xFFFFFFFF);

/// 带名字的色点，用于语义色一览。
class _DemoSwatch extends StatelessWidget {
  const _DemoSwatch({
    required this.label,
    required this.color,
    this.width = 84,
  });

  final String label;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Container(
            height: 34,
            decoration: ShapeDecoration(
              color: color,
              shape: RoundedSuperellipseBorder(
                borderRadius: AppRadius.sm,
                side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.caption2.of(context).copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

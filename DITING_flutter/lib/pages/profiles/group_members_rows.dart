part of 'group_members_page.dart';

/// 已选成员行：序号 + 名字 + 拖拽把手 + 移除。
///
/// 序号是这一行的重点：组按顺序取第一个可用成员，所以「谁在前」是配置数据的
/// 一部分，不只是列表位置。
class MemberSelectedRow extends StatelessWidget {
  const MemberSelectedRow({
    super.key,
    required this.name,
    required this.index,
    required this.total,
    required this.onRemove,
  });

  final String name;
  final int index;
  final int total;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ItemPositionProvider(
      position: ItemPosition.get(index, total),
      child: DecorationListItem(
        leading: SizedBox.square(
          dimension: 24,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: colorScheme.primary.withValues(alpha: 0.14),
              shape: AppShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: AppTextStyle.caption1
                    .of(context, emphasized: true)
                    .copyWith(color: colorScheme.primary),
              ),
            ),
          ),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            IconButton(
              tooltip: '移除',
              onPressed: onRemove,
              icon: const GlyphIcon(AppGlyphs.removeCircle),
            ),
            SortHandle(index: index),
          ],
        ),
      ),
    );
  }
}

/// 候选行：名字 + 说明 + 添加按钮。
class MemberCandidateRow extends StatelessWidget {
  const MemberCandidateRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.isGroup,
    required this.onAdd,
  });

  final String name;
  final String subtitle;

  /// 候选是另一个组：用组图标与「组」徽标区分，避免把组当成节点加进去。
  final bool isGroup;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ListItem(
      leading: GlyphIcon(
        isGroup ? AppGlyphs.layers : AppGlyphs.proxies,
        color: isGroup ? colorScheme.tertiary : colorScheme.primary,
      ),
      title: Row(
        spacing: 6,
        children: [
          Flexible(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (isGroup) const MetaChip(label: '组'),
        ],
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.listCaptionStyle,
      ),
      trailing: IconButton(
        tooltip: '添加',
        onPressed: onAdd,
        icon: const GlyphIcon(AppGlyphs.addCircle),
      ),
      onTap: onAdd,
    );
  }
}

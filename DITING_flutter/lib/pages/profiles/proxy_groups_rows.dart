part of 'proxy_groups_page.dart';

/// 代理组卡片（上游 `_ProxyGroupItem`）。
///
/// 卡片要回答三个问题：这个组按什么策略选（类型徽标）、现在选了谁（成员前几个
/// 名字）、有几个成员（计数）。三行里的第三行只在有 `filter` / `use` 时出现，
/// 因为它们是「组的行为已经被自动化了」的信号。
class ProxyGroupCard extends StatelessWidget {
  const ProxyGroupCard({
    super.key,
    required this.group,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onMembers,
    required this.onIcon,
    required this.onDuplicate,
    required this.onDelete,
  });

  final MockProxyGroup group;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMembers;
  final VoidCallback onIcon;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return GestureDetector(
      onLongPress: onLongPress,
      child: CommonCard(
        isSelected: isSelected,
        fillsSelection: isSelected,
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Row(
                spacing: 10,
                children: [
                  SizedBox.square(
                    dimension: 32,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        shape: AppShape.sm,
                      ),
                      child: Center(
                        child: GlyphIcon(
                          groupGlyphOf(group),
                          size: 18,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.listTitleStyle.copyWith(
                        color: isSelected ? colorScheme.onPrimary : null,
                      ),
                    ),
                  ),
                  TonalChip(
                    label: group.kind.label,
                    color: isSelected
                        ? colorScheme.onPrimary.withValues(alpha: 0.2)
                        : colorScheme.secondary.withValues(alpha: 0.14),
                    foregroundColor: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.secondary,
                  ),
                  CommonPopupBox(
                    targetBuilder: (open) => IconButton(
                      tooltip: UiLocalizations.of(context).more,
                      onPressed: open,
                      icon: const GlyphIcon(AppGlyphs.more),
                    ),
                    popupBuilder: (_) => CommonPopupMenu(
                      items: [
                        CommonPopupMenuItem(
                          label: '选择成员',
                          glyph: AppGlyphs.selectAll,
                          onPressed: onMembers,
                        ),
                        CommonPopupMenuItem(
                          label: '选择图标',
                          glyph: AppGlyphs.photos,
                          onPressed: onIcon,
                        ),
                        CommonPopupMenuItem(
                          label: '复制组',
                          glyph: AppGlyphs.copy,
                          onPressed: onDuplicate,
                        ),
                        CommonPopupMenuItem(
                          label: '删除组',
                          glyph: AppGlyphs.delete,
                          danger: true,
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                spacing: 6,
                children: [
                  MetaChip(label: '${group.members.length} 成员'),
                  if (group.kind.needsProbe)
                    MetaChip(label: '每 ${group.intervalSeconds ~/ 60} 分钟测速'),
                  if (group.kind.needsStrategy)
                    MetaChip(label: group.strategy.label),
                  if (group.hidden) const MetaChip(label: '隐藏'),
                ],
              ),
              if (group.members.isEmpty)
                Text(
                  '还没有成员，这个组不会转发任何流量',
                  style: context.listCaptionStyle.copyWith(
                    color: colorScheme.error,
                  ),
                )
              else
                Text(
                  group.members.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.listCaptionStyle,
                ),
              if (group.filter.isNotEmpty || group.useProviders.isNotEmpty)
                Row(
                  spacing: 6,
                  children: [
                    GlyphIcon(
                      AppGlyphs.filter,
                      size: 14,
                      color: colorScheme.tertiary,
                    ),
                    Flexible(
                      child: Text(
                        [
                          if (group.filter.isNotEmpty) '筛选：${group.filter}',
                          if (group.useProviders.isNotEmpty)
                            '引用：${group.useProviders.join('、')}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.listCaptionStyle.copyWith(
                          color: colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

part of 'rules_page.dart';

/// 一条规则行。
///
/// 行内容按上游 `RuleItem` 组织：主行是规则内容（覆写加 `pattern → target`），
/// 副行是来源标签。来源用文字而不是图标，因为「订阅名」本身就要显示出来，
/// 图标撑不下。
class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.rule,
    required this.kind,
    required this.protected,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onProtected,
  });

  final MockRule rule;
  final RuleKind kind;

  /// 只读保护：预设行且未开启「允许编辑默认白名单」。
  final bool protected;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onProtected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    // 只读行压到 0.75 透明度、未启用行再压一档：两种「不能按」的视觉必须
    // 可区分，否则用户会以为开关坏了。
    final opacity = protected ? 0.75 : (rule.enabled ? 1.0 : 0.5);
    final pattern = rule.target == null
        ? rule.pattern
        : '${rule.pattern} → ${rule.target}';
    return Opacity(
      opacity: opacity,
      child: ListItem(
        leading: GlyphIcon(
          glyphByName(kind.glyphName),
          size: 20,
          color: protected ? colorScheme.onSurfaceVariant : colorScheme.primary,
        ),
        title: Text(
          pattern,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.listTitleStyle.copyWith(
            fontFamily: 'JetBrainsMono',
            fontSize: 15,
          ),
        ),
        subtitle: Row(
          spacing: 6,
          children: [
            if (rule.important)
              TonalChip(
                label: '重要',
                color: colorScheme.warningContainer,
                foregroundColor: colorScheme.onWarningContainer,
              ),
            if (rule.group case final group?) MetaChip(label: group),
            if (rule.subscriptionName case final name?) MetaChip(label: name),
            if (protected) const MetaChip(label: '只读'),
            Flexible(
              child: Text(
                rule.source.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.listCaptionStyle,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            Switch(
              value: rule.enabled,
              onChanged: protected ? null : onToggle,
            ),
            CommonPopupBox(
              targetBuilder: (open) => IconButton(
                tooltip: UiLocalizations.of(context).more,
                onPressed: protected ? onProtected : open,
                icon: const GlyphIcon(AppGlyphs.more),
              ),
              popupBuilder: (_) => CommonPopupMenu(
                items: [
                  CommonPopupMenuItem(
                    label: '编辑规则',
                    glyph: AppGlyphs.edit,
                    onPressed: onEdit,
                  ),
                  CommonPopupMenuItem(
                    label: '删除规则',
                    glyph: AppGlyphs.delete,
                    danger: true,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
        onTap: protected ? onProtected : null,
      ),
    );
  }
}

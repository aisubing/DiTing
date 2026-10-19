part of 'subscriptions_page.dart';

/// 订阅卡片。
///
/// 用 `CommonCard` + `ListItem` 而不是自绘卡片：卡片本体的圆角、按下态、
/// 明暗两套填充都由设计系统管，页面只负责往里放内容，换主题时不会漏掉一块。
class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.entry,
    required this.isUpdating,
    required this.busy,
    required this.onToggle,
    required this.onUpdate,
    required this.onDelete,
    required this.onEdit,
  });

  final SubscriptionEntry entry;

  /// 这一条正在更新。
  final bool isUpdating;

  /// 有任意更新在跑：此时禁用所有更新入口，避免并发打同一份数据。
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final hasError = entry.error != null;
    return CommonCard(
      isError: hasError,
      // 停用的订阅整卡压暗：只在开关上体现会让「规则没生效」看起来像 bug。
      child: Opacity(
        opacity: entry.enabled ? 1 : 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListItem(
              leading: GlyphIcon(
                entry.importType == SubscriptionImportType.local
                    ? AppGlyphs.importFile
                    : AppGlyphs.cloudSync,
                size: 20,
                color: hasError ? colorScheme.error : colorScheme.primary,
              ),
              title: Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.listTitleStyle,
              ),
              subtitle: Text(
                '${entry.group} · ${entry.importType.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.listSubtitleStyle,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Switch(value: entry.enabled, onChanged: onToggle),
                  CommonPopupBox(
                    targetBuilder: (open) => IconButton(
                      tooltip: UiLocalizations.of(context).more,
                      onPressed: open,
                      icon: const GlyphIcon(AppGlyphs.more),
                    ),
                    popupBuilder: (_) => CommonPopupMenu(
                      items: [
                        CommonPopupMenuItem(
                          label: '立即更新',
                          glyph: AppGlyphs.refresh,
                          onPressed: busy ? null : onUpdate,
                        ),
                        CommonPopupMenuItem(
                          label: '编辑订阅',
                          glyph: AppGlyphs.edit,
                          onPressed: onEdit,
                        ),
                        CommonPopupMenuItem(
                          label: '删除订阅',
                          glyph: AppGlyphs.delete,
                          danger: true,
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      MetaChip(label: '${_formatCount(entry.ruleCount)} 条规则'),
                      MetaChip(label: entry.updatedAt),
                      if (entry.importType == SubscriptionImportType.remote)
                        Flexible(
                          child: Text(
                            entry.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.listCaptionStyle.copyWith(
                              fontFamily: 'JetBrainsMono',
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (hasError)
                    Row(
                      spacing: 6,
                      children: [
                        GlyphIcon(
                          AppGlyphs.error,
                          size: 16,
                          color: colorScheme.error,
                        ),
                        Expanded(
                          child: Text(
                            entry.error!,
                            style: context.listCaptionStyle.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (isUpdating)
                    // 单条更新用不确定进度条：演示数据没有真实进度可报，
                    // 报一个假百分比反而会让人以为能看到什么时候结束。
                    LinearProgressIndicator(
                      minHeight: 3,
                      borderRadius: AppRadius.full,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 千分位。规则条数是这里唯一的大数字，`48213` 读起来比 `48,213` 慢得多。
String _formatCount(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[i]);
  }
  return buffer.toString();
}

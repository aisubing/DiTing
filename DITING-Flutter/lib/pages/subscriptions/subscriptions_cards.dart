part of 'subscriptions_page.dart';

/// 订阅卡片。
///
/// 用 `CommonCard` + `ListItem` 而不是自绘卡片：卡片本体的圆角、按下态、明暗两
/// 套填充都由设计系统管，页面只负责往里放内容，换主题时不会漏掉一块。
///
/// 三态视觉（`SubscriptionImportState`）：`ready` 正常、`importing` 顶部不确定
/// 进度条、`failed` 卡片 `isError` + 错误色文案。三态之外的状态一律按 `ready`
/// 处理（`fromStorage` 的回落），不会出现「未知状态渲染成失败」这种误报。
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

  /// 这一条正在更新（真实下载在进行）。
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
    final hasError = entry.isFailed;
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
                entry.isRemote ? AppGlyphs.cloudSync : AppGlyphs.importFile,
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
                '${entry.groupKey} · ${entry.kind.displayName}'
                ' · ${entry.sourceType.label}',
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
                          onPressed: busy || !entry.isRemote ? null : onUpdate,
                        ),
                        CommonPopupMenuItem(
                          label: '重命名',
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      MetaChip(label: _lineCountLabel(entry)),
                      MetaChip(label: _updatedLabel(entry)),
                      if (entry.consecutiveFailureCount > 0)
                        MetaChip(
                          label: '连续失败 ${entry.consecutiveFailureCount} 次',
                        ),
                      if (!entry.isRemote) const MetaChip(label: '本地文件不可下载'),
                    ],
                  ),
                  if (entry.isRemote)
                    Text(
                      entry.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.listCaptionStyle.copyWith(
                        fontFamily: 'JetBrainsMono',
                      ),
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
                            entry.importError ?? '上次更新失败',
                            style: context.listCaptionStyle.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (entry.isImporting || isUpdating)
                    LinearProgressIndicator(
                      minHeight: 3,
                      borderRadius: AppRadius.full,
                    ),
                  if (entry.isRemote)
                    Text(
                      '已入库 ${_formatCount(entry.ruleCount)} 条规则；'
                      '更新会重新解析并替换该订阅贡献的规则。',
                      style: context.listCaptionStyle,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 真实入库条数（解析后写进规则表的行数）。
  static String _lineCountLabel(SubscriptionEntry entry) =>
      '${_formatCount(entry.ruleCount)} 条';

  static String _updatedLabel(SubscriptionEntry entry) {
    if (entry.lastUpdated <= 0) {
      return '从未成功更新';
    }
    return _formatTimestamp(entry.lastUpdated);
  }
}

/// epoch ms → `MM-dd HH:mm`。
///
/// 只保留到分钟：订阅更新是小时级动作，秒数没有信息量，还会让同一分钟内两次
/// 更新的卡片看起来「没变」。
String _formatTimestamp(int epochMs) {
  final time = DateTime.fromMillisecondsSinceEpoch(epochMs);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}

part of 'subscriptions_page.dart';

/// Built from `CommonCard` + `ListItem` so the design system owns radius, pressed state and
/// fills. `SubscriptionImportState` drives three looks: `ready`, `importing` and `failed`.
class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.entry,
    required this.isUpdating,
    required this.busy,
    required this.onToggle,
    required this.onUpdate,
    required this.onDelete,
    required this.onEdit,
    required this.onConfigure,
  });

  final SubscriptionEntry entry;

  final bool isUpdating;

  /// Any update is running, so every update entry point is disabled to avoid concurrent
  /// writes to the same data.
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  /// Opens the full edit sheet (address, kind, group, mirror).
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final hasError = entry.isFailed;
    final mirror = entry.record.mirrorTemplate;
    return CommonCard(
      isError: hasError,
      // A disabled subscription dims the whole card: showing it only on the switch makes
      // "rules not applied" look like a bug.
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
                  CommonSwitch(value: entry.enabled, onChanged: onToggle),
                  CommonPopupBox(
                    targetBuilder: (open) => IconButton(
                      tooltip: UiLocalizations.of(context).more,
                      onPressed: open,
                      icon: const GlyphIcon(AppGlyphs.more),
                    ),
                    popupBuilder: (_) => CommonPopupMenu(
                      items: [
                        CommonPopupMenuItem(
                          // Local rows re-read the picked file instead of downloading it.
                          label: entry.isRemote ? '立即更新' : '重新导入文件',
                          glyph: AppGlyphs.refresh,
                          onPressed: busy ? null : onUpdate,
                        ),
                        CommonPopupMenuItem(
                          label: '编辑订阅',
                          glyph: AppGlyphs.sliders,
                          // Saving may re-download, which must not overlap a running update.
                          onPressed: busy ? null : onConfigure,
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
                      if (!entry.isRemote) const MetaChip(label: '本地文件订阅'),
                      if (mirror != null)
                        MetaChip(
                          label: entry.record.mirrorFallback
                              ? '镜像 · 可回退'
                              : '镜像 · 不回退',
                        ),
                    ],
                  ),
                  Text(
                    // A local row stores its SAF address, which is far too long to show; the
                    // file name (last path segment) is what the user recognises.
                    entry.isRemote ? entry.url : _fileNameOf(entry.url),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.listCaptionStyle.copyWith(
                      fontFamily: appMonospaceFontFamily,
                    ),
                  ),
                  if (mirror != null)
                    Text(
                      '镜像 $mirror',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.listCaptionStyle.copyWith(
                        fontFamily: appMonospaceFontFamily,
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
                  Text(
                    '已入库 ${_formatCount(entry.ruleCount)} 条规则；'
                    '${entry.isRemote ? '更新会重新下载并替换' : '重新导入会重新读取该文件并替换'}'
                    '该订阅贡献的规则。',
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

  /// Last segment of a `content://` address, which is the file name the picker reported.
  static String _fileNameOf(String uri) {
    final segment = Uri.tryParse(uri)?.pathSegments.lastOrNull ?? uri;
    return segment.isEmpty ? uri : segment;
  }

  static String _lineCountLabel(SubscriptionEntry entry) =>
      '${_formatCount(entry.ruleCount)} 条';

  static String _updatedLabel(SubscriptionEntry entry) {
    if (entry.lastUpdated <= 0) {
      return '从未成功更新';
    }
    return _formatTimestamp(entry.lastUpdated);
  }
}

/// Epoch milliseconds to `MM-dd HH:mm`. Minutes are enough because updates happen on an
/// hourly scale, and seconds would make two updates in the same minute look identical.
String _formatTimestamp(int epochMs) {
  final time = DateTime.fromMillisecondsSinceEpoch(epochMs);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}

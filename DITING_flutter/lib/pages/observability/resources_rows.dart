part of 'resources_page.dart';

/// 概览卡：四类资源各自的条数与总体积，外加全部更新的进度条。
class ResourcesSummaryCard extends StatelessWidget {
  const ResourcesSummaryCard({super.key, required this.state});

  final ResourcesState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final totalBytes = state.resources.fold(
      0,
      (sum, resource) => sum + resource.sizeBytes,
    );
    final progress = state.total == 0 ? 0.0 : state.completed / state.total;
    return CommonCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            spacing: 8,
            children: [
              GlyphIcon(
                AppGlyphs.cloudSync,
                size: 20,
                color: colorScheme.primary,
              ),
              Expanded(
                child: Text(
                  '共 ${state.resources.length} 项资源',
                  style: context.listTitleStyle,
                ),
              ),
              MetaChip(label: obsFormatBytes(totalBytes)),
            ],
          ),
          Text(
            state.updatingAll
                ? '正在更新第 ${state.completed + 1} 项，共 ${state.total} 项'
                : '全部资源的本地缓存已是最新',
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          if (state.updatingAll)
            LinearProgressIndicator(
              value: progress == 0 ? null : progress,
              minHeight: 4,
              borderRadius: AppRadius.full,
            ),
        ],
      ),
    );
  }
}

/// 一行资源：名称 + 地址 + 更新时间 / 体积，右侧「更新」与「改地址」。
class ResourceRow extends StatelessWidget {
  const ResourceRow({
    super.key,
    required this.resource,
    required this.isUpdating,
    required this.onSync,
    required this.onEdit,
  });

  final MockObsResource resource;
  final bool isUpdating;
  final VoidCallback onSync;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ListItem(
      leading: GlyphIcon(
        _kindGlyph(resource.kind),
        size: 20,
        color: colorScheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              resource.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          MetaChip(label: obsFormatBytes(resource.sizeBytes)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(
              resource.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'JetBrainsMono',
                  ),
            ),
            Text(
              '${isUpdating ? '正在更新…' : '更新于 ${resource.updatedAt}'}'
              '${resource.lineCount > 0 ? ' · ${resource.lineCount} 条' : ''}',
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(
                    color: isUpdating
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (isUpdating)
            const SizedBox.square(
              dimension: 32,
              child: Center(child: CommonCircleLoading(size: 16)),
            )
          else
            DetailButton(
              glyph: AppGlyphs.refresh,
              tooltip: '更新此项',
              onPressed: onSync,
            ),
          DetailButton(
            glyph: AppGlyphs.edit,
            tooltip: '修改地址',
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

/// 资源种类对应的图标。
Glyph _kindGlyph(ObsResourceKind kind) => switch (kind) {
  ObsResourceKind.geoData => AppGlyphs.dataUsage,
  ObsResourceKind.iconSet => AppGlyphs.iconTile,
  ObsResourceKind.ruleProvider => AppGlyphs.rules,
  ObsResourceKind.script => AppGlyphs.code,
};

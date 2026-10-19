part of 'traffic_page.dart';

/// 一行应用流量：图标 + 名称 + 占比条 + 字节数。
///
/// 占比条不用 `LinearProgressIndicator`：那个组件的轨道与指示条颜色由主题
/// 接管，与卡片底色叠在一起几乎看不见；这里用两个 `DecoratedBox` 自绘，
/// 高度与圆角都能和行高对齐。
class _AppTrafficRow extends StatelessWidget {
  const _AppTrafficRow({
    required this.app,
    required this.total,
    required this.onTap,
  });

  final MockAppTraffic app;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final share = total == 0 ? 0.0 : app.bytes / total;
    return ListItem(
      leading: GlyphIcon(
        glyphByName(app.iconGlyphName),
        size: 20,
        color: colorScheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              app.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatBytes(app.bytes),
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            _ShareBar(share: share),
            Text(
              '${app.packageName} · ${app.queries} 次查询',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 18),
      onTap: onTap,
    );
  }
}

/// 占比条：轨道铺满宽度，指示条按比例填充。
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: share.clamp(0.0, 1.0),
                child: ColoredBox(color: colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 应用流量详情面板。
class _AppTrafficSheet extends StatelessWidget {
  const _AppTrafficSheet({required this.app, required this.total});

  final MockAppTraffic app;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final share = total == 0 ? 0.0 : app.bytes / total;
    return CommonScaffold(
      title: app.name,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KeyValueRow(
                    label: '包名',
                    value: app.packageName,
                    monospace: true,
                  ),
                  KeyValueRow(
                    label: '下行流量',
                    value: _formatBytes(app.bytes),
                    monospace: true,
                  ),
                  KeyValueRow(
                    label: '占比',
                    value: '${(share * 100).toStringAsFixed(1)} %',
                    monospace: true,
                  ),
                  KeyValueRow(
                    label: 'DNS 查询',
                    value: '${app.queries} 次',
                    monospace: true,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _ShareBar(share: share),
          ),
          ListFooter(
            text: '流量按 UID 归因到应用（上游 TrafficAttributionDialog 的口径）；'
                '同一应用的多进程流量合并计算。',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              '占比条长度就是这一行在本日总流量里的位置，与列表排序一致。',
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// 归因说明面板：解释「为什么某个应用算到了这些流量」。
class _AttributionSheet extends StatelessWidget {
  const _AttributionSheet();

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '流量归因说明',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  Text('统计口径', style: context.listTitleStyle),
                  Text(
                    '流量按 UID 归因：每个应用的上下行字节数由系统 UID 流量账本'
                    '累加得到，不走包名匹配，因此共享 UID 的应用会合并成一项。',
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
                  const Divider(height: 1),
                  Text('为什么数字比系统设置里少', style: context.listTitleStyle),
                  Text(
                    '这里只统计经过本机解析的流量，未走 DNS 的直连流量不计入；'
                    '系统设置里的统计包含全部网卡流量。',
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
                  const Divider(height: 1),
                  Text('实时速率的来源', style: context.listTitleStyle),
                  Text(
                    '曲线是 2 秒一次的 EMA 平滑值，不是瞬时值——瞬时值抖得看不清趋势。',
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          ListFooter(
            text: '上游对应 ui/traffic/TrafficAttributionDialog.kt 与 AppTrafficDetailDialog.kt。',
          ),
        ],
      ),
    );
  }
}

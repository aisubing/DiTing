part of 'traffic_page.dart';

/// One app row: name, package, share bar, up/down bytes. The share bar is hand-drawn from
/// two DecoratedBox widgets, since a LinearProgressIndicator vanishes on the card color.
class AppTrafficRow extends StatelessWidget {
  const AppTrafficRow({
    super.key,
    required this.row,
    required this.total,
    required this.sort,
    required this.onTap,
  });

  final AppTrafficDaily row;
  final int total;

  /// Current sort field. The share bar follows it: sorting by upload while drawing
  /// the total would put bar length and rank out of step.
  final TrafficSort sort;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final highlighted = switch (sort) {
      TrafficSort.total => row.totalBytes,
      TrafficSort.download => row.rxBytes,
      TrafficSort.upload => row.txBytes,
    };

    return ListItem(
      leading: GlyphIcon(
        AppGlyphs.appsList,
        size: 20,
        color: colorScheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              row.appName.isEmpty ? row.packageName : row.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            obsFormatBytes(highlighted),
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
            ShareBar(share: total <= 0 ? 0 : highlighted / total),
            Text(
              '${row.packageName} · ↓ ${obsFormatBytes(row.rxBytes)} '
              '↑ ${obsFormatBytes(row.txBytes)}',
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

class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.share});

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

/// Per-app traffic detail (upstream AppTrafficDetailDialog.kt).
class _AppTrafficDetailSheet extends StatelessWidget {
  const _AppTrafficDetailSheet({
    required this.row,
    required this.total,
    required this.sort,
  });

  final AppTrafficDaily row;
  final int total;
  final TrafficSort sort;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final share = row.shareOf(total);
    final highlighted = switch (sort) {
      TrafficSort.total => row.totalBytes,
      TrafficSort.download => row.rxBytes,
      TrafficSort.upload => row.txBytes,
    };

    return CommonScaffold(
      title: row.appName.isEmpty ? row.packageName : row.appName,
      body: ListView(
        // The sheet title floats over the body, so without this gap it covers line one.
        padding: EdgeInsets.only(top: context.contentTopPadding, bottom: 24),
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
                    value: row.packageName,
                    monospace: true,
                  ),
                  if (row.appName.isNotEmpty)
                    KeyValueRow(label: '应用名', value: row.appName),
                  KeyValueRow(
                    label: '下行流量',
                    value: obsFormatBytes(row.rxBytes),
                    monospace: true,
                  ),
                  KeyValueRow(
                    label: '上行流量',
                    value: obsFormatBytes(row.txBytes),
                    monospace: true,
                  ),
                  KeyValueRow(
                    label: '合计',
                    value: obsFormatBytes(row.totalBytes),
                    monospace: true,
                  ),
                  KeyValueRow(
                    label: '占比',
                    value: '${(share * 100).toStringAsFixed(1)} %',
                    monospace: true,
                  ),
                  KeyValueRow(
                    label: '统计起始日',
                    // For dateRange and allHistory, date is the earliest day in the group
                    // (upstream min(date)), not the latest update.
                    value: row.date.isEmpty ? '—' : row.date,
                    monospace: true,
                  ),
                  if (row.updatedAt > 0)
                    KeyValueRow(
                      label: '最后更新',
                      value: _updatedAtLabel(row.updatedAt),
                      monospace: true,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: ShareBar(share: share),
          ),
          ListFooter(
            text:
                '流量按 UID 归因到应用（上游 TrafficAttributionDialog 的口径）；'
                '同一应用的多进程流量合并计算。',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              '占比条长度是这一行按「${sort.label}」在当前窗口总量里的份额 '
              '（当前 ${obsFormatBytes(highlighted)}），与列表排序一致。',
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  /// updated_at is a millisecond timestamp, shown as `yyyy-MM-dd HH:mm`.
  static String _updatedAtLabel(int millis) {
    final time = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }
}

/// Upstream TrafficAttributionDialog.kt: why this app is credited and why no live rate.
class _AttributionSheet extends StatelessWidget {
  const _AttributionSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '流量归因说明',
      body: ListView(
        padding: EdgeInsets.only(top: context.contentTopPadding, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  Text('统计口径', style: context.listTitleStyle),
                  Text(
                    '流量按 UID 归因：每个应用的上下行字节数由引擎按 UID 累计后'
                    '按天落库（表 app_traffic_daily，主键是「日期 + 包名」），'
                    '不走包名匹配，因此共享 UID 的应用会合并成一项。',
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const Divider(height: 1),
                  Text('为什么数字比系统设置里少', style: context.listTitleStyle),
                  Text(
                    '这里只统计经过本机隧道处理的流量，未进入隧道的直连流量不计入；'
                    '系统设置里的统计包含全部网卡流量。',
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const Divider(height: 1),
                  Text('为什么没有实时速率', style: context.listTitleStyle),
                  Text(
                    '实时速率需要内核每秒回报的速率序列；本仓的按天流量表只有'
                    '「日期 + 包名 + 上下行累计字节」，没有速率列。因此'
                    '「本次会话」窗口与「按实时速率」排序不可用，页面上也没有'
                    '速率曲线——页面里出现的每个数字都是真实字节数。',
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const Divider(height: 1),
                  Text('记录保留多久', style: context.listTitleStyle),
                  Text(
                    '按天保留，由原生侧的清理策略删除过期行；'
                    '「全部历史」档位汇总表里现存的全部日期。',
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const Divider(height: 1),
                  Text('系统应用怎么识别', style: context.listTitleStyle),
                  Text(
                    '流量表里没有系统应用标记，页面按旧版 SystemAppClassifier 的'
                    '同一份前缀表识别（android、com.android.*、各厂商预装前缀等）。'
                    '「隐藏系统应用」开关的状态落在 traffic_stats_hide_system_apps。',
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const ListFooter(
            text:
                '上游对应 ui/traffic/TrafficAttributionDialog.kt 与 '
                'AppTrafficDetailDialog.kt；本页数字来自 app_traffic_daily。',
          ),
        ],
      ),
    );
  }
}
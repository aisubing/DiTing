part of 'traffic_page.dart';

/// 排序 chip：与 DNS 页的 `DnsKeywordChip` 同视觉，但独立定义，避免流量页
/// 依赖观测域的页面文件（两者只是长得像，不是同一个语义）。
class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return TonalChip(
      label: label,
      color: selected
          ? colorScheme.primary
          : context.raisedSurfaceLevel.colorOf(colorScheme),
      foregroundColor: selected
          ? colorScheme.onPrimary
          : colorScheme.onSurfaceVariant,
      onPressed: onPressed,
    );
  }
}

/// 一行应用流量：名称 + 包名 + 占比条 + ── 上下行字节数。
///
/// 占比条不用 `LinearProgressIndicator`：那个组件的轨道与指示条颜色由主题
/// 接管，与卡片底色叠在一起几乎看不见；这里用两个 `DecoratedBox` 自绘，
/// 高度与圆角都能和行高对齐。
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

  /// 当前排序字段。占比条跟着它变：按上传排序却画总量的条，条长与名次不一致。
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

/// 占比条：轨道铺满宽度，指示条按比例填充。
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

/// 应用流量详情面板。
class _AppTrafficSheet extends StatelessWidget {
  const _AppTrafficSheet({
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
                    // `dateRange` / `allHistory` 的 `date` 是组内最早一天
                    // （旧版 `min(date)`），不是「最近一次更新」。
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
            text: '流量按 UID 归因到应用（上游 TrafficAttributionDialog 的口径）；'
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

  /// `updated_at` 是毫秒时间戳；按 `yyyy-MM-dd HH:mm` 显示。
  static String _updatedAtLabel(int millis) {
    final time = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }
}

/// 归因说明面板：解释「为什么某个应用算到了这些流量」。
class _AttributionSheet extends StatelessWidget {
  const _AttributionSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '流量归因说明',
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
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
                    '引擎只回报累计字节数，没有按秒、按应用的速率接口；'
                    '页面上的曲线是示意波形，真实数字看统计卡与排行。',
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const Divider(height: 1),
                  Text('记录保留多久', style: context.listTitleStyle),
                  Text(
                    '按天保留，由原生侧的清理策略删除过期行；'
                    '「全部」档位汇总表里现存的全部日期。',
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          ListFooter(
            text: '上游对应 ui/traffic/TrafficAttributionDialog.kt 与 '
                'AppTrafficDetailDialog.kt；本页数字来自 app_traffic_daily。',
          ),
        ],
      ),
    );
  }
}

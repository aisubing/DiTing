part of 'dns_queries_page.dart';

/// 概览卡：总数 / 失败 / 缓存命中。
class DnsSummaryCard extends StatelessWidget {
  const DnsSummaryCard({
    super.key,
    required this.total,
    required this.failureCount,
    required this.cachedCount,
  });

  final int total;
  final int failureCount;
  final int cachedCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonCard(
      child: StatStrip(
        stats: [
          StatItem(
            label: '查询总数',
            value: '$total',
            unit: '条',
            color: colorScheme.primary,
          ),
          StatItem(
            label: '失败',
            value: '$failureCount',
            unit: '条',
            color: failureCount == 0 ? colorScheme.success : colorScheme.error,
          ),
          StatItem(
            label: '命中缓存数',
            value: '$cachedCount',
            unit: '条',
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// 关键词过滤 chip：选中态用主色填充，未选中用凸起表面。
class DnsKeywordChip extends StatelessWidget {
  const DnsKeywordChip({
    super.key,
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

/// 耗时文本：`0 ms` 是缓存命中，写成「缓存」更准确。
///
/// 不复用 `obsFormatLatency`：那个返回「缓存命中」，和结果列的文案重复。
String formatDnsElapsed(int milliseconds) =>
    milliseconds == 0 ? '缓存' : '$milliseconds ms';

/// 一行 DNS 查询：域名 + 类型 / 时间 + 结果 + 来源 + 耗时。
///
/// 失败行整行用 error 色（上游 `_ErrorRow` 的做法）：DNS 故障排查时视线只需
/// 扫红色行，不必逐条读结果文字。
class DnsQueryRow extends StatelessWidget {
  const DnsQueryRow({super.key, required this.query, required this.onTap});

  final MockDnsQuery query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final failure = query.isFailure;
    final outcomeColor = failure
        ? colorScheme.error
        : query.cached
        ? colorScheme.success
        : colorScheme.onSurfaceVariant;
    return ListItem(
      leading: GlyphIcon(
        failure
            ? AppGlyphs.error
            : query.cached
            ? AppGlyphs.checkCircle
            : AppGlyphs.dns,
        size: 20,
        color: failure ? colorScheme.error : colorScheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              query.domain,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: failure ? colorScheme.error : null),
            ),
          ),
          const SizedBox(width: 8),
          MetaChip(label: query.type.label),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              query.time.substring(11),
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'JetBrainsMono',
                  ),
            ),
            Text(
              query.outcome.label,
              style: AppTextStyle.footnote
                  .of(context, emphasized: failure)
                  .copyWith(color: outcomeColor),
            ),
            if (!query.cached)
              Text(
                query.source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            Text(
              formatDnsElapsed(query.latencyMs),
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(
                    color: failure
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                    fontFamily: 'JetBrainsMono',
                  ),
            ),
          ],
        ),
      ),
      trailing: GlyphIcon(
        AppGlyphs.chevronForward,
        size: 18,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

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

/// 耗时文本：`0` 不写成「0 ms」——没有 `elapsed` 记录的行（例如被拦截的查询
/// 在引擎里耗时就是 0）要能区分「很快」和「没有测」。
String formatDnsElapsed(int? milliseconds) {
  if (milliseconds == null) return '—';
  return milliseconds == 0 ? '缓存' : '$milliseconds ms';
}

/// DNS 记录类型编号 → 可读名。照 1.4.3 `dnsRequestType` 的映射。
///
/// 未列出的类型按 `TYPE_<n>` 显示：DNS 类型号是 IANA 注册的，写死一张完整表
/// 会随新记录类型过期，而 `TYPE_65` 这种写法本身就可查。
///
/// `0` → 「连接」是旧版映射之外的一条：引擎把**连接日志**写成 `queryType = 0`
/// 且 `queryName` 为 `TCP 1.2.3.4:443`（见 `engine_connection_log.go`）。
/// 1.4.3 的 `dnsRequestType(0)` 会落到 `else -> TYPE_0`，但它的列表页在更上层
/// 就把这类行折成「旁路」了，所以源码里看不到这一档。这里必须显式映射，
/// 否则连接行会显示成 `TYPE_0`，用户会以为类型号坏了。
String dnsTypeLabel(int queryType) => switch (queryType) {
  1 => 'A',
  28 => 'AAAA',
  5 => 'CNAME',
  15 => 'MX',
  16 => 'TXT',
  2 => 'NS',
  0 => '连接',
  _ => 'TYPE_$queryType',
};

/// 时间：`HH:mm:ss`（列表行只留时分秒，日期在详情里）。
String _dnsTimeOfDay(int timestamp) {
  final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

/// 概览里可选的包名关键词：从真实数据现取，取不到的（旧库 packageName 为
/// null 的行）不列，避免出现一个点了就没有结果的空 chip。
///
/// 上限 8 个：chip 行是横向 Wrap，前几个之外的包名点到要滚很远；用户仍可用
/// 搜索框按包名过滤。
List<String> _packageKeywords(List<DnsLogRow> rows) {
  final counts = <String, int>{};
  for (final row in rows) {
    final name = row.packageName;
    if (name == null || name.isEmpty) continue;
    counts[name] = (counts[name] ?? 0) + 1;
  }
  final sorted = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return sorted.take(8).toList(growable: false);
}

/// 一行 DNS 查询：域名 + 类型 / 时间 + 状态 + 应用 + 耗时。
///
/// 失败行整行用 error 色（上游 `_ErrorRow` 的做法）：DNS 故障排查时视线只需
/// 扫红色行，不必逐条读结果文字。
class DnsQueryRow extends StatelessWidget {
  const DnsQueryRow({super.key, required this.query, required this.onTap});

  final DnsLogRow query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final failed = query.status == RequestStatus.error;
    final blocked = query.status == RequestStatus.blocked;
    final statusColor = failed
        ? colorScheme.error
        : blocked
        ? colorScheme.warning
        : query.cached
        ? colorScheme.success
        : colorScheme.onSurfaceVariant;

    return ListItem(
      leading: GlyphIcon(
        failed
            ? AppGlyphs.error
            : blocked
            ? AppGlyphs.block
            : query.cached
            ? AppGlyphs.checkCircle
            : AppGlyphs.dns,
        size: 20,
        color: failed || blocked ? statusColor : colorScheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              query.queryName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: failed ? colorScheme.error : null),
            ),
          ),
          const SizedBox(width: 8),
          MetaChip(label: dnsTypeLabel(query.queryType)),
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
              _dnsTimeOfDay(query.timestamp),
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'JetBrainsMono',
                  ),
            ),
            Text(
              query.status.label,
              style: AppTextStyle.footnote
                  .of(context, emphasized: failed)
                  .copyWith(color: statusColor),
            ),
            if (query.packageName case final packageName?
                when packageName.isNotEmpty)
              Text(
                packageName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            Text(
              formatDnsElapsed(DnsLogMessage.parse(query.message).elapsedMs),
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(
                    color: failed ? colorScheme.error : statusColor,
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

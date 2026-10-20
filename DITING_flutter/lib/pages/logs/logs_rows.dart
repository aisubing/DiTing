part of 'logs_page.dart';

/// 一行请求日志：时间 + 域名 + 处置 chip + 延迟。
///
/// 处置用带色 chip 而不是纯文字：40 行里「放行」占多数，纯文字扫视时要逐行读，
/// 颜色能让人先定位到拦截行（`docs/refactor/05-traffic-log-system.md` §3.3 的
/// 仪表盘也是这个分层）。
class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.entry, required this.onTap});

  final MockLogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (color, container) = _actionColors(colorScheme, entry.action);
    return ListItem(
      leading: GlyphIcon(_actionGlyph(entry.action), size: 20, color: color),
      title: Row(
        children: [
          Expanded(
            child: Text(
              entry.domain,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TonalChip(
            label: entry.action.label,
            color: container,
            foregroundColor: color,
          ),
        ],
      ),
      subtitle: Text(
        '${entry.time} · ${entry.client}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (entry.cached) const GlyphIcon(AppGlyphs.dataUsage, size: 16),
          Text(
            '${entry.latencyMs}ms',
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const GlyphIcon(AppGlyphs.chevronForward, size: 18),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// 一行缓存条目：域名 + 应答 + TTL + 命中次数。
class _CacheRow extends StatelessWidget {
  const _CacheRow({required this.entry});

  final DnsCacheRecord entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ListItem(
      leading: GlyphIcon(
        AppGlyphs.dns,
        size: 20,
        color: colorScheme.onSurfaceVariant,
      ),
      title: Text(entry.domain, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_queryTypeLabel(entry.queryType)} · ${entry.responseSize}B',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyle.footnote
            .of(context)
            .copyWith(fontFamily: 'JetBrainsMono'),
      ),
      trailing: Text(
        'TTL ${entry.remainingTtlSeconds}s · ${entry.hitCount} 次',
        style: AppTextStyle.caption1
            .of(context)
            .copyWith(
              color: entry.remainingTtlSeconds < 30
                  ? colorScheme.warning
                  : colorScheme.success,
            ),
      ),
    );
  }
}

String _queryTypeLabel(int type) => switch (type) {
  1 => 'A',
  2 => 'NS',
  5 => 'CNAME',
  6 => 'SOA',
  12 => 'PTR',
  15 => 'MX',
  16 => 'TXT',
  28 => 'AAAA',
  33 => 'SRV',
  65 => 'HTTPS',
  _ => 'TYPE$type',
};

/// 一行竞速排行：名次 + 服务商 + 胜出次数 + 平均延迟。
class _RaceRow extends StatelessWidget {
  const _RaceRow({required this.rank, required this.entry});

  final int rank;
  final RaceRanking entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ListItem(
      leading: SizedBox(
        width: 24,
        child: Text(
          '$rank',
          textAlign: TextAlign.center,
          style: AppTextStyle.headline
              .of(context, emphasized: true)
              .copyWith(
                color: rank == 1
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
        ),
      ),
      title: Text(entry.provider, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '胜出 ${entry.wins} 次',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${entry.averageLatencyMs}ms',
        style: AppTextStyle.subheadline
            .of(context)
            .copyWith(color: colorScheme.delayColor(entry.averageLatencyMs)),
      ),
    );
  }
}

/// 单条请求详情面板。
class _LogDetailSheet extends StatelessWidget {
  const _LogDetailSheet({required this.entry});

  final MockLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (color, _) = _actionColors(colorScheme, entry.action);
    return CommonScaffold(
      title: '请求详情',
      body: ListView(
        // 浮层标题是浮在正文之上的（`FloatingHeaderBody`），不预留这段
        // `contentTopPadding`，「域名」这一行就会被标题压住——用户看到的
        // 就是「顶部内容高度不对、被遮挡」。
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
                    label: '域名',
                    value: entry.domain,
                    monospace: true,
                  ),
                  KeyValueRow(label: '时间', value: entry.time, monospace: true),
                  KeyValueRow(label: '处置', value: entry.action.label),
                  KeyValueRow(
                    label: '延迟',
                    value: '${entry.latencyMs} ms',
                    monospace: true,
                  ),
                  KeyValueRow(label: '来源客户端', value: entry.client),
                  KeyValueRow(label: '缓存命中', value: entry.cached ? '是' : '否'),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              entry.rule == null ? '命中规则' : '命中的规则',
              style: context.listTitleStyle,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              child: ListItem(
                leading: GlyphIcon(
                  entry.rule == null ? AppGlyphs.info : AppGlyphs.rules,
                  size: 20,
                  color: entry.rule == null
                      ? colorScheme.onSurfaceVariant
                      : color,
                ),
                title: Text(entry.rule ?? '未命中任何规则'),
                subtitle: Text(
                  entry.rule == null
                      ? '这条请求走了默认策略，没有规则参与判定。'
                      : '规则来源：规则订阅 · 处置：${entry.action.label}',
                ),
              ),
            ),
          ),
          ListFooter(text: '演示数据只有一条规则来源，真实实现会记录规则所属订阅与命中行号。'),
        ],
      ),
    );
  }
}

/// 处置 → (前景色, 容器色)。
///
/// 放行用 success、拦截用 error、覆写用 warning、缓存用 primary：四个语义正好
/// 对应设计系统已有的四种强调色，不需要另造色板。
(Color, Color) _actionColors(ColorScheme colorScheme, LogAction action) =>
    switch (action) {
      LogAction.allowed => (colorScheme.success, colorScheme.successContainer),
      LogAction.blocked => (colorScheme.error, colorScheme.errorContainer),
      LogAction.rewritten => (
        colorScheme.warning,
        colorScheme.warningContainer,
      ),
      LogAction.cached => (colorScheme.primary, colorScheme.primaryContainer),
      LogAction.failed => (colorScheme.error, colorScheme.errorContainer),
    };

Glyph _actionGlyph(LogAction action) => switch (action) {
  LogAction.allowed => AppGlyphs.checkCircle,
  LogAction.blocked => AppGlyphs.block,
  LogAction.rewritten => AppGlyphs.swap,
  LogAction.cached => AppGlyphs.dataUsage,
  LogAction.failed => AppGlyphs.warning,
};

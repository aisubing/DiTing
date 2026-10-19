part of 'dns_queries_page.dart';

/// DNS 查询详情（上游 `DnsQueryDetailView`）：基础信息 → 错误 → 查询链路 → 应答。
///
/// 上游把「错误」放在基础信息之后：失败查询的第一诉求是看到原因，而不是先
/// 读一串元数据。
class DnsQueryDetailSheet extends StatelessWidget {
  const DnsQueryDetailSheet({super.key, required this.query});

  final MockDnsQuery query;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final error = query.error;
    return CommonScaffold(
      title: 'DNS 查询详情',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DnsDetailHeader(query: query),
          ),
          generateSection(
            title: '基础信息',
            items: [
              KeyValueRow(label: '查询时间', value: query.time, monospace: true),
              KeyValueRow(label: '域名', value: query.domain, monospace: true),
              KeyValueRow(label: '记录类型', value: query.type.label),
              KeyValueRow(
                label: '上游来源',
                value: query.cached ? '未查询上游' : query.source,
              ),
              KeyValueRow(label: '结果', value: query.outcome.label),
              KeyValueRow(
                label: '耗时',
                value: obsFormatLatency(query.latencyMs),
              ),
              KeyValueRow(label: '命中缓存', value: query.cached ? '是' : '否'),
              KeyValueRow(
                label: 'TTL',
                value: query.ttlSeconds == 0 ? '未缓存' : '${query.ttlSeconds} 秒',
              ),
            ],
          ),
          if (error != null)
            generateSection(
              title: '错误',
              footer: '失败原因直接取核心返回的响应码与上游状态。',
              items: [DnsErrorRow(message: error)],
            ),
          generateSection(
            title: '查询链路',
            items: [
              for (final (index, hop) in query.hops.indexed)
                ChainStepRow(
                  label: hop,
                  detail: switch (index) {
                    0 => '发起',
                    _ when index == query.hops.length - 1 => '返回',
                    _ => '处理',
                  },
                  isLast: index == query.hops.length - 1,
                ),
            ],
          ),
          generateSection(
            title: '应答',
            footer: query.answers.isEmpty
                ? '这次查询没有拿到任何应答记录。'
                : '应答按上游返回顺序列出，未做去重。',
            items: query.answers.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Text(
                        '无应答记录',
                        style: AppTextStyle.footnote
                            .of(context)
                            .copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ]
                : [
                    for (final answer in query.answers)
                      KeyValueRow(label: '记录', value: answer, monospace: true),
                  ],
          ),
        ],
      ),
    );
  }
}

/// 详情顶部：域名 + 类型 chip + 结果 chip。
class DnsDetailHeader extends StatelessWidget {
  const DnsDetailHeader({super.key, required this.query});

  final MockDnsQuery query;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final failure = query.isFailure;
    final outcomeColor = failure
        ? colorScheme.error
        : query.cached
        ? colorScheme.success
        : colorScheme.onSurfaceVariant;
    return CommonCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text(
                  query.domain,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.listTitleStyle,
                ),
              ),
              MetaChip(label: query.type.label),
              TonalChip(
                label: query.outcome.label,
                color: outcomeColor.withValues(alpha: 0.14),
                foregroundColor: outcomeColor,
              ),
            ],
          ),
          Text(
            '${query.time} · ${query.cached ? '来自缓存' : query.source} · '
            '${obsFormatLatency(query.latencyMs)}',
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 错误行：error 底色 + 警告图标 + 原因。
class DnsErrorRow extends StatelessWidget {
  const DnsErrorRow({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colorScheme.errorContainer,
          shape: AppShape.md,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              GlyphIcon(
                AppGlyphs.error,
                size: 18,
                color: colorScheme.onErrorContainer,
              ),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: colorScheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「IP 质量」演示浮层：当前出口 IP 的多来源检测结果。
///
/// 独立成一个自带数据的浮层，而不是跳 `/ip-quality` 页面：那个页面属于系统
/// 领域（另一份 mock），DNS 页只借用它的入口位置，不引入跨页依赖。
class IpQualityOverlay extends StatelessWidget {
  const IpQualityOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final report = mockObservedIpQuality;
    final risky = report.level == '风险';
    final levelColor = risky ? colorScheme.error : colorScheme.success;
    return CommonDialog(
      title: 'IP 质量',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            spacing: 10,
            children: [
              GlyphIcon(AppGlyphs.locate, size: 22, color: colorScheme.primary),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      report.ip,
                      style: AppTextStyle.headline
                          .of(context)
                          .copyWith(fontFamily: 'JetBrainsMono'),
                    ),
                    Text(
                      '${report.ipType} · ${report.organization}',
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              TonalChip(
                label: report.level,
                color: levelColor.withValues(alpha: 0.14),
                foregroundColor: levelColor,
              ),
            ],
          ),
          Text(
            '${report.asn} · 检测于 ${report.checkedAt}',
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          for (final source in report.sources)
            Row(
              spacing: 8,
              children: [
                GlyphIcon(
                  source.status == '命中'
                      ? AppGlyphs.checkCircle
                      : AppGlyphs.warning,
                  size: 16,
                  color: source.status == '命中'
                      ? colorScheme.success
                      : colorScheme.warning,
                ),
                Expanded(
                  child: Text(
                    source.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.footnote.of(context),
                  ),
                ),
                Text(
                  source.latencyMs == null
                      ? source.status
                      : '${source.status} · ${source.latencyMs} ms',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'JetBrainsMono',
                      ),
                ),
              ],
            ),
          Text(
            risky ? '该地址被标记为机房 IP，部分站点可能会要求额外验证。' : '该地址未发现明显风险。',
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

part of 'dns_queries_page.dart';

/// DNS 查询详情（上游 `DnsQueryDetailView`）：基础信息 → 错误 → 解析结果 → 原始记录。
///
/// 上游把「错误」放在基础信息之后：失败查询的第一诉求是看到原因，而不是先
/// 读一串元数据。这里同样把 error 提到解析结果之前。
///
/// 所有字段都来自 `dns_log` 一行的真实列：`result` / `cached` / `queryType`
/// 直接读列，`app=` / `resolved=` / `blocked_by=` / `error=` / `elapsed=` 从
/// `message` 拆出来（格式见 `DnsLogWriter` 的写入侧）。没有 `message` 的行
/// 会如实显示「该行没有追加信息」，而不是拼一份看似完整的假字段。
class DnsQueryDetailSheet extends StatelessWidget {
  const DnsQueryDetailSheet({super.key, required this.query});

  final DnsLogRow query;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final parsed = DnsLogMessage.parse(query.message);
    final elapsed = parsed.elapsedMs;

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
              KeyValueRow(
                label: '查询时间',
                value: _dnsStampOf(query.timestamp),
                monospace: true,
              ),
              KeyValueRow(
                label: '查询名',
                value: query.queryName,
                monospace: true,
              ),
              KeyValueRow(
                label: '记录类型',
                value: dnsTypeLabel(query.queryType),
              ),
              KeyValueRow(label: '结果', value: query.status.label),
              KeyValueRow(
                label: '命中缓存',
                value: query.cached ? '是' : '否',
              ),
              KeyValueRow(
                label: '耗时',
                value: elapsed == null
                    ? '未记录'
                    : obsFormatLatency(elapsed),
                monospace: true,
              ),
              if (query.packageName case final packageName?
                  when packageName.isNotEmpty)
                KeyValueRow(label: '应用包名', value: packageName, monospace: true)
              else
                KeyValueRow(label: '应用包名', value: '未归因（引擎未解析出发起 UID）'),
              if (query.blockSubscriptionId case final id?)
                KeyValueRow(label: '拦截订阅', value: 'sub_$id', monospace: true),
            ],
          ),
          if (parsed.error case final error? when error.isNotEmpty)
            generateSection(
              title: '错误',
              footer: '这一栏是引擎写入的 error 字段原文。',
              items: [DnsErrorRow(message: error)],
            ),
          generateSection(
            title: '解析结果',
            footer: parsed.resolved == null
                ? '引擎没有在 message 里记录应答地址（缓存命中或未返回应答时都可能如此）。'
                : '应答地址是引擎写入 message 的 resolved 字段，可能包含多条。',
            items: [
              if (parsed.resolved case final resolved? when resolved.isNotEmpty)
                KeyValueRow(label: '应答地址', value: resolved, monospace: true)
              else
                KeyValueRow(label: '应答地址', value: '未记录'),
              if (parsed.blockedBy case final blockedBy? when blockedBy.isNotEmpty)
                KeyValueRow(label: '处置来源', value: blockedBy, monospace: true),
              KeyValueRow(label: '原始结果值', value: query.result, monospace: true),
            ],
          ),
          generateSection(
            title: '查询链路',
            items: _chainOf(query, parsed),
          ),
          if (query.message case final message? when message.isNotEmpty)
            generateSection(
              title: '原始记录',
              footer: 'message 列原文，未经改写；上面的字段都从这里解析出来。',
              items: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    message,
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFamily: 'JetBrainsMono',
                        ),
                  ),
                ),
              ],
            )
          else
            generateSection(
              title: '原始记录',
              footer: '这一行的 message 为空，说明引擎没有追加任何说明。',
              items: const [],
            ),
        ],
      ),
    );
  }

  /// 从真实字段还原的链路。没有上游字段时不给「上游 → 应答」这种无从证实的
  /// 步骤——宁可短一截，也不拼一条假链路。
  List<Widget> _chainOf(DnsLogRow row, DnsLogMessage parsed) {
    final steps = <(String, String)>[
      ('客户端发起 · ${dnsTypeLabel(row.queryType)} 查询', '发起'),
      if (row.isConnection)
        ('连接记录（未经过域名解析）', '直连')
      else if (row.cached)
        ('命中内存缓存', '缓存')
      else
        ('未命中缓存', '查询'),
      if (parsed.blockedBy case final blockedBy? when blockedBy.isNotEmpty)
        ('规则处置 · $blockedBy', '规则')
      else if (parsed.resolved case final resolved? when resolved.isNotEmpty)
        ('上游返回 · $resolved', '应答')
      else if (parsed.error != null)
        ('解析失败', '失败')
      else
        ('无上游记录', '结束'),
    ];
    return [
      for (final (index, step) in steps.indexed)
        ChainStepRow(
          label: step.$1,
          detail: step.$2,
          isLast: index == steps.length - 1,
        ),
    ];
  }
}

/// 完整时间：`yyyy-MM-dd HH:mm:ss`。
String _dnsStampOf(int timestamp) {
  final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

/// 详情顶部：域名 + 类型 chip + 结果 chip。
class DnsDetailHeader extends StatelessWidget {
  const DnsDetailHeader({super.key, required this.query});

  final DnsLogRow query;

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
                  query.queryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.listTitleStyle,
                ),
              ),
              MetaChip(label: dnsTypeLabel(query.queryType)),
              TonalChip(
                label: query.status.label,
                color: statusColor.withValues(alpha: 0.14),
                foregroundColor: statusColor,
              ),
            ],
          ),
          Text(
            '${_dnsStampOf(query.timestamp)} · '
            '${formatDnsElapsed(DnsLogMessage.parse(query.message).elapsedMs)}',
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
///
/// **仍是演示数据**：1.4.3 的 IP 质量检测依赖外网第三方接口（ipinfo 等），
/// 本轮没有移植，浮层里的每个数字都来自 `mockObservedIpQuality`。
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
          Text(
            '演示数据：本轮没有接入 IP 质量检测接口，以上结果不是当前出口的真实检测值。',
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: colorScheme.error),
          ),
        ],
      ),
    );
  }
}

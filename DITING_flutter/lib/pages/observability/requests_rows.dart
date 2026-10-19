part of 'requests_page.dart';

/// 结果对应的配色：成功绿、拦截黄、失败红。
///
/// 三态都靠颜色 + 图标双重区分，不单靠颜色——红绿色盲用户看图标也能分辨。
(Color, Glyph) _outcomeStyle(BuildContext context, RequestOutcome outcome) {
  final colorScheme = context.colorScheme;
  return switch (outcome) {
    RequestOutcome.success => (colorScheme.success, AppGlyphs.checkCircle),
    RequestOutcome.blocked => (colorScheme.warning, AppGlyphs.block),
    RequestOutcome.failed => (colorScheme.error, AppGlyphs.error),
  };
}

/// 一行请求：时间 + 域名 / 客户端 + 结果 + 延迟。
class RequestRow extends StatelessWidget {
  const RequestRow({super.key, required this.request, required this.onTap});

  final MockRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (outcomeColor, outcomeGlyph) = _outcomeStyle(
      context,
      request.outcome,
    );
    return ListItem(
      leading: GlyphIcon(outcomeGlyph, size: 20, color: outcomeColor),
      title: Row(
        children: [
          Expanded(
            child: Text(
              request.host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            request.time,
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: 'JetBrainsMono',
                ),
          ),
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
              request.client,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
            TonalChip(
              label: request.outcome.label,
              color: outcomeColor.withValues(alpha: 0.14),
              foregroundColor: outcomeColor,
            ),
            Text(
              obsFormatLatency(request.latencyMs),
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(
                    color: request.latencyMs >= 600
                        ? colorScheme.warning
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

/// 请求详情（上游标题「请求详情」）。
class RequestDetailSheet extends StatelessWidget {
  const RequestDetailSheet({super.key, required this.request});

  final MockRequest request;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (outcomeColor, outcomeGlyph) = _outcomeStyle(
      context,
      request.outcome,
    );
    return CommonScaffold(
      title: '请求详情',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      GlyphIcon(outcomeGlyph, size: 20, color: outcomeColor),
                      Expanded(
                        child: Text(
                          request.host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.listTitleStyle,
                        ),
                      ),
                      TonalChip(
                        label: request.outcome.label,
                        color: outcomeColor.withValues(alpha: 0.14),
                        foregroundColor: outcomeColor,
                      ),
                    ],
                  ),
                  Text(
                    '${request.client} · ${request.time}',
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          generateSection(
            title: '基础信息',
            items: [
              KeyValueRow(label: '时间', value: request.time, monospace: true),
              KeyValueRow(label: '域名', value: request.host, monospace: true),
              KeyValueRow(
                label: '目标地址',
                value: request.destinationIp,
                monospace: true,
              ),
              KeyValueRow(label: '客户端', value: request.client),
              KeyValueRow(label: '结果', value: request.outcome.label),
              KeyValueRow(
                label: '延迟',
                value: obsFormatLatency(request.latencyMs),
              ),
            ],
          ),
          generateSection(
            title: '规则命中',
            items: [
              KeyValueRow(label: '规则', value: request.rule, monospace: true),
              KeyValueRow(
                label: '处理方式',
                value: switch (request.outcome) {
                  RequestOutcome.success => '按规则转发',
                  RequestOutcome.blocked => '被规则拦截，未发出请求',
                  RequestOutcome.failed => '按规则转发后失败',
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              request.outcome == RequestOutcome.success
                  ? '这条请求已正常完成。'
                  : '异常请求可在「连接」页配合查看对应的活动连接。',
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

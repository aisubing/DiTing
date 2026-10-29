part of 'requests_page.dart';

/// Handling text, translating outcome and message into plain words. Wording follows the
/// upstream matchedRule switch; no invented categories.
String _handlingOf(ObservedRequest request) {
  if (request.source == RequestSource.dns) {
    if (request.status == RequestStatus.bypassed) return '直连，未经过 DNS 解析流程';
    if (request.status == RequestStatus.blocked) return '被过滤规则拦截，未发出查询';
    if (request.status == RequestStatus.rewritten) return '命中了覆写规则，返回改写后的结果';
    if (request.status == RequestStatus.error) return '解析过程出错，未取得应答';
    return '按规则解析并正常返回';
  }
  return switch (request.status) {
    RequestStatus.passed => '按规则转发成功',
    RequestStatus.rewritten => '命中了覆写规则，返回改写后的请求',
    RequestStatus.blocked => '被过滤规则拦截，未建立连接',
    RequestStatus.bypassed => '未解密直接转发（旁路）',
    RequestStatus.error => '处理过程出错',
    RequestStatus.all => '—',
  };
}

/// Matched rule text. An empty value gets an explanation rather than "none".
String _ruleOf(ObservedRequest request) {
  final rule = request.matchedRule?.trim();
  if (rule != null && rule.isNotEmpty) return rule;
  return request.source == RequestSource.https ? '未命中规则（或未记录规则）' : '无';
}

/// Bare host of a record: drops the `TCP `/`UDP ` prefix of connection rows, the port and any
/// trailing dot. Null when the record carries no host at all.
String? _hostOf(ObservedRequest request) {
  var text = request.title.trim();
  final lower = text.toLowerCase();
  if (lower.startsWith('tcp ') || lower.startsWith('udp ')) {
    text = text.substring(4).trim();
  }
  if (text.startsWith('[')) {
    final end = text.indexOf(']');
    return end > 1 ? text.substring(1, end) : null;
  }
  final colon = text.lastIndexOf(':');
  // A single colon followed by digits is a port; several colons mean a bare IPv6 address.
  if (colon > 0 &&
      text.indexOf(':') == colon &&
      int.tryParse(text.substring(colon + 1)) != null) {
    text = text.substring(0, colon);
  }
  text = text.replaceFirst(RegExp(r'\.+$'), '');
  return text.isEmpty ? null : text;
}

class RequestDetailSheet extends ConsumerWidget {
  const RequestDetailSheet({super.key, required this.request});

  final ObservedRequest request;

  Future<void> _copyHost(BuildContext context, String host) async {
    await Clipboard.setData(ClipboardData(text: host));
    if (!context.mounted) return;
    showObsTip(context, '已复制 $host');
  }

  Future<void> _addRule(
    BuildContext context,
    WidgetRef ref,
    RuleKind kind,
    String domain,
  ) async {
    final added = await ref.read(rulesProvider.notifier).add(kind, domain);
    if (!context.mounted) return;
    showObsTip(
      context,
      added ? '已将 $domain 加入${kind.title}' : '$domain 已在${kind.title}中',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final host = _hostOf(request);
    // Domain rules match query names, so a literal IP from a connection row cannot be a rule.
    final domain = host == null ? null : normalizeDomain(host);
    final inBlock =
        domain != null &&
        ref
            .watch(rulesOfKindProvider(RuleKind.block))
            .any((rule) => rule.pattern == domain);
    final inAllow =
        domain != null &&
        ref
            .watch(rulesOfKindProvider(RuleKind.allow))
            .any((rule) => rule.pattern == domain);
    final parsed = DnsLogMessage.parse(request.message);

    return CommonScaffold(
      title: '请求详情',
      body: PageBody(
        children: [
          _DetailHero(request: request),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              spacing: 10,
              children: [
                Expanded(
                  child: _QuickAction(
                    glyph: AppGlyphs.copy,
                    label: host != null && domain == null ? '复制地址' : '复制域名',
                    color: colorScheme.primary,
                    onPressed: host == null
                        ? null
                        : () => _copyHost(context, host),
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    glyph: AppGlyphs.block,
                    label: inBlock ? '已在黑名单' : '加入黑名单',
                    color: colorScheme.error,
                    onPressed: domain == null || inBlock
                        ? null
                        : () => _addRule(context, ref, RuleKind.block, domain),
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    glyph: AppGlyphs.checkCircle,
                    label: inAllow ? '已在白名单' : '加入白名单',
                    color: colorScheme.success,
                    onPressed: domain == null || inAllow
                        ? null
                        : () => _addRule(context, ref, RuleKind.allow, domain),
                  ),
                ),
              ],
            ),
          ),
          if (host != null && domain == null)
            const ListFooter(text: '该记录只有 IP 地址，域名规则无法匹配，因此不能加入黑白名单。'),
          SectionBlock(
            title: '基础信息',
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _InfoCard(
              children: [
                KeyValueRow(
                  label: '时间',
                  value: _stampOf(request.timestamp),
                  monospace: true,
                ),
                KeyValueRow(label: '来源', value: request.source.label),
                if (request.protocol case final protocol?
                    when protocol.isNotEmpty)
                  KeyValueRow(label: '协议', value: protocol, monospace: true),
                if (request.packageName case final packageName?
                    when packageName.isNotEmpty)
                  KeyValueRow(
                    label: '应用包名',
                    value: packageName,
                    monospace: true,
                  ),
                if (parsed.resolved case final resolved?)
                  KeyValueRow(label: '解析结果', value: resolved, monospace: true),
                if (request.elapsedMs case final elapsed?)
                  KeyValueRow(
                    label: '耗时',
                    value: obsFormatLatency(elapsed),
                    monospace: true,
                  ),
                if (request.blockSubscriptionId case final id?)
                  KeyValueRow(label: '拦截订阅', value: 'sub_$id', monospace: true),
              ],
            ),
          ),
          SectionBlock(
            title: '规则命中',
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _InfoCard(
              children: [
                KeyValueRow(
                  label: '规则',
                  value: _ruleOf(request),
                  monospace: true,
                ),
                KeyValueRow(label: '处理方式', value: _handlingOf(request)),
                if (parsed.error case final error?)
                  KeyValueRow(label: '错误', value: error, monospace: true),
              ],
            ),
          ),
          if (host != null)
            SectionBlock(
              title: 'AI 分析',
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: CommonCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                onPressed: () =>
                    openAgentAnalysis(context, AgentDomainTarget(host)),
                child: Row(
                  spacing: 12,
                  children: [
                    IconBadge(
                      glyph: AppGlyphs.sparkle,
                      size: 38,
                      glyphSize: 20,
                      color: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      shape: AppShape.circle,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text('分析这条请求', style: context.listTitleStyle),
                          Text(
                            '用配置的模型研判归属、风险与处置建议',
                            style: context.listCaptionStyle,
                          ),
                        ],
                      ),
                    ),
                    GlyphIcon(
                      AppGlyphs.chevronForward,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          if (request.message case final message? when message.isNotEmpty)
            SectionBlock(
              title: '原始记录',
              footer: '引擎写入 message 字段的原文，未经改写。',
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: CommonCard(
                padding: const EdgeInsets.all(14),
                inert: true,
                child: SelectableText(
                  message.split(',').map((part) => part.trim()).join('\n'),
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(
                        color: colorScheme.onSurface,
                        fontFamily: appMonospaceFontFamily,
                        height: 1.5,
                      ),
                ),
              ),
            ),
          ListFooter(
            text: request.status == RequestStatus.error
                ? '处理失败的请求可在「连接」页配合查看对应的活动连接。'
                : '加入的黑白名单可在「规则」页查看和撤销。',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Summary card: status badge, host and the chips that classify the record.
class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.request});

  final ObservedRequest request;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (statusColor, statusGlyph) = _statusStyle(context, request.status);
    final title = request.title.isEmpty ? '—' : request.title;
    final metaColor = context.raisedSurfaceLevel.colorOf(colorScheme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: CommonCard(
        inert: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                IconBadge(
                  glyph: statusGlyph,
                  color: statusColor.withValues(alpha: 0.14),
                  foregroundColor: statusColor,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      SelectableText(
                        title,
                        style: AppTextStyle.headline
                            .of(context)
                            .copyWith(
                              color: colorScheme.onSurface,
                              fontFamily: appMonospaceFontFamily,
                            ),
                      ),
                      Text(
                        request.status.explanation,
                        style: context.listCaptionStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                TonalChip(
                  label: request.status.label,
                  color: statusColor.withValues(alpha: 0.14),
                  foregroundColor: statusColor,
                ),
                TonalChip(
                  label: request.source.label,
                  color: metaColor,
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                if (request.cached)
                  TonalChip(
                    label: '缓存',
                    color: metaColor,
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                TonalChip(
                  label: _stampOf(request.timestamp),
                  color: metaColor,
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon over label in a card; disabled when [onPressed] is null.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.glyph,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final Glyph glyph;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final tint = enabled ? color : context.colorScheme.onSurfaceVariant;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: CommonCard(
        onPressed: onPressed,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            IconBadge(
              glyph: glyph,
              size: 40,
              glyphSize: 20,
              color: tint.withValues(alpha: 0.14),
              foregroundColor: tint,
              shape: AppShape.circle,
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.subheadline
                  .of(context, emphasized: true)
                  .copyWith(color: context.colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rows of [KeyValueRow] on one card, the layout the traffic detail sheet uses.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      inert: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

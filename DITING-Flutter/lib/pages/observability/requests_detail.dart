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

class RequestDetailSheet extends StatelessWidget {
  const RequestDetailSheet({super.key, required this.request});

  final ObservedRequest request;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final host = _hostOf(request);
    final parsed = DnsLogMessage.parse(request.message);
    final (statusColor, statusGlyph) = _statusStyle(context, request.status);

    return CommonScaffold(
      title: '请求详情',
      body: PageBody(
        children: [
          DetailHeroCard(
            glyph: statusGlyph,
            color: statusColor,
            title: request.title.isEmpty ? '—' : request.title,
            subtitle: request.status.explanation,
            chips: [
              TonalChip(
                label: request.status.label,
                color: statusColor.withValues(alpha: 0.14),
                foregroundColor: statusColor,
              ),
              DetailMetaChip(label: request.source.label),
              if (request.cached) const DetailMetaChip(label: '缓存'),
              DetailMetaChip(label: _stampOf(request.timestamp)),
            ],
          ),
          DomainActionRow(host: host),
          SectionBlock(
            title: '基础信息',
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: DetailInfoCard(
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
            child: DetailInfoCard(
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
              child: AgentAnalysisEntryCard(domain: host),
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

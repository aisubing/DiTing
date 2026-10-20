part of 'requests_page.dart';

/// 档位对应的配色与图标。
///
/// 六档而非三档：`rewritten`（覆写成功）与 `bypassed`（旁路直连）都不是失败，
/// 套进「成功 / 拦截 / 失败」会把二者一起染红，排查时误判成故障。
/// 三态都靠颜色 + 图标双重区分，不单靠颜色——红绿色盲用户看图标也能分辨。
(Color, Glyph) _statusStyle(BuildContext context, RequestStatus status) {
  final colorScheme = context.colorScheme;
  return switch (status) {
    RequestStatus.passed => (colorScheme.success, AppGlyphs.checkCircle),
    RequestStatus.rewritten => (colorScheme.primary, AppGlyphs.edit),
    RequestStatus.blocked => (colorScheme.warning, AppGlyphs.block),
    RequestStatus.error => (colorScheme.error, AppGlyphs.error),
    RequestStatus.bypassed => (colorScheme.onSurfaceVariant, AppGlyphs.shuffle),
    RequestStatus.all => (colorScheme.onSurfaceVariant, AppGlyphs.info),
  };
}

/// 时间：`HH:mm:ss`。日期放进标题卡的第二行，列表行只留时分秒。
String _timeOfDay(int timestamp) {
  final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

/// 完整时间：`yyyy-MM-dd HH:mm:ss`，与旧版 `formatRequestTime` 同格式。
String _stampOf(int timestamp) {
  final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

/// 一行请求：时间 + 域名 + 来源/状态/包名/耗时。
class RequestRow extends StatelessWidget {
  const RequestRow({super.key, required this.request, required this.onTap});

  final ObservedRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (statusColor, statusGlyph) = _statusStyle(context, request.status);
    // authority 可能为 null（TLS 早期失败没有域名），而 `ObservedRequest.title`
    // 对 null 已经是空串；空串直接进 `Text` 会渲染成一行「洞」，所以落成
    // 破折号。旧版写的是「未取得 authority」，本仓列表行更短，用破折号。
    final title = request.title.isEmpty ? '—' : request.title;

    return ListItem(
      leading: GlyphIcon(statusGlyph, size: 20, color: statusColor),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _timeOfDay(request.timestamp),
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
              request.source.label,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
            if (request.packageName case final packageName?
                when packageName.isNotEmpty)
              Text(
                packageName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            TonalChip(
              label: request.status.label,
              color: statusColor.withValues(alpha: 0.14),
              foregroundColor: statusColor,
            ),
            if (request.elapsedMs case final elapsed?)
              Text(
                obsFormatLatency(elapsed),
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(
                      color: elapsed >= 600
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

/// 处理方式说明：把 `outcome` / `message` 翻成人话。
///
/// 文案口径照 1.4.3 `RequestLogItem.httpRequestItem` 的 `when (matchedRule)`：
/// 旁路与失败两类都靠 `matchedRule` 里的原因串区分，不自己造词。
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

/// 规则命中说明。空值不显示「无」，而是给一句能解释为什么为空的话。
String _ruleOf(ObservedRequest request) {
  final rule = request.matchedRule?.trim();
  if (rule != null && rule.isNotEmpty) return rule;
  return request.source == RequestSource.https
      ? '未命中规则（或未记录规则）'
      : '无';
}

/// 请求详情（上游标题「请求详情」）。
class RequestDetailSheet extends StatelessWidget {
  const RequestDetailSheet({super.key, required this.request});

  final ObservedRequest request;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final (statusColor, statusGlyph) = _statusStyle(context, request.status);
    final title = request.title.isEmpty ? '—' : request.title;

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
                      GlyphIcon(statusGlyph, size: 20, color: statusColor),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.listTitleStyle,
                        ),
                      ),
                      TonalChip(
                        label: request.status.label,
                        color: statusColor.withValues(alpha: 0.14),
                        foregroundColor: statusColor,
                      ),
                    ],
                  ),
                  Text(
                    '${request.source.label} · ${_stampOf(request.timestamp)}',
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
              KeyValueRow(
                label: '时间',
                value: _stampOf(request.timestamp),
                monospace: true,
              ),
              KeyValueRow(
                label: '来源',
                value: request.source.label,
              ),
              if (request.source == RequestSource.https)
                KeyValueRow(
                  label: '域名',
                  value: title,
                  monospace: true,
                )
              else
                KeyValueRow(
                  label: '查询名',
                  value: title,
                  monospace: true,
                ),
              if (request.protocol case final protocol?
                  when protocol.isNotEmpty)
                KeyValueRow(label: '协议', value: protocol, monospace: true),
              if (request.packageName case final packageName?
                  when packageName.isNotEmpty)
                KeyValueRow(label: '应用包名', value: packageName, monospace: true),
              KeyValueRow(label: '结果', value: request.status.label),
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
          generateSection(
            title: '规则命中',
            items: [
              KeyValueRow(
                label: '规则',
                value: _ruleOf(request),
                monospace: true,
              ),
              KeyValueRow(label: '处理方式', value: _handlingOf(request)),
            ],
          ),
          if (request.message case final message?
              when message.isNotEmpty)
            generateSection(
              title: '原始记录',
              footer: '这一列是引擎写入 message 字段的原文，未经改写。',
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
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              request.status == RequestStatus.error
                  ? '处理失败的请求可在「连接」页配合查看对应的活动连接。'
                  : '记录来自旧版数据库，只读；清空请用日志页的「清空」。',
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

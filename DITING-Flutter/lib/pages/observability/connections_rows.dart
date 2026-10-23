part of 'connections_page.dart';

/// One active connection: domain, target, chain, rates, duration and close button.
/// `ListItem` so height, dividers and press state match the rest of the app.
class ConnectionRow extends StatelessWidget {
  const ConnectionRow({
    super.key,
    required this.connection,
    required this.onTap,
    required this.onClose,
  });

  final MockConnection connection;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final blocked = connection.chains.contains('REJECT');
    return ListItem(
      leading: GlyphIcon(
        blocked ? AppGlyphs.block : AppGlyphs.connections,
        size: 20,
        color: blocked ? colorScheme.error : colorScheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              connection.host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            obsFormatDuration(connection.seconds),
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(
              '${connection.process} · ${connection.network.toUpperCase()} '
              '${connection.destinationIp}:${connection.destinationPort}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            ObsChainTrail(chains: connection.chains),
            Row(
              spacing: 6,
              children: [
                GlyphIcon(
                  AppGlyphs.rules,
                  size: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Text(
                    connection.ruleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            Row(
              spacing: 12,
              children: [
                ObsSpeedText(
                  glyph: AppGlyphs.arrowUp,
                  speed: connection.uploadSpeed,
                  color: colorScheme.onSurfaceVariant,
                ),
                ObsSpeedText(
                  glyph: AppGlyphs.arrowDown,
                  speed: connection.downloadSpeed,
                  color: colorScheme.primary,
                ),
                Flexible(
                  child: Text(
                    '共 ${obsFormatBytes(connection.download + connection.upload)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      trailing: SizedBox.square(
        dimension: 40,
        child: Center(
          child: Tooltip(
            message: '关闭这条连接',
            child: InkWell(
              onTap: onClose,
              customBorder: AppShape.circle,
              child: SizedBox.square(
                dimension: 28,
                child: Center(
                  child: GlyphIcon(
                    AppGlyphs.block,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

class ObsSpeedText extends StatelessWidget {
  const ObsSpeedText({
    super.key,
    required this.glyph,
    required this.speed,
    required this.color,
  });

  final Glyph glyph;
  final int speed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        GlyphIcon(glyph, size: 12, color: color),
        Text(
          obsFormatSpeed(speed),
          style: AppTextStyle.footnote
              .of(context)
              .copyWith(color: color, fontFamily: 'JetBrainsMono'),
        ),
      ],
    );
  }
}

/// Connection detail: basics, addresses, proxy chain, close button. Rule matches fold into
/// the chain section because this repo has no RecordTable column grouping.
class ConnectionDetailSheet extends ConsumerWidget {
  const ConnectionDetailSheet({
    super.key,
    required this.connectionId,
    required this.onClose,
  });

  final String connectionId;
  final ValueChanged<String> onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(connectionsProvider);
    final connection = connections
        .where((item) => item.id == connectionId)
        .firstOrNull;
    if (connection == null) {
      return CommonScaffold(
        title: '连接详情',
        // The empty state is centered, so it would otherwise start under the app bar.
        body: AppBarClearance(
          child: obsEmpty(
            label: '连接已关闭',
            description: '这条连接在别处被关闭了。',
            illustration: NullStatusIllustration.connections,
          ),
        ),
      );
    }
    return CommonScaffold(
      title: '连接详情',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ConnectionHeaderCard(connection: connection),
          ),
          generateSection(
            title: '基本信息',
            items: [
              KeyValueRow(label: '创建时间', value: connection.startedAt),
              KeyValueRow(
                label: '持续时间',
                value: obsFormatDuration(connection.seconds),
              ),
              KeyValueRow(label: '进程', value: connection.process),
              KeyValueRow(
                label: '网络类型',
                value: connection.network.toUpperCase(),
              ),
              KeyValueRow(
                label: '命中规则',
                value: connection.ruleText,
                monospace: true,
              ),
            ],
          ),
          generateSection(
            title: '地址',
            items: [
              KeyValueRow(label: '域名', value: connection.host, monospace: true),
              KeyValueRow(
                label: '目标地址',
                value: connection.endpoint,
                monospace: true,
              ),
              KeyValueRow(label: '目标地区', value: connection.geoIp),
              KeyValueRow(label: '目标 ASN', value: connection.asn),
              if (connection.remoteDestination.isNotEmpty)
                KeyValueRow(
                  label: '远端目标',
                  value: connection.remoteDestination,
                  monospace: true,
                ),
            ],
          ),
          generateSection(
            title: '路由链路',
            footer: '链路按流量实际经过的顺序排列，最后一步是最终的出站策略。',
            items: [
              for (final (index, chain) in connection.chains.indexed)
                ChainStepRow(
                  label: chain,
                  detail: index == connection.chains.length - 1
                      ? '最终出站'
                      : '策略组',
                  isLast: index == connection.chains.length - 1,
                ),
              KeyValueRow(label: 'DNS 模式', value: connection.dnsMode),
              if (connection.specialProxy.isNotEmpty)
                KeyValueRow(label: '指定代理', value: connection.specialProxy),
              if (connection.specialRules.isNotEmpty)
                KeyValueRow(label: '指定规则', value: connection.specialRules),
            ],
          ),
          generateSection(
            title: '请求与响应',
            items: [
              KeyValueRow(
                label: '上传',
                value: obsFormatBytes(connection.upload),
              ),
              KeyValueRow(
                label: '下载',
                value: obsFormatBytes(connection.download),
              ),
              KeyValueRow(
                label: '上行速率',
                value: obsFormatSpeed(connection.uploadSpeed),
              ),
              KeyValueRow(
                label: '下行速率',
                value: obsFormatSpeed(connection.downloadSpeed),
              ),
              KeyValueRow(
                label: '总流量',
                value: obsFormatBytes(connection.download + connection.upload),
              ),
              KeyValueRow(
                label: '平均下行',
                value: connection.seconds == 0
                    ? '—'
                    : obsFormatSpeed(connection.download ~/ connection.seconds),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: FilledButton.tonal(
              onPressed: () {
                onClose(connection.id);
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: context.colorScheme.errorContainer,
                foregroundColor: context.colorScheme.onErrorContainer,
              ),
              child: const Text('关闭连接'),
            ),
          ),
        ],
      ),
    );
  }
}

class ConnectionHeaderCard extends StatelessWidget {
  const ConnectionHeaderCard({super.key, required this.connection});

  final MockConnection connection;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            spacing: 8,
            children: [
              GlyphIcon(
                AppGlyphs.connections,
                size: 20,
                color: colorScheme.primary,
              ),
              Expanded(
                child: Text(
                  connection.host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.listTitleStyle,
                ),
              ),
              Text(
                obsFormatDuration(connection.seconds),
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          Text(
            '${connection.process} · ${connection.network.toUpperCase()} · '
            '${connection.endpoint}',
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
          Row(
            spacing: 16,
            children: [
              Expanded(
                child: ObsSpeedText(
                  glyph: AppGlyphs.arrowUp,
                  speed: connection.uploadSpeed,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: ObsSpeedText(
                  glyph: AppGlyphs.arrowDown,
                  speed: connection.downloadSpeed,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
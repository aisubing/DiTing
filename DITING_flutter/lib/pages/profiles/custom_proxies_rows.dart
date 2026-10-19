part of 'custom_proxies_page.dart';

/// 节点卡片（上游 `_NodeItem`）。
///
/// 三行信息：名称 + 协议徽标、`server:port`、延迟与传输开关。延迟做成徽标而不是
/// 单独一列，是因为它只在比较时有意义——一屏十张卡片，眼睛扫的是颜色不是数字。
class ProxyNodeCard extends StatelessWidget {
  const ProxyNodeCard({
    super.key,
    required this.proxy,
    required this.isSelected,
    required this.isSelecting,
    required this.onTap,
    required this.onLongPress,
    required this.onShare,
    required this.onDelete,
  });

  final MockProxy proxy;
  final bool isSelected;

  /// 多选态：卡片左侧换成勾选标记，点卡片只切选择不打开表单。
  final bool isSelecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return GestureDetector(
      onLongPress: onLongPress,
      child: CommonCard(
        isSelected: isSelected,
        fillsSelection: isSelected,
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            spacing: 12,
            children: [
              if (isSelecting)
                isSelected
                    ? const SelectionCheck()
                    : GlyphIcon(
                        AppGlyphs.proxies,
                        size: SelectionCheck.size,
                        color: colorScheme.onSurfaceVariant,
                      )
              else
                _ProtocolGlyph(protocol: proxy.protocol),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Row(
                      spacing: 8,
                      children: [
                        Flexible(
                          child: Text(
                            proxy.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.listTitleStyle.copyWith(
                              color: isSelected ? colorScheme.onPrimary : null,
                            ),
                          ),
                        ),
                        MetaChip(label: proxy.protocol.label),
                        if (proxy.tls) const MetaChip(label: 'TLS'),
                        if (!proxy.udp) const MetaChip(label: '不转 UDP'),
                      ],
                    ),
                    Text(
                      '${proxy.server}:${proxy.port}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.listCaptionStyle.copyWith(
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  ],
                ),
              ),
              _LatencyBadge(latencyMs: proxy.latencyMs),
              if (!isSelecting)
                CommonPopupBox(
                  targetBuilder: (open) => IconButton(
                    tooltip: UiLocalizations.of(context).more,
                    onPressed: open,
                    icon: const GlyphIcon(AppGlyphs.more),
                  ),
                  popupBuilder: (_) => CommonPopupMenu(
                    items: [
                      CommonPopupMenuItem(
                        label: '分享链接',
                        glyph: AppGlyphs.link,
                        onPressed: onShare,
                      ),
                      CommonPopupMenuItem(
                        label: '删除节点',
                        glyph: AppGlyphs.delete,
                        danger: true,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 协议图标底的方块：不同协议用不同字形，扫视时不必读文字。
class _ProtocolGlyph extends StatelessWidget {
  const _ProtocolGlyph({required this.protocol});

  final ProxyProtocol protocol;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return SizedBox.square(
      dimension: 36,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colorScheme.primary.withValues(alpha: 0.12),
          shape: AppShape.sm,
        ),
        child: Center(
          child: GlyphIcon(
            switch (protocol) {
              ProxyProtocol.wireguard => AppGlyphs.vpn,
              ProxyProtocol.tuic => AppGlyphs.bolt,
              ProxyProtocol.hysteria2 => AppGlyphs.speed,
              _ => AppGlyphs.link,
            },
            size: 18,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// 延迟徽标：数字 + 分档颜色。
class _LatencyBadge extends StatelessWidget {
  const _LatencyBadge({required this.latencyMs});

  final int latencyMs;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final color = latencyColorOf(colorScheme, latencyMs);
    return TonalChip(
      label: latencyMs <= 0 ? '未测速' : '$latencyMs ms',
      color: color.withValues(alpha: 0.14),
      foregroundColor: color,
    );
  }
}

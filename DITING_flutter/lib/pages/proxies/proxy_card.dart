/// 节点卡片（上游 `views/proxies/card.dart`，四种尺寸档）。
///
/// 上游的卡片是「选中态 + 延迟色 + 长按菜单」三件事的组合体，尺寸只有内边距与
/// 字号差异。这里把三档尺寸做成一个参数，避免三份几乎相同的 build。
library;

import 'package:diting/data/mock_proxies.dart';
import 'package:diting/pages/proxies/proxy_common.dart';
import 'package:diting/state/proxies_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 单张节点卡片。
///
/// 点击 = 选中（`onSelect` 返回 false 表示该组不可选，由页面给提示）；
/// 长按 = 弹出上下文菜单（延迟测试 / 复制名字）。
class ProxyCard extends StatelessWidget {
  const ProxyCard({
    super.key,
    required this.node,
    required this.cardType,
    required this.selected,
    required this.testing,
    required this.onSelect,
    required this.onMenu,
  });

  final ProxyNodeView node;
  final ProxyCardType cardType;
  final bool selected;
  final bool testing;
  final VoidCallback onSelect;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final padding = switch (cardType) {
      ProxyCardType.loose => const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      ProxyCardType.standard => const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      ProxyCardType.compact => const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
    };
    final titleStyle = switch (cardType) {
      ProxyCardType.loose => AppTextStyle.callout,
      ProxyCardType.standard => AppTextStyle.subheadline,
      ProxyCardType.compact => AppTextStyle.footnote,
    };
    return GestureDetector(
      onTap: onSelect,
      onLongPress: onMenu,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: padding,
        decoration: ShapeDecoration(
          shape: AppShape.md,
          color: selected
              ? colorScheme.primaryContainer
              : SurfaceLevel.card.colorOf(colorScheme),
        ),
        child: Row(
          spacing: 8,
          children: [
            // 选中点：未选中时留同宽占位，避免选中时整行右移。
            SizedBox(
              width: 14,
              child: selected
                  ? GlyphIcon(
                      AppGlyphs.checkCircle,
                      size: 14,
                      color: colorScheme.onPrimaryContainer,
                    )
                  : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 1,
                children: [
                  Text(
                    node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle
                        .of(context, emphasized: selected)
                        .copyWith(
                          color: selected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ),
                  ),
                  if (cardType != ProxyCardType.compact)
                    ProxyProtocolBadge(protocol: node.protocol),
                ],
              ),
            ),
            ProxyDelayText(delayMs: node.delayMs, testing: testing),
          ],
        ),
      ),
    );
  }
}

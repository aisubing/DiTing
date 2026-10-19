/// 分组区块：组头 + 节点网格。
///
/// tab 形式与 list 形式共用这一个 widget —— 两者的差别只在「一次显示几组、
/// 组头能否折叠」，那是页面级的编排，不该在卡片层分叉。
library;

import 'package:diting/data/mock_proxies.dart';
import 'package:diting/pages/proxies/proxy_card.dart';
import 'package:diting/pages/proxies/proxy_common.dart';
import 'package:diting/state/proxies_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 组头的紧凑程度。
enum ProxyGroupHeaderStyle {
  /// tab 形式：一行 `图标 + 组名 + 当前选中 + 测速按钮`，不可折叠。
  tab,

  /// list 形式：可折叠，折叠时也显示选中节点。
  list,
}

class ProxyGroupSection extends StatelessWidget {
  const ProxyGroupSection({
    super.key,
    required this.group,
    required this.settings,
    required this.headerStyle,
    required this.isTesting,
    required this.onSelect,
    required this.onTest,
    required this.onNodeMenu,
    required this.onToggleFold,
    this.unfolded = true,
  });

  final ProxyGroupView group;
  final ProxiesSettings settings;
  final ProxyGroupHeaderStyle headerStyle;
  final bool isTesting;
  final bool unfolded;
  final void Function(String proxyName) onSelect;
  final VoidCallback onTest;
  final void Function(ProxyNodeView node) onNodeMenu;
  final VoidCallback onToggleFold;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final canFold = headerStyle == ProxyGroupHeaderStyle.list;
    return CommonCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          _Header(
            group: group,
            isTesting: isTesting,
            canFold: canFold,
            unfolded: unfolded,
            onTest: onTest,
            onToggleFold: onToggleFold,
            iconStyle: settings.iconStyle,
          ),
          if (unfolded) ...[
            if (group.hiddenCount > 0)
              Text(
                '已隐藏 ${group.hiddenCount} 个超时节点',
                style: AppTextStyle.caption2
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            _NodeGrid(
              group: group,
              settings: settings,
              isTesting: isTesting,
              onSelect: onSelect,
              onNodeMenu: onNodeMenu,
            ),
          ] else if (group.selectedName != null)
            Text(
              '当前：${group.selectedName}',
              style: AppTextStyle.footnote.of(context).copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.group,
    required this.isTesting,
    required this.canFold,
    required this.unfolded,
    required this.onTest,
    required this.onToggleFold,
    required this.iconStyle,
  });

  final ProxyGroupView group;
  final bool isTesting;
  final bool canFold;
  final bool unfolded;
  final VoidCallback onTest;
  final VoidCallback onToggleFold;
  final ProxiesIconStyle iconStyle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Row(
      spacing: 6,
      children: [
        if (iconStyle != ProxiesIconStyle.hidden)
          _GroupIcon(glyphName: group.glyphName, style: iconStyle),
        Flexible(
          child: Text(
            group.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.subheadline.of(context, emphasized: true),
          ),
        ),
        // 组类型徽标：把「为什么这个组会自动变」直接写在组头上，省得用户猜。
        Text(
          group.type.label,
          style: AppTextStyle.caption2
              .of(context)
              .copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const Spacer(),
        if (group.selectedName != null && !canFold)
          Flexible(
            child: Text(
              group.selectedName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: colorScheme.primary),
            ),
          ),
        _TestButton(isTesting: isTesting, onTest: onTest),
        if (canFold)
          GestureDetector(
            onTap: onToggleFold,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: GlyphIcon(
                unfolded ? AppGlyphs.chevronUp : AppGlyphs.chevronDown,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupIcon extends StatelessWidget {
  const _GroupIcon({required this.glyphName, required this.style});

  final String glyphName;
  final ProxiesIconStyle style;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    if (style == ProxiesIconStyle.plain) {
      return ProxyGroupIcon(glyphName: glyphName, size: 16);
    }
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        shape: AppShape.sm,
        color: colorScheme.primaryContainer,
      ),
      child: ProxyGroupIcon(
        glyphName: glyphName,
        size: 14,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({required this.isTesting, required this.onTest});

  final bool isTesting;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return GestureDetector(
      onTap: isTesting ? null : onTest,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: GlyphIcon(
          isTesting ? AppGlyphs.sync : AppGlyphs.speed,
          size: 16,
          color: isTesting
              ? colorScheme.onSurfaceVariant
              : colorScheme.primary,
        ),
      ),
    );
  }
}

/// 节点网格。
///
/// 用 `Wrap` 而不是 `GridView`：卡片数是几个到几十个，`Wrap` 在
/// `SingleChildScrollView` 里不需要 `shrinkWrap`，也不会引入第二层滚动。
class _NodeGrid extends StatelessWidget {
  const _NodeGrid({
    required this.group,
    required this.settings,
    required this.isTesting,
    required this.onSelect,
    required this.onNodeMenu,
  });

  final ProxyGroupView group;
  final ProxiesSettings settings;
  final bool isTesting;
  final void Function(String proxyName) onSelect;
  final void Function(ProxyNodeView node) onNodeMenu;

  @override
  Widget build(BuildContext context) {
    // 一屏两列是上游的默认；紧凑档放三列。用 `LayoutBuilder` 算可用宽度，
    // 这样平板与横屏不会退化成「两列超宽卡片」。
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (settings.cardType) {
          ProxyCardType.compact => constraints.maxWidth >= 520 ? 4 : 3,
          ProxyCardType.standard => constraints.maxWidth >= 520 ? 3 : 2,
          ProxyCardType.loose => constraints.maxWidth >= 520 ? 2 : 1,
        };
        final spacing = settings.layout == ProxiesLayout.tight ? 6.0 : 8.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final node in group.nodes)
              SizedBox(
                width: width,
                child: ProxyCard(
                  node: node,
                  cardType: settings.cardType,
                  selected: group.selectedName == node.name,
                  testing: isTesting,
                  onSelect: () => onSelect(node.name),
                  onMenu: () => onNodeMenu(node),
                ),
              ),
          ],
        );
      },
    );
  }
}

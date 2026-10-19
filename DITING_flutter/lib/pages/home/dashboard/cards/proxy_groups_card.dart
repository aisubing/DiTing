import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 代理组摘要（仪表盘用）。
///
/// 有意与 `lib/data/mock_proxies.dart`（代理页的完整数据）分开：仪表盘只要
/// 「组名 + 当前选中 + 成员数 + 最新延迟」四项，字段少、体积小，不跟代理页
/// 的数据结构耦合——那边改字段不会牵动首页。
class _GroupSummary {
  const _GroupSummary({
    required this.name,
    required this.selected,
    required this.total,
    required this.latencyMs,
  });

  final String name;
  final int selected;
  final int total;

  /// 当前选中节点的延迟；`null` 表示未测速。
  final int? latencyMs;
}

const _groups = <_GroupSummary>[
  _GroupSummary(name: '节点选择', selected: 2, total: 24, latencyMs: 42),
  _GroupSummary(name: '自动选择', selected: 7, total: 24, latencyMs: 38),
  _GroupSummary(name: '流媒体', selected: 1, total: 6, latencyMs: 156),
  _GroupSummary(name: 'AI 服务', selected: 0, total: 4, latencyMs: null),
];

/// 代理组卡（上游 `widgets/proxy_groups.dart`，634 行）。
///
/// 上游这张卡有两种形态：`ProxyGroupsSummaryCard`（每行一个组 + 成员头像堆叠，
/// 仪表盘用）与 `ProxyGroupsCard`（展开成完整卡片列表，代理页用）。这里做前者，
/// 点击任意组跳到代理页对应的组。
class ProxyGroupsCard extends StatelessWidget {
  const ProxyGroupsCard({super.key, this.onOpenGroup});

  final void Function(String groupName)? onOpenGroup;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      semanticLabel: '代理组',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.proxies,
            title: '代理组',
            chevron: onOpenGroup != null,
          ),
          const SizedBox(height: 4),
          for (final group in _groups)
            _GroupRow(
              group: group,
              onTap: onOpenGroup == null
                  ? null
                  : () => onOpenGroup!(group.name),
            ),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, this.onTap});

  final _GroupSummary group;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final delayColor = colorScheme.delayColor(group.latencyMs);
    final shape = AppShape.all(AppCorner.md);
    return Semantics(
      button: onTap != null,
      label: '${group.name} ${group.selected + 1}/${group.total}',
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            spacing: 10,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardText.rowTitle(context),
                    ),
                    Text(
                      '第 ${group.selected + 1} / ${group.total} 个节点',
                      style: DashboardText.label(context),
                    ),
                  ],
                ),
              ),
              // 延迟徽标：只显示选中节点的延迟，和上游一致。
              if (group.latencyMs case final delay?)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: ShapeDecoration(
                    color: DashboardColors.of(context).tone,
                    shape: AppShape.all(AppCorner.sm),
                  ),
                  child: Text(
                    '${delay}ms',
                    style: DashboardText.label(
                      context,
                      color: delayColor,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: ShapeDecoration(
                    color: DashboardColors.of(context).tone,
                    shape: AppShape.all(AppCorner.sm),
                  ),
                  child: Text('未测速', style: DashboardText.label(context)),
                ),
              if (onTap != null)
                GlyphIcon(
                  AppGlyphs.chevronForward,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:diting/data/dashboard_models.dart';
import 'package:diting/pages/home/dashboard/cards/log_list_cards.dart';
import 'package:diting/pages/home/dashboard/cards/service_status_card.dart';
import 'package:diting/pages/home/dashboard/cards/traffic_monitor_card.dart';
import 'package:diting/pages/home/dashboard/cards/traffic_structure_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/pages/home/dashboard/edit/dashboard_edit_sheet.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 仪表盘卡片的落点回调。
///
/// 统一成一个对象而不是给 `buildDashboardCard` 加十个可选参数：卡片集以后还会
/// 增删，每加一张就改一次函数签名会让编辑态与普通态两个调用点同时漂移。没给
/// 回调的卡片就不显示「详情」按钮。
class DashboardCardActions {
  const DashboardCardActions({
    this.onOpenRequests,
    this.onOpenCache,
    this.onOpenRace,
    this.onOpenBootstrap,
    this.onOpenSubscriptionStats,
  });

  /// 无入口（编辑态用）：所有卡片都不显示「详情」。
  static const none = DashboardCardActions();

  final VoidCallback? onOpenRequests;
  final VoidCallback? onOpenCache;
  final VoidCallback? onOpenRace;
  final VoidCallback? onOpenBootstrap;
  final VoidCallback? onOpenSubscriptionStats;
}

/// 仪表盘卡片注册表。
///
/// 十张卡全部来自 1.4.3 的 `ModernLogDashboardModeViews.kt`：FlClash 时代的
/// `currentOutbound` / `networkSpeed` / `vpn` / `profiles` / `proxyGroups` /
/// `connectionStats` / `intranetIp` / `memory` 八张卡没有旧版依据，已随对应
/// 页面文件一起删除。
Widget buildDashboardCard(
  DashboardWidget widget,
  DashboardCardActions actions,
) {
  return switch (widget) {
    DashboardWidget.serviceStatus => ServiceStatusCard(
      onDetail: actions.onOpenRequests,
    ),
    DashboardWidget.trafficMonitor => TrafficMonitorCard(
      onDetail: actions.onOpenRequests,
    ),
    DashboardWidget.requestOverview => RequestOverviewCard(
      onDetail: actions.onOpenRequests,
    ),
    DashboardWidget.trafficStructure => const LogTrafficStructureCard(
      mode: TrafficStructureMode.all,
    ),
    DashboardWidget.recentRequests => RecentRequestsLogCard(
      onDetail: actions.onOpenRequests,
    ),
    DashboardWidget.cacheHotspots => CacheHotspotsCard(
      onDetail: actions.onOpenCache,
    ),
    DashboardWidget.raceWinners => RaceWinnersCard(
      onDetail: actions.onOpenRace,
    ),
    DashboardWidget.bootstrapDns => BootstrapDnsCard(
      onDetail: actions.onOpenBootstrap,
    ),
    DashboardWidget.ruleBlocks => RuleBlocksCard(
      onDetail: actions.onOpenSubscriptionStats,
    ),
    DashboardWidget.filteredHighlight => FilteredHighlightCard(
      onDetail: actions.onOpenSubscriptionStats,
    ),
  };
}

/// 仪表盘卡片编排区。
///
/// 普通态：单列按 `dashboardWidgetsProvider` 顺序渲染，卡片之间统一 12 间距。
/// 编辑态：每张卡右上角出现移除徽标、可拖拽换位，末尾出现「添加卡片」行。
///
/// 移动端是单列（上游 `dashboard.dart:290-357` 的移动分支）；桌面多列布局
/// 在 Android 上没有意义，因此刻意不实现。
class DashboardBoard extends ConsumerWidget {
  const DashboardBoard({super.key, this.actions = DashboardCardActions.none});

  final DashboardCardActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgets = ref.watch(dashboardWidgetsProvider);
    final editing = ref.watch(dashboardEditingProvider);
    final side = dashboardMobileSideOf(MediaQuery.sizeOf(context).width);
    if (editing) {
      return _EditingBoard(widgets: widgets, side: side);
    }
    if (widgets.isEmpty) {
      return _EmptyBoard(side: side);
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: dashboardCardGap,
        children: [
          for (final widget in widgets)
            _CardEntrance(
              key: ValueKey(widget),
              child: buildDashboardCard(widget, actions),
            ),
        ],
      ),
    );
  }
}

/// 卡片入场：透明度 + 轻微上移。
///
/// 上游卡片是逐张淡入的（`dashboard.dart` 的 `StaggeredEntrance`）。这里用
/// `TweenAnimationBuilder` 做一次性入场，不引入额外动画控制器——滚动时不重播，
/// 刷新列表时才会因为 key 变化重播。
class _CardEntrance extends StatelessWidget {
  const _CardEntrance({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, amount, child) => Opacity(
        opacity: amount,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - amount)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _EmptyBoard extends ConsumerWidget {
  const _EmptyBoard({required this.side});

  final double side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.fromLTRB(side, 40, side, 0),
      child: NullStatus(
        illustration: NullStatusIllustration.data,
        label: '仪表盘还没有卡片',
        description: '进入编辑模式，从「添加卡片」里挑几个放上来。',
        action: FilledButton.tonal(
          onPressed: () => ref.read(dashboardEditingProvider.notifier).enter(),
          child: const Text('进入编辑模式'),
        ),
      ),
    );
  }
}

/// 编辑态：可拖拽、可移除、可添加。
class _EditingBoard extends ConsumerWidget {
  const _EditingBoard({required this.widgets, required this.side});

  final List<DashboardWidget> widgets;
  final double side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: dashboardCardGap,
        children: [
          // 编辑提示条：说明当前处于编辑模式、手势怎么用。
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: ShapeDecoration(
              color: colorScheme.primaryContainer,
              shape: AppShape.all(AppCorner.md),
            ),
            child: Row(
              spacing: 8,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onPrimaryContainer,
                ),
                Expanded(
                  child: Text(
                    '拖动手柄排序，点右上角移除；改完点右上角「完成」。',
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: colorScheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
          if (widgets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: NullStatus(
                illustration: NullStatusIllustration.data,
                label: '卡片都移除了',
                description: '点下面的「添加卡片」挑一个。',
              ),
            )
          else
            ReorderableListView.builder(
              // 外层已有滚动容器，这里不能再滚，否则拖拽会与它抢手势。
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: widgets.length,
              onReorderItem: (oldIndex, newIndex) => ref
                  .read(dashboardWidgetsProvider.notifier)
                  .move(oldIndex, newIndex),
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                child: ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.02).animate(animation),
                  child: child,
                ),
              ),
              itemBuilder: (context, index) {
                final widget = widgets[index];
                return Padding(
                  key: ValueKey(widget),
                  padding: const EdgeInsets.only(bottom: 12),
                  // 操作条注入卡片内部：卡片顶部多出独立一行，徽标不再与
                  // 标题、右侧动作抢同一块空间。正文的禁用遮罩由卡片施加，
                  // 这样操作条不会被一起灰度化。
                  child: DashboardEditBar(
                    bar: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: _DragBadge(),
                        ),
                        const Spacer(),
                        _RemoveBadge(
                          onPressed: () => ref
                              .read(dashboardWidgetsProvider.notifier)
                              .remove(widget),
                        ),
                      ],
                    ),
                    // 编辑态不给落点：点进下钻页会让「拖不动」的误判变成
                    // 「刚拖完又被跳走」。
                    child: buildDashboardCard(
                      widget,
                      DashboardCardActions.none,
                    ),
                  ),
                );
              },
            ),
          _AddCardRow(side: 0),
        ],
      ),
    );
  }
}

class _RemoveBadge extends StatelessWidget {
  const _RemoveBadge({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            Icons.close,
            size: 16,
            color: colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

class _DragBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 28,
        height: 28,
        child: GlyphIcon(
          AppGlyphs.dragHandle,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 编辑态末尾的「添加卡片」行。
class _AddCardRow extends ConsumerWidget {
  const _AddCardRow({required this.side});

  final double side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side),
      child: OutlinedButton.icon(
        onPressed: () => showSheet<void>(
          context: context,
          builder: (_) => const DashboardEditSheet(),
        ),
        icon: Icon(Icons.add, size: 18, color: colorScheme.primary),
        label: const Text('添加卡片'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    );
  }
}

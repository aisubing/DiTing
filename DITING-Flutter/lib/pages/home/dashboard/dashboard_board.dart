import 'package:diting/data/dashboard_models.dart';
import 'package:diting/pages/home/dashboard/cards/intranet_ip_card.dart';
import 'package:diting/pages/home/dashboard/cards/log_list_cards.dart';
import 'package:diting/pages/home/dashboard/cards/memory_card.dart';
import 'package:diting/pages/home/dashboard/cards/network_speed_card.dart';
import 'package:diting/pages/home/dashboard/cards/site_latency_card.dart';
import 'package:diting/pages/home/dashboard/cards/status_card.dart';
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

/// Where dashboard cards navigate to. One object instead of ten optional parameters, so
/// adding a card does not change the signature. No action means no detail button.
class DashboardCardActions {
  const DashboardCardActions({
    this.onOpenRequests,
    this.onOpenCache,
    this.onOpenRace,
    this.onOpenBootstrap,
    this.onOpenSubscriptionStats,
    this.onOpenTraffic,
  });

  /// No targets (edit mode): no card shows a detail button.
  static const none = DashboardCardActions();

  final VoidCallback? onOpenRequests;
  final VoidCallback? onOpenCache;
  final VoidCallback? onOpenRace;
  final VoidCallback? onOpenBootstrap;
  final VoidCallback? onOpenSubscriptionStats;

  /// `/traffic`: target for the speed and traffic monitor cards.
  final VoidCallback? onOpenTraffic;
}

/// Dashboard card registry. First five cards follow FlClash 0.9.1, the rest the upstream
/// log dashboard views.
Widget buildDashboardCard(
  DashboardWidget widget,
  DashboardCardActions actions,
) {
  return switch (widget) {
    DashboardWidget.status => StatusCard(onDetail: actions.onOpenRequests),
    DashboardWidget.networkSpeed => NetworkSpeedCard(
      onDetail: actions.onOpenTraffic,
    ),
    DashboardWidget.siteLatency => SiteLatencyCard(
      onDetail: actions.onOpenTraffic,
    ),
    DashboardWidget.memoryInfo => MemoryCard(onDetail: actions.onOpenRequests),
    DashboardWidget.intranetIp => IntranetIpCard(
      onDetail: actions.onOpenRequests,
    ),
    DashboardWidget.trafficMonitor => TrafficMonitorCard(
      onDetail: actions.onOpenTraffic,
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

/// Dashboard card board: one column in dashboardWidgetsProvider order, plus a remove
/// badge, drag reordering and an add row in edit mode. Single column: Android has no room.
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

/// Card entrance: fade plus a small rise, played once per list refresh.
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
              // The outer scrollable already exists; nesting one would steal drag gestures.
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
                  // Injected inside the card so the badge does not compete with the title and
                  // trailing action. The
                  // card dims the body only, keeping the bar at full color.
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
                    // No target in edit mode: navigating away mid-drag reads as a lost drag.
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
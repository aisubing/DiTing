import 'package:diting/data/mock_dashboard.dart';
import 'package:diting/pages/home/dashboard/cards/connection_stats_card.dart';
import 'package:diting/pages/home/dashboard/cards/current_outbound_card.dart';
import 'package:diting/pages/home/dashboard/cards/intranet_ip_card.dart';
import 'package:diting/pages/home/dashboard/cards/memory_card.dart';
import 'package:diting/pages/home/dashboard/cards/network_speed_card.dart';
import 'package:diting/pages/home/dashboard/cards/outbound_mode_card.dart';
import 'package:diting/pages/home/dashboard/cards/profiles_card.dart';
import 'package:diting/pages/home/dashboard/cards/proxy_groups_card.dart';
import 'package:diting/pages/home/dashboard/cards/service_status_card.dart';
import 'package:diting/pages/home/dashboard/cards/vpn_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/edit/dashboard_edit_sheet.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 仪表盘卡片注册表（上游 `views/dashboard/widget_registry.dart`）。
///
/// 上游用 `Map<DashboardWidget, Widget Function()>` 注册 11 张卡；这里同样以
/// 枚举为键，编辑器「添加卡片」列表直接由枚举驱动，不需要第二处维护。
Widget buildDashboardCard(
  DashboardWidget widget, {
  VoidCallback? onOpenConnections,
  void Function(String groupName)? onOpenGroup,
  VoidCallback? onOpenProfiles,
}) {
  return switch (widget) {
    DashboardWidget.currentOutbound => const CurrentOutboundCard(),
    DashboardWidget.networkSpeed => const NetworkSpeedCard(),
    DashboardWidget.outboundMode => const OutboundModeCard(),
    DashboardWidget.vpn => const VpnCard(),
    DashboardWidget.serviceStatus => const ServiceStatusCard(),
    DashboardWidget.profiles => ProfilesCard(onTap: onOpenProfiles),
    DashboardWidget.proxyGroups => ProxyGroupsCard(onOpenGroup: onOpenGroup),
    DashboardWidget.connectionStats => ConnectionStatsCard(
      onOpenConnections: onOpenConnections,
    ),
    DashboardWidget.intranetIp => const IntranetIpCard(),
    DashboardWidget.memory => const MemoryCard(),
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
  const DashboardBoard({
    super.key,
    this.onOpenConnections,
    this.onOpenGroup,
    this.onOpenProfiles,
  });

  final VoidCallback? onOpenConnections;
  final void Function(String groupName)? onOpenGroup;
  final VoidCallback? onOpenProfiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgets = ref.watch(dashboardWidgetsProvider);
    final editing = ref.watch(dashboardEditingProvider);
    final side = dashboardMobileSideOf(MediaQuery.sizeOf(context).width);
    if (editing) {
      return _EditingBoard(
        widgets: widgets,
        side: side,
        onOpenConnections: onOpenConnections,
        onOpenGroup: onOpenGroup,
        onOpenProfiles: onOpenProfiles,
      );
    }
    if (widgets.isEmpty) {
      return _EmptyBoard(side: side);
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          for (final widget in widgets)
            _CardEntrance(
              key: ValueKey(widget),
              child: buildDashboardCard(
                widget,
                onOpenConnections: onOpenConnections,
                onOpenGroup: onOpenGroup,
                onOpenProfiles: onOpenProfiles,
              ),
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
  const _EditingBoard({
    required this.widgets,
    required this.side,
    this.onOpenConnections,
    this.onOpenGroup,
    this.onOpenProfiles,
  });

  final List<DashboardWidget> widgets;
  final double side;
  final VoidCallback? onOpenConnections;
  final void Function(String groupName)? onOpenGroup;
  final VoidCallback? onOpenProfiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
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
                  child: Stack(
                    children: [
                      // 编辑态卡片整体罩一层禁用遮罩：内容不可点，避免误触。
                      DisabledMask(
                        status: true,
                        child: buildDashboardCard(
                          widget,
                          onOpenConnections: null,
                          onOpenGroup: null,
                          onOpenProfiles: null,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _RemoveBadge(
                          onPressed: () => ref
                              .read(dashboardWidgetsProvider.notifier)
                              .remove(widget),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: ReorderableDragStartListener(
                          index: index,
                          child: _DragBadge(),
                        ),
                      ),
                    ],
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
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }
}

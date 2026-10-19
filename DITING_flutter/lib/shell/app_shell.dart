import 'package:diting/app/theme/layout.dart';
import 'package:diting/router.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 底栏承载的六页共用一个壳：内容 + 浮条。
///
/// 用 [StatefulShellRoute.indexedStack]，所以每个 branch 有自己的 `Navigator`
/// 且切 tab 不销毁——`KeepScope` 在这里是多余的，不能重复套。
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(bottomBarProvider);
    final haptic = ref.watch(hapticProvider);
    final selected = _selectedIndex(destinations, navigationShell.currentIndex);

    void onSelected(int index) {
      if (index == selected) {
        // 重复点当前 tab 回首页（上游行为：回第 0 页）。
        navigationShell.goBranch(index, initialLocation: true);
        return;
      }
      if (haptic) {
        HapticFeedback.selectionClick();
      }
      navigationShell.goBranch(index);
    }

    return Scaffold(
      // 内容自己负责底部留白（`DockSpacer`），浮条浮在它上面。
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: destinations.isEmpty
          ? null
          : _Dock(
              destinations: destinations,
              selectedIndex: selected,
              onSelected: onSelected,
            ),
    );
  }

  /// 底栏是 branch 的子集视图，因此用户配置的下标要映射回 branch 下标。
  int _selectedIndex(
    List<BottomBarDestination> destinations,
    int branchIndex,
  ) {
    final location = _branchOrder[branchIndex];
    final index = destinations.indexWhere(
      (destination) => destinationLocation(destination) == location,
    );
    return index < 0 ? 0 : index;
  }
}

/// branch 下标 → 路由，与 [createRouter] 的 branch 顺序一一对应。
const _branchOrder = <String>[
  Routes.home,
  Routes.hub,
  Routes.logs,
  Routes.traffic,
  Routes.tools,
  Routes.settings,
];

/// 底栏项 → 路由。
String destinationLocation(BottomBarDestination destination) =>
    switch (destination) {
      BottomBarDestination.home => Routes.home,
      BottomBarDestination.featureHub => Routes.hub,
      BottomBarDestination.logDashboard => Routes.logs,
      BottomBarDestination.appTraffic => Routes.traffic,
      BottomBarDestination.networkTools => Routes.tools,
      BottomBarDestination.settings => Routes.settings,
    };

class _Dock extends StatelessWidget {
  const _Dock({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<BottomBarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final isMobile = ViewScope.isMobileOf(context);
    final items = [
      for (final destination in destinations)
        NavigationDockDestination(
          glyph: destination.glyph,
          label: destination.label,
        ),
    ];
    // 浮条最多 5 项；超过后（用户配了 6 项）退回 Material 底栏，避免挤成
    // 每项 40dp 的不可点目标。
    if (!isMobile || items.length > maxDockDestinations) {
      return _FallbackBar(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onSelected: onSelected,
      );
    }
    return SafeArea(
      top: false,
      // 浮条自己算底部安全区（`insetOf`），这里不能再加一层。
      minimum: EdgeInsets.zero,
      child: NavigationDock(
        destinations: items,
        selectedIndex: selectedIndex,
        onSelected: onSelected,
      ),
    );
  }
}

class _FallbackBar extends StatelessWidget {
  const _FallbackBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<BottomBarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: GlyphIcon(destination.glyph),
            label: destination.label,
          ),
      ],
    );
  }
}

import 'package:diting/app/theme/layout.dart';
import 'package:diting/pages/server/server_mode_shell.dart';
import 'package:diting/router.dart';
import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 底栏承载的六页共用一个壳：内容 + 浮条。
///
/// 用 [StatefulShellRoute.indexedStack]，所以每个 branch 有自己的 `Navigator`
/// 且切 tab 不销毁——`KeepScope` 在这里是多余的，不能重复套。
///
/// **服务器模式是例外**：旧版 `DnsMainScreen` 是另一个 Activity，带自己的三 Tab
/// 浮条（概览 / 上游服务器 / 模式设置）。因此 `workModeProvider == server` 时
/// 整棵树换成 [ServerModeShell]，六项浮条不出现——把两套导航叠在一起，用户会
/// 在「上游服务器」页底下看到「日志 / 流量 / 工具」这些与服务器模式无关的 tab。
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(workModeProvider);
    if (mode == AppWorkMode.server) {
      return const ServerModeShell();
    }
    final destinations = ref.watch(bottomBarProvider);
    final haptic = ref.watch(hapticProvider);
    final style = ref.watch(bottomBarStyleProvider);
    final transition = ref.watch(tabTransitionProvider);
    final selected = _selectedIndex(destinations, navigationShell.currentIndex);

    void onSelected(int index) {
      // 底栏回调给的是 **destinations 下标**，`goBranch` 要的是 **branch 下标**，
      // 两者不是同一套：branch 固定六项（home/hub/logs/traffic/tools/settings），
      // 底栏只是它的 2–4 项子集。直接透传会让「网络工具」（底栏第 3 项 = 下标 2）
      // 落到 2 号 branch（日志仪表盘）、「设置」（下标 3）落到流量统计。
      final branch = branchIndexOf(destinationLocation(destinations[index]));
      if (branch == navigationShell.currentIndex) {
        // 重复点当前 tab 回首页（上游行为：回该 branch 的第 0 页）。
        navigationShell.goBranch(branch, initialLocation: true);
        return;
      }
      if (haptic) {
        HapticFeedback.selectionClick();
      }
      navigationShell.goBranch(branch);
    }

    return Scaffold(
      // 内容自己负责底部留白（`DockSpacer`），浮条浮在它上面。
      extendBody: true,
      body: _TabTransitionHost(
        transition: transition,
        branchIndex: navigationShell.currentIndex,
        child: navigationShell,
      ),
      bottomNavigationBar: destinations.isEmpty
          ? null
          : _Dock(
              destinations: destinations,
              selectedIndex: selected,
              onSelected: onSelected,
              style: style,
            ),
    );
  }

  /// 底栏是 branch 的子集视图，因此 branch 下标要先换成位置，再回查底栏下标。
  ///
  /// 找不到时返回 **-1**，不要兜底成 0。落在底栏之外的 branch（用户把「流量
  /// 统计」从底栏里删了，却又从首页卡片或功能中心进了 `/traffic`）如果兜底成
  /// 0，底栏会把「首页」点亮；而点击回调拿 `index != selectedIndex` 判重，点
  /// 「首页」等于点自己，什么也不发生——用户被卡在这一页，只能靠系统返回键。
  /// 返回 -1 让底栏不点亮任何项，点哪一项都是真正的切换。
  int _selectedIndex(List<BottomBarDestination> destinations, int branchIndex) {
    final location = branchLocationOf(branchIndex);
    final index = destinations.indexWhere(
      (destination) => destinationLocation(destination) == location,
    );
    return index;
  }
}

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
    required this.style,
  });

  final List<BottomBarDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final BottomBarStyle style;

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
    // 用户可以在外观页把底栏切成普通形态；普通形态本来就是给「项多、浮条挤
    // 不下」准备的，因此它优先于浮条判定。
    final wantFallback = style == BottomBarStyle.docked;
    // 浮条最多 5 项；超过后（用户配了 6 项）退回 Material 底栏，避免挤成
    // 每项 40dp 的不可点目标。
    if (wantFallback || !isMobile || items.length > maxDockDestinations) {
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

/// tab 切换动画。
///
/// `StatefulShellRoute.indexedStack` 本身不给切 tab 加动画（它只切换 `IndexedStack`
/// 的 index），所以动画只能在壳这一层做：用 [branchIndex] 作 key，切 tab 时换
/// 一棵新子树，让入场动画重播。
///
/// 注意这**不是**真的交叉淡入——旧 tab 会立刻消失。做成交叉淡入要给每个 branch
/// 各留一棵树（`AnimatedSwitcher` 的 child 必须带 key，成本是同时挂两份子树），
/// 而六个 tab 各自持有长列表，同时挂两份会让切 tab 从一帧变成两帧的抖动。
/// 上游移动端也只在「淡入」档做新页入场，因此这里对齐。
class _TabTransitionHost extends StatelessWidget {
  const _TabTransitionHost({
    required this.transition,
    required this.branchIndex,
    required this.child,
  });

  final TabTransition transition;
  final int branchIndex;
  final Widget child;

  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    // 关掉动画时不要套任何包装：多一层 `KeyedSubtree` 也会让子树在切 tab 时
    // 重建，与「无动画」的语义不符。
    if (transition == TabTransition.none) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(branchIndex),
      tween: Tween(begin: 0, end: 1),
      duration: _duration,
      curve: Curves.easeOutCubic,
      builder: (context, amount, child) => switch (transition) {
        TabTransition.fade => Opacity(opacity: amount, child: child),
        TabTransition.slide => FractionalTranslation(
          translation: Offset(0.04 * (1 - amount), 0),
          child: Opacity(opacity: amount, child: child),
        ),
        TabTransition.scale => Transform.scale(
          scale: 0.96 + 0.04 * amount,
          child: Opacity(opacity: amount, child: child),
        ),
        TabTransition.none => child!,
      },
      child: child,
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
      // `NavigationBar` 要求 0 ≤ selectedIndex < length，而落在底栏之外的 branch
      // 传进来的是 -1。这里退回 0 只是为了让断言过——该形态下每次点击都会回调
      // `onDestinationSelected`，不存在浮条那种「点已选中项被吞掉」的问题。
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
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

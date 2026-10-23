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

/// Shell for the six dock pages: content plus dock. [StatefulShellRoute.indexedStack] gives
/// every branch its own `Navigator` that survives tab switches, so `KeepScope` must not be
/// nested here. Server mode swaps the whole tree for [ServerModeShell].
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
      // The dock reports a destination index, `goBranch` wants a branch index; the dock is a
      // subset of the six branches, so passing it through would be wrong.
      final branch = branchIndexOf(destinationLocation(destinations[index]));
      if (branch == navigationShell.currentIndex) {
        // Re-tapping the current tab returns to the branch root (upstream).
        navigationShell.goBranch(branch, initialLocation: true);
        return;
      }
      if (haptic) {
        HapticFeedback.selectionClick();
      }
      navigationShell.goBranch(branch);
    }

    return Scaffold(
      // Content adds its own bottom padding (`DockSpacer`); the dock floats over it.
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

  /// Maps a branch index to a dock index, or -1 when the branch is not in the dock. Never
  /// fall back to 0: the dock would light up "home" and tapping it counts as tapping the
  /// selected item, trapping the user.
  int _selectedIndex(List<BottomBarDestination> destinations, int branchIndex) {
    final location = branchLocationOf(branchIndex);
    final index = destinations.indexWhere(
      (destination) => destinationLocation(destination) == location,
    );
    return index;
  }
}

/// Dock destination to route.
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
    // The plain bar is meant for many items, so it wins over the floating dock.
    final wantFallback = style == BottomBarStyle.docked;
    // The floating dock holds at most 5 items; beyond that use the Material bar.
    if (wantFallback || !isMobile || items.length > maxDockDestinations) {
      return _FallbackBar(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onSelected: onSelected,
      );
    }
    return SafeArea(
      top: false,
      // The dock applies its own bottom inset; do not add another layer here.
      minimum: EdgeInsets.zero,
      child: NavigationDock(
        destinations: items,
        selectedIndex: selectedIndex,
        onSelected: onSelected,
      ),
    );
  }
}

/// Tab switch animation. `indexedStack` only changes the index, so keying by [branchIndex] remounts
/// the subtree and replays the entry. Not a true cross-fade on purpose: keeping both trees alive
/// would turn a one-frame switch into a stutter.
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
    // With animations off, wrap nothing: even a `KeyedSubtree` would rebuild it.
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
      // `NavigationBar` requires 0 <= selectedIndex < length, but off-dock branches pass -1.
      // Clamping only satisfies the assert; every tap still fires.
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

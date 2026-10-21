// Portions derived from DITING (https://github.com/chen08209/DITING), Copyright (c) the DITING authors, GPL-3.0-or-later.
import 'package:material_ui/material_ui.dart';

/// A sheet's own navigator, which holds only the pages of that sheet.
class SheetPagesNavigator extends Navigator {
  const SheetPagesNavigator({super.key, super.onGenerateInitialRoutes});
}

bool isSheetPage(BuildContext context) =>
    Navigator.maybeOf(context)?.widget is SheetPagesNavigator;

/// A sheet opened from inside another sheet goes over it, sized by the space
/// that sheet is shown in rather than squeezed among its pages.
///
/// 一路爬到**最外层** navigator，而不是「第一个不是 sheet 的 navigator」。
/// 两者在只有一个 navigator 的宿主里相同，但在 `StatefulShellRoute` 下不同：
/// 每个 tab 是一个 branch `Navigator`，它挂在 `AppShell` 的 `Scaffold.body` 里，
/// 而底栏浮条是该 `Scaffold.bottomNavigationBar`——`Scaffold` 保证浮条画在
/// body 之上。于是推到 branch navigator 的浮层落在浮条**下面**：浮层打开时
/// 底部那条「首页 / 功能中心 / 日志仪表盘」照旧画在最上层，命中测试也仍然被
/// 浮条截走（实测 `modalBarrierInPath=false`，点浮条能切 tab）。
///
/// 推到最外层就落在 `AppShell` 之上，浮层与它的遮罩盖住浮条——这也正是二级
/// 页面一直在做的事（全部 `parentNavigatorKey: rootNavigatorKey`）。
NavigatorState sheetNavigatorOf(BuildContext context) {
  var navigator = Navigator.of(context);
  while (true) {
    final outer = navigator.context.findAncestorStateOfType<NavigatorState>();
    if (outer == null) {
      return navigator;
    }
    navigator = outer;
  }
}

final _covers = Expando<ProxyAnimation>();

ProxyAnimation _coverOf(Route<dynamic> route) =>
    _covers[route] ??= ProxyAnimation(kAlwaysDismissedAnimation);

/// Hands the route below the sheet's entrance, for it to step back behind.
mixin SheetCoverRouteMixin<T> on TransitionRoute<T> {
  ProxyAnimation? _covered;

  @override
  void didChangePrevious(Route<dynamic>? previousRoute) {
    super.didChangePrevious(previousRoute);
    _uncover();
    if (previousRoute != null) {
      _covered = _coverOf(previousRoute)..parent = animation;
    }
  }

  void _uncover() {
    final covered = _covered;
    if (covered != null && covered.parent == animation) {
      covered.parent = kAlwaysDismissedAnimation;
    }
    _covered = null;
  }

  @override
  void dispose() {
    _uncover();
    super.dispose();
  }
}

/// Runs to 1 as a sheet covers the page or sheet that [context] is on.
Animation<double> sheetCoverOf(BuildContext context) {
  var route = ModalRoute.of(context);
  while (route != null) {
    final navigator = route.navigator;
    if (navigator == null || navigator.widget is! SheetPagesNavigator) {
      return _coverOf(route);
    }
    route = ModalRoute.of(navigator.context);
  }
  return kAlwaysDismissedAnimation;
}

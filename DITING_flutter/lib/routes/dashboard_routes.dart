/// 仪表盘（首页）领域路由。
///
/// 上游仪表盘是**一屏 + 编辑模式**（`lib/views/dashboard/dashboard.dart`），
/// 编辑模式不是独立路由而是同屏状态。这里仍然给它一条路由，理由是：
/// 深链与测试都需要「不点两次就进编辑态」的入口，而首页组件本身从路由参数里
/// 拿不到状态（`StatefulShellRoute` 的 branch 只按 location 匹配）。
///
/// 这两条路由进入后会**立刻**跳回 `/`：它们的作用是「设置一个开关再回首页」，
/// 不是渲染一屏内容。所以它们只有 `redirect`，没有 `builder`。
library;

import 'package:diting/pages/home/dashboard/profile_detail_page.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

abstract final class DashboardPaths {
  static const dashboard = '/';

  /// 深链进编辑模式：设置开关后跳回首页。
  static const edit = '/dashboard/edit';

  /// 配置详情浮层（上游 `ProfileDetailSheet` 是 sheet，这里用路由方便深链）。
  static const profileDetail = '/dashboard/profile';
}

/// 仪表盘领域路由表。由 `lib/router.dart` 拼接。
///
/// 用 `redirect` 而不是 `builder`：`GoRouter` 的 redirect 在导航解析阶段执行，
/// 此时 `ProviderScope` 已经在树上了，可以直接读容器改状态；而 `builder` 里
/// 改状态会在 build 期触发 provider 更新，属于「build 期间产生副作用」。
List<RouteBase> dashboardRoutes() => [
  GoRoute(
    path: DashboardPaths.edit,
    parentNavigatorKey: rootNavigatorKey,
    redirect: (context, state) {
      _setEditing(context, true);
      return DashboardPaths.dashboard;
    },
  ),
  GoRoute(
    path: DashboardPaths.profileDetail,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => ProfileDetailPage(
      profileId: state.uri.queryParameters['id'],
    ),
  ),
];

/// 在 redirect 阶段改 provider 状态。
///
/// `GoRouter` 的 redirect 回调拿不到 `WidgetRef`，只能靠 `ProviderScope.containerOf`
/// 从 `BuildContext` 里取容器。取不到（例如在测试里没有 ProviderScope 祖先）时
/// 静默跳过——导航仍应成功，只是不进编辑态。
void _setEditing(BuildContext context, bool value) {
  final container = ProviderScope.containerOf(context, listen: false);
  final notifier = container.read(dashboardEditingProvider.notifier);
  if (value) {
    notifier.enter();
  } else {
    notifier.exit();
  }
}

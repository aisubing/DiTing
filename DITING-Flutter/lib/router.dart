import 'package:diting/pages/about/about_page.dart';
import 'package:diting/pages/home/home_page.dart';
import 'package:diting/pages/hub/feature_hub_page.dart';
import 'package:diting/pages/logs/logs_page.dart';
import 'package:diting/pages/mode/mode_onboarding_page.dart';
import 'package:diting/pages/mode/mode_select_page.dart';
import 'package:diting/pages/rules/batch_editor_page.dart';
import 'package:diting/pages/rules/rules_page.dart';
import 'package:diting/pages/settings/settings_page.dart';
import 'package:diting/pages/subscriptions/subscriptions_page.dart';
import 'package:diting/pages/system/unknown_route_page.dart';
import 'package:diting/pages/tools/tools_page.dart';
import 'package:diting/pages/traffic/traffic_page.dart';
import 'package:diting/routes/routes.dart';
import 'package:diting/shell/app_shell.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 路由表。
///
/// 结构：
/// - 底栏六个 tab 各占一个 [StatefulShellBranch]（`indexedStack` 天然保活，
///   切 tab 不重建，因此不再需要额外的 `KeepScope`）；
/// - 二级页面挂在 root navigator 上普通 push，走
///   `commonSharedXPageTransitions`（已在主题里统一）；
/// - 模式切换页与引导页**不在** shell 里：它们要全屏、没有底栏。
///
/// 1.4.3 的底栏是六项（`BottomBarDestination`），可选 2–4 个；这里的六个 branch
/// 与它一一对应。上一轮多出来的 `/agent`、`/apps` 已删除：前者与
/// `/hub/agent` 重复，后者在旧版是「排除应用名单」（`/hub/excluded-apps`）。
abstract final class Routes {
  static const home = '/';
  static const hub = '/hub';
  static const logs = '/logs';
  static const traffic = '/traffic';
  static const tools = '/tools';
  static const settings = '/settings';

  static const rules = '/rules';
  static const batchEditor = '/rules/batch';
  static const subscriptions = '/subscriptions';
  static const about = '/about';
  static const modeSelect = '/mode/select';
  static const modeOnboarding = '/mode/onboarding';

  /// 规则页按种类分三份，同一个 widget 三种数据源。
  static String rulesOf(String kind) => '$rules/$kind';
}

/// 底栏 tab 与 branch 下标的对应关系。
///
/// branch 顺序固定（不随用户配置变化），底栏只是它的一个子集视图；否则
/// 用户改一次底栏配置，`goBranch` 的下标就会整体错位。
const _branchOrder = <String>[
  Routes.home,
  Routes.hub,
  Routes.logs,
  Routes.traffic,
  Routes.tools,
  Routes.settings,
];

/// 把位置映射到 branch 下标。
///
/// **必须按最长前缀匹配，不能 `indexWhere(startsWith)` 取第一个命中**：首页的
/// 路径是 `/`，它对任何绝对路径都 `startsWith` 为真，于是 `/hub`、`/logs` 全都
/// 会被判成 0 号 branch。这个问题在「只有测试调用」时不可见，一旦有人用它做
/// `goBranch` 的入参，在任何非首页的位置点一下都会跳回首页。
///
/// 未命中时返回 0（首页）：兜底到首页比抛异常安全，调用点都在导航路径上。
int branchIndexOf(String location) {
  var bestIndex = 0;
  var bestLength = -1;
  for (var index = 0; index < _branchOrder.length; index++) {
    final prefix = _branchOrder[index];
    if (!location.startsWith(prefix)) continue;
    // `/logs` 与 `/logs/cache` 都命中 `/logs`；`/` 与 `/hub` 都命中 `/`。
    // 取最长的那条，`/logs/cache` 因此落在 logs branch 上。
    //
    // 前缀后必须紧跟 `/` 或结束，否则 `/logsomething` 会命中 `/logs`。
    final isBoundary =
        location.length == prefix.length ||
        prefix.endsWith('/') ||
        location[prefix.length] == '/';
    if (!isBoundary) continue;
    if (prefix.length > bestLength) {
      bestLength = prefix.length;
      bestIndex = index;
    }
  }
  return bestIndex;
}

/// branch 下标 → 该 branch 的根路径。
///
/// 供壳层把 `navigationShell.currentIndex` 反查成位置用。之前 `app_shell.dart`
/// 自己抄了一份 `_branchOrder`，两份顺序一旦有偏差，`goBranch` 的下标就会整体
/// 错位而且看不出来（见 `branchIndexOf` 注释）。现在只保留这一份。
String branchLocationOf(int index) =>
    index >= 0 && index < _branchOrder.length ? _branchOrder[index] : Routes.home;

/// 这个位置本身是不是某个底栏 tab 的根（`/`、`/hub`、`/logs`、`/traffic`、
/// `/tools`、`/settings`）。
///
/// 用来区分「跳到另一个 tab」与「打开一个二级页」：两者在跳转 API 上不能混用，
/// 见 [goToBranch]。
bool isBranchRoot(String location) {
  for (final root in _branchOrder) {
    if (root == location) return true;
  }
  return false;
}

/// 跳到 [location] 所在的底栏 tab（而不是把它 push 成一张独立页面）。
///
/// 为什么不直接 `context.push('/traffic')`：`/traffic` 等路径是
/// `StatefulShellBranch` 的根，push 它会在当前 branch 之上再叠一个页面，而这个
/// 页面里**同样画着一条底栏**。那条底栏不在 `StatefulShellRoute` 之内，点它切
/// 不动 branch——用户被卡在复制出来的这一页上，只能按返回键退出，这正是
/// 「底栏点了没反应 / 跳到错误页」的同一类问题。
///
/// 命中 shell 时返回 true（调用方不要再 push）；不在 shell 里（罕见，例如引导
/// 期无壳）返回 false，调用方才回退到普通 push。
bool goToBranch(BuildContext context, String location) {
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell == null) {
    return false;
  }
  shell.goBranch(branchIndexOf(location));
  return true;
}

/// 打开 [location]：目标是底栏 tab 就切 tab，否则正常 push 一张二级页。
///
/// 首页卡片、功能中心卡片这类「可能指向 tab、也可能指向二级页」的入口统一走
/// 这里，免得每个调用点各自判断，漏掉一处就又复制出一条无法切换的底栏。
void openLocation(BuildContext context, String location) {
  if (isBranchRoot(location) && goToBranch(context, location)) {
    return;
  }
  context.push(location);
}

GoRouter createRouter({String initialLocation = Routes.home}) {
  return GoRouter(
    initialLocation: initialLocation,
    navigatorKey: rootNavigatorKey,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.hub,
                builder: (context, state) => const FeatureHubPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.logs,
                builder: (context, state) => const LogsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.traffic,
                builder: (context, state) => const TrafficPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tools,
                builder: (context, state) => const ToolsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.batchEditor,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BatchEditorPage(),
      ),
      GoRoute(
        path: '${Routes.rules}/:kind',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            RulesPage(kind: state.pathParameters['kind'] ?? 'block'),
      ),
      GoRoute(
        path: Routes.subscriptions,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SubscriptionsPage(),
      ),
      GoRoute(
        path: Routes.about,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: Routes.modeSelect,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ModeSelectPage(),
      ),
      GoRoute(
        path: Routes.modeOnboarding,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ModeOnboardingPage(),
      ),
      // —— 第二轮按领域拆分的路由，各自在 `lib/routes/<domain>_routes.dart` 里
      // 定义；这里只负责拼接。新增领域 = 新增一个 `...<domain>Routes()`。
      ...dashboardRoutes(),
      ...hubRoutes(),
      ...logsRoutes(),
      ...observabilityRoutes(),
      ...configRoutes(),
      ...systemRoutes(),
    ],
    // 兜底页：没有它，未匹配的路由会被 `GoRouter` 静默当成「无页面」——
    // 真机上是一片空白，测试里因为没有抛异常反而会**通过**，这条路由就永远
    // 不会被发现是漏注册的。挂上 `UnknownRoutePage` 后：
    // - 用户看到「页面不存在 + 返回」，不是空白；
    // - `route_catalog_test.dart` 靠 `find.byType(UnknownRoutePage)` 把漏注册
    //   变成硬失败。
    errorBuilder: (context, state) =>
        UnknownRoutePage(location: state.uri.toString()),
  );
}

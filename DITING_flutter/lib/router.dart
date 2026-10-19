import 'package:diting/pages/about/about_page.dart';
import 'package:diting/pages/agent/agent_page.dart';
import 'package:diting/pages/apps/apps_page.dart';
import 'package:diting/pages/demo/demo_page.dart';
import 'package:diting/pages/home/home_page.dart';
import 'package:diting/pages/hub/feature_hub_page.dart';
import 'package:diting/pages/logs/logs_page.dart';
import 'package:diting/pages/mode/mode_onboarding_page.dart';
import 'package:diting/pages/mode/mode_select_page.dart';
import 'package:diting/pages/rules/batch_editor_page.dart';
import 'package:diting/pages/rules/rules_page.dart';
import 'package:diting/pages/server/server_page.dart';
import 'package:diting/pages/settings/settings_page.dart';
import 'package:diting/pages/subscriptions/subscriptions_page.dart';
import 'package:diting/pages/tools/tools_page.dart';
import 'package:diting/pages/traffic/traffic_page.dart';
import 'package:diting/shell/app_shell.dart';
import 'package:diting/ui/ui.dart';
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
/// 路由字符串集中在这里，页面内部只写 `context.push(Routes.xxx)`。
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
  static const apps = '/apps';
  static const agent = '/agent';
  static const about = '/about';
  static const server = '/server';
  static const demo = '/demo';
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

int branchIndexOf(String location) {
  final index = _branchOrder.indexWhere(location.startsWith);
  return index < 0 ? 0 : index;
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
        path: Routes.apps,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AppsPage(),
      ),
      GoRoute(
        path: Routes.agent,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AgentPage(),
      ),
      GoRoute(
        path: Routes.about,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: Routes.server,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ServerPage(),
      ),
      GoRoute(
        path: Routes.demo,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DemoPage(),
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
    ],
  );
}

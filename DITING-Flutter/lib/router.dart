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
import 'package:diting/routes/standalone_routes.dart';
import 'package:diting/shell/app_shell.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Route table: one shell branch per bottom-bar tab (the indexed stack keeps them alive), secondary
/// pages pushed full screen on the root navigator, mode and onboarding pages outside the shell.
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

  /// Rule pages share one widget and differ only by kind.
  static String rulesOf(String kind) => '$rules/$kind';
}

/// Branch order is fixed so `goBranch` indices stay stable when the user customises
/// which tabs the bottom bar shows.
const _branchOrder = <String>[
  Routes.home,
  Routes.hub,
  Routes.logs,
  Routes.traffic,
  Routes.tools,
  Routes.settings,
];

/// Maps a location to its branch index. Must match the longest prefix: `/` prefixes every
/// absolute path, so the first hit would map `/hub` and `/logs` to home. Falls back to 0
/// (home), which is safer than throwing on a navigation path.
int branchIndexOf(String location) {
  var bestIndex = 0;
  var bestLength = -1;
  for (var index = 0; index < _branchOrder.length; index++) {
    final prefix = _branchOrder[index];
    if (!location.startsWith(prefix)) continue;
    // The prefix must end at a `/` boundary, or `/logsomething` would match `/logs`.
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

/// Root path of a branch, used by the shell to translate `currentIndex` back into a
/// location. The only copy of the order.
String branchLocationOf(int index) =>
    index >= 0 && index < _branchOrder.length ? _branchOrder[index] : Routes.home;

/// Whether the location is a tab root rather than a sub page; this distinguishes
/// switching tabs from pushing, and the two APIs are not interchangeable.
bool isBranchRoot(String location) {
  for (final root in _branchOrder) {
    if (root == location) return true;
  }
  return false;
}

/// Switches to the tab that owns [location] instead of pushing it. Pushing a branch root such as
/// `/traffic` would stack a second copy with a bottom bar outside the `StatefulShellRoute`. Returns
/// false without a shell (before mounting), so the caller falls back to a plain push.
bool goToBranch(BuildContext context, String location) {
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell == null) {
    return false;
  }
  shell.goBranch(branchIndexOf(location));
  return true;
}

/// Opens [location]: switches tabs when it is a branch root, pushes otherwise. Entry
/// points that may hit either (home, hub cards) must go through here.
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
        pageBuilder: (context, state) =>
            androidDefaultPage(state, const BatchEditorPage()),
      ),
      GoRoute(
        path: '${Routes.rules}/:kind',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => androidDefaultPage(
          state,
          RulesPage(kind: state.pathParameters['kind'] ?? 'block'),
        ),
      ),
      GoRoute(
        path: Routes.subscriptions,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            androidDefaultPage(state, const SubscriptionsPage()),
      ),
      GoRoute(
        path: Routes.about,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            androidDefaultPage(state, const AboutPage()),
      ),
      GoRoute(
        path: Routes.modeSelect,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            androidDefaultPage(state, const ModeSelectPage()),
      ),
      GoRoute(
        path: Routes.modeOnboarding,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            androidDefaultPage(state, const ModeOnboardingPage()),
      ),
      // Domain routes live in `lib/routes/<domain>_routes.dart`; a new domain
      // means one more `...<domain>Routes()` entry here.
      ...dashboardRoutes(),
      ...hubRoutes(),
      ...logsRoutes(),
      ...observabilityRoutes(),
      ...configRoutes(),
      ...systemRoutes(),
      ...standaloneRoutes(),
    ],
    // Without this, unmatched routes render a blank page instead of failing, so a missing
    // registration goes unnoticed. `UnknownRoutePage` shows "page not found".
    errorBuilder: (context, state) =>
        UnknownRoutePage(location: state.uri.toString()),
  );
}

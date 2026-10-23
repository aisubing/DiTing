import 'package:diting/pages/config/custom_resources_page.dart';
import 'package:diting/pages/config/icon_sets_page.dart';
import 'package:diting/pages/config/on_demand_page.dart';
import 'package:diting/pages/config/user_agents_page.dart';
import 'package:diting/routes/page.dart';
import 'package:diting/ui/ui.dart';
import 'package:go_router/go_router.dart';

/// Custom resources routes: icon sets, User-Agent and on-demand, all reached
/// through `/config/custom-resources` from the developer page.
abstract final class ConfigPaths {
  /// Entry page listing the three resource tables.
  static const customResources = '/config/custom-resources';
  static const iconSets = '/config/icon-sets';
  static const userAgents = '/config/user-agents';
  static const onDemand = '/config/on-demand';
}

/// Config routes, assembled by `lib/router.dart`.
List<RouteBase> configRoutes() => [
  GoRoute(
    path: ConfigPaths.customResources,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const CustomResourcesConfigPage()),
  ),
  GoRoute(
    path: ConfigPaths.iconSets,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const IconSetsConfigPage()),
  ),
  GoRoute(
    path: ConfigPaths.userAgents,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const UserAgentsConfigPage()),
  ),
  GoRoute(
    path: ConfigPaths.onDemand,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const OnDemandConfigPage()),
  ),
];

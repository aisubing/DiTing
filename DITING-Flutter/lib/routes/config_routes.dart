import 'package:diting/pages/config/custom_resources_page.dart';
import 'package:diting/pages/config/icon_sets_page.dart';
import 'package:diting/pages/config/on_demand_page.dart';
import 'package:diting/pages/config/user_agents_page.dart';
import 'package:diting/ui/ui.dart';
import 'package:go_router/go_router.dart';

/// 资源领域路由：图标集 / User-Agent / 按需连接，以及它们的入口页。
///
/// 上一轮这里挂着 16 条 Clash 内核配置路由（general / network / tun / dns / ntp /
/// sniffer / override / filters / rules / scripts / providers / on-demand …），
/// 全部来自 FlClash。1.4.3 没有内核配置这个概念：它只管 DNS 解析路径、规则、
/// 缓存与上游，没有 TUN 栈、没有 NTP、没有嗅探、没有内核覆写。
///
/// 本轮按「旧版为准」清理后只剩这三张表——它们不是旧版界面，但用户要求保留，
/// 因此统一收敛到 `/config/custom-resources` 一个入口下，由 `/developer`
/// 聚合页统一进入，不再占据设置页与底栏。
abstract final class ConfigPaths {
  /// 资源入口页（图标集 / User-Agent / 按需连接三行）。
  static const customResources = '/config/custom-resources';
  static const iconSets = '/config/icon-sets';
  static const userAgents = '/config/user-agents';
  static const onDemand = '/config/on-demand';
}

/// 资源领域路由表。由 `lib/router.dart` 拼接。
List<RouteBase> configRoutes() => [
  GoRoute(
    path: ConfigPaths.customResources,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const CustomResourcesConfigPage(),
  ),
  GoRoute(
    path: ConfigPaths.iconSets,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const IconSetsConfigPage(),
  ),
  GoRoute(
    path: ConfigPaths.userAgents,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const UserAgentsConfigPage(),
  ),
  GoRoute(
    path: ConfigPaths.onDemand,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const OnDemandConfigPage(),
  ),
];

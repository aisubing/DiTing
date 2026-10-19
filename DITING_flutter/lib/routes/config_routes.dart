import 'package:diting/pages/config/added_rules_page.dart';
import 'package:diting/pages/config/advanced_config_page.dart';
import 'package:diting/pages/config/custom_resources_page.dart';
import 'package:diting/pages/config/dns_page.dart';
import 'package:diting/pages/config/filters_page.dart';
import 'package:diting/pages/config/general_page.dart';
import 'package:diting/pages/config/icon_sets_page.dart';
import 'package:diting/pages/config/network_page.dart';
import 'package:diting/pages/config/ntp_page.dart';
import 'package:diting/pages/config/on_demand_page.dart';
import 'package:diting/pages/config/override_editor_page.dart';
import 'package:diting/pages/config/providers_page.dart';
import 'package:diting/pages/config/scripts_page.dart';
import 'package:diting/pages/config/sniffer_page.dart';
import 'package:diting/pages/config/tun_override_page.dart';
import 'package:diting/pages/config/user_agents_page.dart';
import 'package:diting/ui/ui.dart';
import 'package:go_router/go_router.dart';

/// 配置领域路由（上游 `lib/views/config/`，17 个文件）。
///
/// 上游这些页面全部由 `SettingsRouteActivity` 承载，彼此平级；这里按「网络 /
/// 内核 / 数据」三组排列，仅影响功能中心的展示顺序，不影响路由语义。
abstract final class ConfigPaths {
  static const general = '/config/general';
  static const network = '/config/network';
  static const tun = '/config/tun';
  static const dns = '/config/dns';
  static const ntp = '/config/ntp';
  static const sniffer = '/config/sniffer';
  static const override = '/config/override';
  static const filters = '/config/filters';
  static const rules = '/config/rules';
  static const scripts = '/config/scripts';
  static const providers = '/config/providers';
  static const iconSets = '/config/icon-sets';
  static const userAgents = '/config/user-agents';
  static const onDemand = '/config/on-demand';
  static const advanced = '/config/advanced';
  static const customResources = '/config/custom-resources';
}

/// 配置领域路由表。由 `lib/router.dart` 拼接。
///
/// 一级页面（general / advanced / custom-resources）留在根导航栈上，其余二级
/// 页面同样用 `rootNavigatorKey`：它们是从一级页面 push 上去的全屏页，不该被
/// 底栏遮住。
List<RouteBase> configRoutes() => [
  GoRoute(
    path: ConfigPaths.general,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const GeneralConfigPage(),
  ),
  GoRoute(
    path: ConfigPaths.network,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const NetworkConfigPage(),
  ),
  GoRoute(
    path: ConfigPaths.tun,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const TunOverridePage(),
  ),
  GoRoute(
    path: ConfigPaths.dns,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const DnsOverridePage(),
  ),
  GoRoute(
    path: ConfigPaths.ntp,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const NtpConfigPage(),
  ),
  GoRoute(
    path: ConfigPaths.sniffer,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const SnifferConfigPage(),
  ),
  GoRoute(
    path: ConfigPaths.override,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const OverrideConfigPage(),
  ),
  GoRoute(
    path: ConfigPaths.filters,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const FiltersConfigPage(),
  ),
  GoRoute(
    path: ConfigPaths.rules,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const AddedRulesConfigPage(),
  ),
  GoRoute(
    path: ConfigPaths.scripts,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ScriptsConfigPage(),
  ),
  GoRoute(
    path: ConfigPaths.providers,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ProvidersConfigPage(),
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
  GoRoute(
    path: ConfigPaths.advanced,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const AdvancedConfigPage(),
  ),
  GoRoute(
    path: ConfigPaths.customResources,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const CustomResourcesConfigPage(),
  ),
];

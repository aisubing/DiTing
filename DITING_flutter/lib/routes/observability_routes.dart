import 'package:diting/pages/observability/connections_page.dart';
import 'package:diting/pages/observability/dns_queries_page.dart';
import 'package:diting/pages/observability/requests_page.dart';
import 'package:diting/pages/observability/resources_page.dart';
import 'package:diting/ui/ui.dart';
import 'package:go_router/go_router.dart';

/// 观测领域路由（上游 `lib/views/connection/`、`views/dns_queries.dart`、
/// `views/resources.dart`）。
///
/// 与已有的 `/logs`、`/traffic` 互补：那两个是「概览」，这四个是「明细」。
abstract final class ObservabilityPaths {
  static const connections = '/connections';
  static const requests = '/requests';
  static const dnsQueries = '/dns-queries';
  static const resources = '/resources';
}

/// 观测领域路由表。由 `lib/router.dart` 拼接。
///
/// 四个页面都是顶层页面（`parentNavigatorKey: rootNavigatorKey`）：它们从首页
/// 快捷入口与功能中心直接进入，不挂在任何 tab 之下，返回时不应回到侧栏。
List<RouteBase> observabilityRoutes() => [
  GoRoute(
    path: ObservabilityPaths.connections,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ConnectionsPage(),
  ),
  GoRoute(
    path: ObservabilityPaths.requests,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const RequestsPage(),
  ),
  GoRoute(
    path: ObservabilityPaths.dnsQueries,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const DnsQueriesPage(),
  ),
  GoRoute(
    path: ObservabilityPaths.resources,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ResourcesPage(),
  ),
];

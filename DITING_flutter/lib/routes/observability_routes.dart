import 'package:diting/pages/observability/connections_page.dart';
import 'package:diting/pages/observability/requests_page.dart';
import 'package:diting/pages/observability/resources_page.dart';
import 'package:diting/ui/ui.dart';
import 'package:go_router/go_router.dart';

/// 观测领域路由：请求日志 / 活动连接 / 资源更新。
///
/// 上一轮这里还有 `/dns-queries`：它与 `/requests`（来源选 DNS）读的是同一张
/// `dns_log` 表、同一批六档状态，旧版也只有「请求日志」一个页面（`RequestLogScreen`
/// 里用来源分段切换），因此那条路由是重复入口，本轮删除。
abstract final class ObservabilityPaths {
  /// 活动连接。旧版无对应页面，用户要求保留。
  static const connections = '/connections';

  /// 请求日志：旧版 `RequestLogScreen`。
  static const requests = '/requests';

  /// 资源更新。旧版无对应页面，用户要求保留。
  static const resources = '/resources';
}

/// 观测领域路由表。由 `lib/router.dart` 拼接。
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
    path: ObservabilityPaths.resources,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ResourcesPage(),
  ),
];

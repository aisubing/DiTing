import 'package:diting/pages/observability/connections_page.dart';
import 'package:diting/pages/observability/requests_page.dart';
import 'package:diting/pages/observability/resources_page.dart';
import 'package:diting/routes/page.dart';
import 'package:diting/ui/ui.dart';
import 'package:go_router/go_router.dart';

/// Observability routes: request log, active connections, resource updates.
/// `/dns-queries` was dropped: it duplicated `/requests` with source = DNS.
abstract final class ObservabilityPaths {
  /// Active connections. No upstream page; kept at the user's request.
  static const connections = '/connections';

  /// Request log: upstream `RequestLogScreen`.
  static const requests = '/requests';

  /// Resource updates. No upstream page; kept at the user's request.
  static const resources = '/resources';
}

/// Observability routes.
List<RouteBase> observabilityRoutes() => [
  GoRoute(
    path: ObservabilityPaths.connections,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const ConnectionsPage()),
  ),
  GoRoute(
    path: ObservabilityPaths.requests,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const RequestsPage()),
  ),
  GoRoute(
    path: ObservabilityPaths.resources,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const ResourcesPage()),
  ),
];

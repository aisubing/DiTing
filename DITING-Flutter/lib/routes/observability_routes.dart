import 'package:diting/pages/observability/requests_page.dart';
import 'package:diting/routes/page.dart';
import 'package:diting/ui/ui.dart';
import 'package:go_router/go_router.dart';

/// Observability routes.
/// `/dns-queries` was dropped: it duplicated `/requests` with source = DNS.
/// `/connections` and `/resources` were dropped: they had no backing data source
/// and only rendered placeholder rows.
abstract final class ObservabilityPaths {
  /// Request log: upstream `RequestLogScreen`.
  static const requests = '/requests';
}

/// Observability routes.
List<RouteBase> observabilityRoutes() => [
  GoRoute(
    path: ObservabilityPaths.requests,
    parentNavigatorKey: rootNavigatorKey,
    pageBuilder: (context, state) =>
        androidDefaultPage(state, const RequestsPage()),
  ),
];

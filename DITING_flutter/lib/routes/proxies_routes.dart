import 'package:diting/pages/proxies/proxies_page.dart';
import 'package:diting/pages/proxies/proxy_providers_page.dart';
import 'package:diting/ui/ui.dart';
import 'package:go_router/go_router.dart';

/// 代理领域路由（上游 `lib/views/proxies/`）。
///
/// 代理页是**单页双形态**：tab 模式（分组 chip + 分页）与 list 模式（折叠分组
/// 列表），由设置项 `ProxiesType` 决定，不是两条路由。
abstract final class ProxiesPaths {
  static const proxies = '/proxies';

  /// 代理提供者（外部 provider 列表 + 编辑页）。
  static const providers = '/proxies/providers';
}

/// 代理领域路由表。由 `lib/router.dart` 拼接。
List<RouteBase> proxiesRoutes() => [
  GoRoute(
    path: ProxiesPaths.proxies,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ProxiesPage(),
  ),
  GoRoute(
    path: ProxiesPaths.providers,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ProxyProvidersPage(),
  ),
];

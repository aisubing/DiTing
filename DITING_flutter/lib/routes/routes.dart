/// 各领域路由表的统一出口。
///
/// 第二轮把路由按领域拆开，每个领域一个文件、一个函数：多人并行时各自只改
/// 自己那一份，`lib/router.dart` 只负责拼接，不会成为冲突热点。
///
/// 约定：
/// - 二级页面一律 `parentNavigatorKey: rootNavigatorKey`（全屏、无底栏）；
/// - 路由字符串写在各自领域文件顶部的 `abstract final class XxxPaths` 里，
///   页面内部只引用常量，不写字面量；
/// - 新领域 = 新增一个 `lib/routes/<domain>_routes.dart` + 在 `lib/router.dart`
///   的 `routes:` 列表里展开。
library;

export 'config_routes.dart';
export 'dashboard_routes.dart';
export 'hub_routes.dart';
export 'logs_routes.dart';
export 'observability_routes.dart';
export 'system_routes.dart';

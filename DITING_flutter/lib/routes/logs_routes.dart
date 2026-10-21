import 'package:diting/pages/logs/logs_bootstrap_page.dart';
import 'package:diting/pages/logs/logs_cache_page.dart';
import 'package:diting/pages/logs/logs_race_page.dart';
import 'package:diting/pages/logs/logs_subscription_stats_page.dart';
import 'package:diting/ui/ui.dart';
import 'package:go_router/go_router.dart';

/// 日志仪表盘的下钻页。
///
/// 1.4.3 的日志仪表盘在三种模式下各有一屏卡片，每张卡右上角都能进一个明细页：
/// 缓存热点 → 缓存页、竞速胜出 → 竞速页、Bootstrap DNS → Bootstrap 页、订阅拦截
/// → 订阅统计页。上一轮这些卡片都还在（`/logs`），但下钻页一个都没有，点进去
/// 只能落到「页面不存在」。本轮补齐这四条。
abstract final class LogPaths {
  /// DNS 缓存表（旧版 `DnsCacheScreen`）。
  static const cache = '/logs/cache';

  /// 竞速排行（旧版 `RaceStatsScreen`）。
  static const race = '/logs/race';

  /// Bootstrap DNS 统计（旧版 `BootstrapStatsScreen`）。
  static const bootstrap = '/logs/bootstrap';

  /// 订阅拦截统计（旧版 `SubscriptionInterceptionStatsScreen`）。
  static const subscriptionStats = '/logs/subscription-stats';
}

/// 日志下钻路由表。由 `lib/router.dart` 拼接。
///
/// 四条都挂 `rootNavigatorKey`：它们是盖住整棵树的整页，不应落进底栏所在的
/// 嵌套 navigator，否则底栏会继续显示在这些没有底栏的页面上。
List<RouteBase> logsRoutes() => [
  GoRoute(
    path: LogPaths.cache,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const LogsCachePage(),
  ),
  GoRoute(
    path: LogPaths.race,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const LogsRacePage(),
  ),
  GoRoute(
    path: LogPaths.bootstrap,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const LogsBootstrapPage(),
  ),
  GoRoute(
    path: LogPaths.subscriptionStats,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const LogsSubscriptionStatsPage(),
  ),
];

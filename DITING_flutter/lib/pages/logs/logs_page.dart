import 'package:diting/pages/home/dashboard/cards/log_list_cards.dart';
import 'package:diting/pages/home/dashboard/cards/traffic_monitor_card.dart';
import 'package:diting/pages/home/dashboard/cards/traffic_structure_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/logs/logs_mode_selector.dart';
import 'package:diting/pages/logs/logs_shared.dart';
import 'package:diting/router.dart';
import 'package:diting/routes/routes.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 日志仪表盘（1.4.3 `ModernLogDashboardScreen`）。
///
/// 结构照抄旧版：顶栏标题 + 右上角刷新、正文顶部三选一「日志模式」，正文按模式
/// 换三套卡片组合：
///
/// - `all`（记录全部）：流量监控 + 请求概览 + 今日流量结构 + 最近请求 +
///   缓存热点 + 竞速胜出 + Bootstrap DNS + 规则拦截；
/// - `blockedAndErrors`（仅拦截与错误）：重点记录 + 重点流量结构 +
///   最近拦截与错误 + 规则拦截；
/// - `off`（关闭日志）：隐私模式保护中 + 解析服务概况 + 解析效能概况 +
///   缓存热点 + 竞速胜出 + Bootstrap DNS。
///
/// 每种模式开头都有一句整页说明（旧版 `DashboardHero`），三种模式的文案各不相同。
///
/// 卡片组件与首页**完全共用**（`cards/` 下那批）：三套组合只是「选哪几张、
/// 什么顺序」，不是三份独立布局——旧版那三个 `*ModeDashboard` 函数里大段重复的
/// 列表卡正是重构前的样子。
///
/// 分段控件 `_LogsView {requests, cache, race}` 已删除：旧版没有这个切换，
/// 缓存与竞速是仪表盘卡片的**下钻页**，不是同一屏的三个视图。
class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  @override
  void initState() {
    super.initState();
    // 计数来自原生引擎；打开仪表盘就把它们拉一次，不等下一次生命周期回调。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(workModeProvider) == AppWorkMode.server) {
        ref.read(serverStatusProvider.notifier).syncStatus();
      } else {
        ref.read(powerProvider.notifier).syncStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(logModeProvider);
    // 卡片要读密度作用域（固定高度乘缩放、圆角分两档），与首页挂同一层。
    return DashboardDensityScopeHost(
      child: CommonScaffold(
        title: '日志仪表盘',
        actions: [
          IconButton(
            tooltip: '刷新',
            // 与下钻页同一个 revision：一处刷新，所有读日志表的页面一起重查，
            // 不会出现「仪表盘新了、缓存页还是旧的」。
            onPressed: () => ref.read(dnsLogRevisionProvider.notifier).bump(),
            icon: const GlyphIcon(AppGlyphs.refresh),
          ),
        ],
        body: PageBody(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: LogModeSelector(
                value: mode,
                onChanged: (value) =>
                    ref.read(logModeProvider.notifier).select(value),
              ),
            ),
            const SizedBox(height: 12),
            ..._blocksOf(context, mode),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 三套卡片组合：先整页说明（旧版 `DashboardHero`），再是它那几张块。
  ///
  /// 用语句式 `switch` 而不是 switch 表达式：表达式每个分支只能返回一个值，
  /// 这里每个分支是「说明块 + N 张卡片」，写成表达式得给三个分支各套一层列表
  /// 再展开，可读性更差。
  List<Widget> _blocksOf(BuildContext context, LegacyLogMode mode) {
    switch (mode) {
      case LegacyLogMode.all:
        return [
          const LogsDashboardHero(
            title: '请求日志仪表盘',
            description: '全部 DNS、HTTPS、缓存、竞速与规则拦截的实时概览',
          ),
          ..._allMode(context),
        ];
      case LegacyLogMode.blockedAndErrors:
        return [
          const LogsDashboardHero(
            title: '重点请求仪表盘',
            description: 'DNS 与 HTTPS 拦截、错误、旁路记录及解析状态概览',
          ),
          ..._filteredMode(context),
        ];
      case LegacyLogMode.off:
        return [
          const LogsDashboardHero(
            title: '服务状态与解析概览',
            description: '当前处于隐私模式，不记录请求明细。'
                'DNS 缓存、并发竞速与网络流量监控仍正常运行。',
          ),
          ..._offMode(context),
        ];
    }
  }

  /// 记录全部：八块。
  List<Widget> _allMode(BuildContext context) => [
    _card(
      context,
      TrafficMonitorCard(onDetail: () => context.push(Routes.traffic)),
    ),
    _card(context, const RequestOverviewCard(title: '请求概览')),
    _card(
      context,
      const LogTrafficStructureCard(mode: TrafficStructureMode.all),
    ),
    _card(
      context,
      RecentRequestsLogCard(
        onDetail: () => context.push(ObservabilityPaths.requests),
      ),
    ),
    _card(
      context,
      CacheHotspotsCard(onDetail: () => context.push(LogPaths.cache)),
    ),
    _card(
      context,
      RaceWinnersCard(onDetail: () => context.push(LogPaths.race)),
    ),
    _card(
      context,
      BootstrapDnsCard(onDetail: () => context.push(LogPaths.bootstrap)),
    ),
    _card(
      context,
      RuleBlocksCard(onDetail: () => context.push(LogPaths.subscriptionStats)),
    ),
  ];

  /// 仅拦截与错误：四块。
  ///
  /// 旧版这一档没有「流量监控」卡（`FilteredModeDashboard` 里虽然也判断了
  /// `onNavigateToTrafficStats`，但主页面调用时不传该参数），因此这里也不放。
  List<Widget> _filteredMode(BuildContext context) => [
    _card(context, const FilteredHighlightCard()),
    _card(
      context,
      const LogTrafficStructureCard(mode: TrafficStructureMode.filtered),
    ),
    _card(
      context,
      FilteredRecentLogCard(
        onDetail: () => context.push(ObservabilityPaths.requests),
      ),
    ),
    _card(
      context,
      RuleBlocksCard(onDetail: () => context.push(LogPaths.subscriptionStats)),
    ),
  ];

  /// 关闭日志：六块。
  List<Widget> _offMode(BuildContext context) => [
    _card(context, const PrivacyModeCard()),
    _card(context, const OffModeMetricCard()),
    _card(context, const ResolutionPerfCard()),
    _card(
      context,
      CacheHotspotsCard(onDetail: () => context.push(LogPaths.cache)),
    ),
    _card(
      context,
      RaceWinnersCard(onDetail: () => context.push(LogPaths.race)),
    ),
    _card(
      context,
      BootstrapDnsCard(onDetail: () => context.push(LogPaths.bootstrap)),
    ),
  ];

  /// 卡片统一走仪表盘密度作用域：卡片内部要读 `scale` 与大圆角。
  Widget _card(BuildContext context, Widget child) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: dashboardMobileSideOf(MediaQuery.sizeOf(context).width),
    ),
    child: child,
  );
}

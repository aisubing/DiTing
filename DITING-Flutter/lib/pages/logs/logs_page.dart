import 'package:diting/pages/home/dashboard/cards/log_list_cards.dart';
import 'package:diting/pages/home/dashboard/cards/traffic_monitor_card.dart';
import 'package:diting/pages/home/dashboard/cards/traffic_structure_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
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
/// 结构照抄旧版：顶栏标题 + 右上角刷新、正文按日志模式换三套卡片组合：
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
/// **日志记录范围（记录全部 / 仅拦截与错误 / 关闭日志）不在本页**：它是「日志
/// 怎么记」的设置，属于日志模式页（`/hub/log-retention`）。放在仪表盘顶部会把
/// 「看日志」与「改日志配置」两件事混在一屏，且三行单选项占掉首屏近四成高度，
/// 真正的统计卡被挤到折叠线以下。顶栏保留一个入口指向那一页。
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
    // 一次算好（说明 + 卡片），避免 `_blocksOf` 在 build 里被调两次建出两份节点。
    final blocks = _blocksOf(context, mode);
    // 卡片要读密度作用域（固定高度乘缩放、圆角分两档），与首页挂同一层。
    return DashboardDensityScopeHost(
      child: CommonScaffold(
        title: '日志仪表盘',
        actions: [
          IconButton(
            tooltip: '日志模式',
            onPressed: () => context.push(HubPaths.logRetention),
            icon: const GlyphIcon(AppGlyphs.sliders),
          ),
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
            const SizedBox(height: 8),
            blocks.hero,
            const SizedBox(height: 4),
            _CardColumn(cards: blocks.cards),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 三套卡片组合：先整页说明（旧版 `DashboardHero`），再是它那几张块。
  ///
  /// 返回 `(说明, 卡片列表)` 而不是拼平一个 `List<Widget>`：卡片之间必须有统一
  /// 的 12dp 间距，而「间距」只能由包住它们的 `Column(spacing:)` 提供。上一轮
  /// 把每张卡各自 `Padding(horizontal)` 后直接摊进 `PageBody` 的 `ListView`，
  /// 卡片之间没有任何纵向留白，真机上量到的间距是 **0.0dp**（相邻两张 34dp
  /// 圆角卡直接贴在一起，看起来像一整块被切开的板，也就是「卡片重叠」）。
  ///
  /// 用语句式 `switch` 而不是 switch 表达式：表达式每个分支只能返回一个值，
  /// 这里每个分支是「说明块 + N 张卡片」，写成表达式得给三个分支各套一层列表
  /// 再展开，可读性更差。
  ({Widget hero, List<Widget> cards}) _blocksOf(
    BuildContext context,
    LegacyLogMode mode,
  ) {
    switch (mode) {
      case LegacyLogMode.all:
        return (
          hero: const LogsDashboardHero(
            title: '请求日志仪表盘',
            description: '全部 DNS、HTTPS、缓存、竞速与规则拦截的实时概览',
          ),
          cards: _allMode(context),
        );
      case LegacyLogMode.blockedAndErrors:
        return (
          hero: const LogsDashboardHero(
            title: '重点请求仪表盘',
            description: 'DNS 与 HTTPS 拦截、错误、旁路记录及解析状态概览',
          ),
          cards: _filteredMode(context),
        );
      case LegacyLogMode.off:
        return (
          hero: const LogsDashboardHero(
            title: '服务状态与解析概览',
            description: '当前处于隐私模式，不记录请求明细。'
                'DNS 缓存、并发竞速与网络流量监控仍正常运行。',
          ),
          cards: _offMode(context),
        );
    }
  }

  /// 记录全部：八块。
  ///
  /// 这里返回的是**裸卡片**：横向边距一律由 [_CardColumn] 给，卡片自己不再包
  /// `Padding`。上一轮两处各包了一层同样的 `dashboardMobileSideOf`，真机上叠成
  /// 32dp（首页同一张卡是 16dp），也就是「日志页左右空隙比别处大一倍」。
  List<Widget> _allMode(BuildContext context) => [
    TrafficMonitorCard(onDetail: () => openLocation(context, Routes.traffic)),
    const RequestOverviewCard(title: '请求概览'),
    const LogTrafficStructureCard(mode: TrafficStructureMode.all),
    RecentRequestsLogCard(
      onDetail: () => context.push(ObservabilityPaths.requests),
    ),
    CacheHotspotsCard(onDetail: () => context.push(LogPaths.cache)),
    RaceWinnersCard(onDetail: () => context.push(LogPaths.race)),
    BootstrapDnsCard(onDetail: () => context.push(LogPaths.bootstrap)),
    RuleBlocksCard(onDetail: () => context.push(LogPaths.subscriptionStats)),
  ];

  /// 仅拦截与错误：四块。
  ///
  /// 旧版这一档没有「流量监控」卡（`FilteredModeDashboard` 里虽然也判断了
  /// `onNavigateToTrafficStats`，但主页面调用时不传该参数），因此这里也不放。
  List<Widget> _filteredMode(BuildContext context) => [
    const FilteredHighlightCard(),
    const LogTrafficStructureCard(mode: TrafficStructureMode.filtered),
    FilteredRecentLogCard(
      onDetail: () => context.push(ObservabilityPaths.requests),
    ),
    RuleBlocksCard(onDetail: () => context.push(LogPaths.subscriptionStats)),
  ];

  /// 关闭日志：六块。
  List<Widget> _offMode(BuildContext context) => [
    const PrivacyModeCard(),
    const OffModeMetricCard(),
    const ResolutionPerfCard(),
    CacheHotspotsCard(onDetail: () => context.push(LogPaths.cache)),
    RaceWinnersCard(onDetail: () => context.push(LogPaths.race)),
    BootstrapDnsCard(onDetail: () => context.push(LogPaths.bootstrap)),
  ];
}

/// 卡片列：与首页 `DashboardBoard` 同一套横向边距 + 12dp 纵向间距。
///
/// 抽成组件是为了让「日志页卡片间距」与「首页卡片间距」只有一个来源
/// （`dashboardCardGap`）：两页共用同一批卡片组件，间距也必须一致，
/// 否则同一张「流量监控」卡在两个页面上贴得松紧不同。
class _CardColumn extends StatelessWidget {
  const _CardColumn({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final side = dashboardMobileSideOf(MediaQuery.sizeOf(context).width);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: dashboardCardGap,
        children: cards,
      ),
    );
  }
}

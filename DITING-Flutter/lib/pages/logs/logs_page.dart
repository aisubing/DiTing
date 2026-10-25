import 'package:diting/pages/home/dashboard/cards/log_list_cards.dart';
import 'package:diting/pages/home/dashboard/cards/traffic_monitor_card.dart';
import 'package:diting/pages/home/dashboard/cards/traffic_structure_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/pages/logs/ai_insight_card.dart';
import 'package:diting/pages/logs/logs_shared.dart';
import 'package:diting/router.dart';
import 'package:diting/routes/routes.dart';
import 'package:diting/routes/standalone_routes.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/log_refresh_providers.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Log dashboard, one card set per log mode (all, blocked and errors, off).
class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  LogLiveRefreshNotifier? _logRefresh;

  @override
  void initState() {
    super.initState();
    // Counters come from the native engine; pull them once when the page opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(workModeProvider) == AppWorkMode.server) {
        ref.read(serverStatusProvider.notifier).syncStatus();
      } else {
        ref.read(powerProvider.notifier).syncStatus();
      }
    });
    // These cards read tables the native writers keep filling; share home's timer so the
    // lists update without tapping refresh. Tests disable it.
    _logRefresh = ref.read(logLiveRefreshProvider.notifier);
    _logRefresh!.attachPolling();
  }

  @override
  void dispose() {
    _logRefresh?.detachPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(logModeProvider);
    // Compute hero and cards once so _blocksOf does not build two node trees.
    final blocks = _blocksOf(context, mode);
    // Cards read the density scope, mounted at the same level as the home page.
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
            // Shares one revision with the drill-down pages: one refresh re-queries every
            // log table, so the dashboard and the cache page never disagree.
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

  /// Hero plus cards for one mode. Returns (hero, cards) rather than a flat list because
  /// the 12dp gap can only come from the enclosing Column(spacing:).
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

  /// All-records mode: eight blocks of bare cards. Horizontal padding always comes
  /// from [_CardColumn], never from the cards themselves, or it doubles up.
  List<Widget> _allMode(BuildContext context) => [
    TrafficMonitorCard(
      // Full screen like the hub entry: the bar belongs to the shell, so only a push on the root
      // navigator hides it and gives the title bar a back arrow.
      onDetail: () => pushStandalone(context, Routes.traffic),
    ),
    const RequestOverviewCard(title: '请求概览'),
    const AiInsightCard(),
    const LogTrafficStructureCard(mode: TrafficStructureMode.all),
    RecentRequestsLogCard(
      onDetail: () => context.push(ObservabilityPaths.requests),
    ),
    CacheHotspotsCard(onDetail: () => context.push(LogPaths.cache)),
    RaceWinnersCard(onDetail: () => context.push(LogPaths.race)),
    BootstrapDnsCard(onDetail: () => context.push(LogPaths.bootstrap)),
    RuleBlocksCard(onDetail: () => context.push(LogPaths.subscriptionStats)),
  ];

  /// Blocked-and-errors mode: four blocks, without the traffic monitor card, which
  /// the upstream filtered view also omits.
  List<Widget> _filteredMode(BuildContext context) => [
    const FilteredHighlightCard(),
    const AiInsightCard(),
    const LogTrafficStructureCard(mode: TrafficStructureMode.filtered),
    FilteredRecentLogCard(
      onDetail: () => context.push(ObservabilityPaths.requests),
    ),
    RuleBlocksCard(onDetail: () => context.push(LogPaths.subscriptionStats)),
  ];

  List<Widget> _offMode(BuildContext context) => [
    const PrivacyModeCard(),
    const OffModeMetricCard(),
    const ResolutionPerfCard(),
    CacheHotspotsCard(onDetail: () => context.push(LogPaths.cache)),
    RaceWinnersCard(onDetail: () => context.push(LogPaths.race)),
    BootstrapDnsCard(onDetail: () => context.push(LogPaths.bootstrap)),
  ];
}

/// Takes the gap from dashboardCardGap so both dashboards share the same 12dp rhythm.
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
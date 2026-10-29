import 'package:diting/app/l10n/l10n.dart';
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
import 'package:diting/state/hub_settings_providers.dart';
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
    final showAi = ref.watch(agentKeyConfiguredProvider);
    // Compute hero and cards once so _blocksOf does not build two node trees.
    final blocks = _blocksOf(context, mode, showAi);
    // Cards read the density scope, mounted at the same level as the home page.
    return DashboardDensityScopeHost(
      child: CommonScaffold(
        title: context.l10n.logsDashboardTitle,
        actions: [
          IconButton(
            tooltip: context.l10n.logsModeTooltip,
            onPressed: () => context.push(HubPaths.logRetention),
            icon: const GlyphIcon(AppGlyphs.sliders),
          ),
          IconButton(
            tooltip: context.l10n.logsRefresh,
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
    bool showAi,
  ) {
    switch (mode) {
      case LegacyLogMode.all:
        return (
          hero: LogsDashboardHero(
            title: context.l10n.logsRequestsDashboard,
            description: context.l10n.logsRequestsDashboardBody,
          ),
          cards: _allMode(context, showAi),
        );
      case LegacyLogMode.blockedAndErrors:
        return (
          hero: LogsDashboardHero(
            title: context.l10n.logsFocusedDashboard,
            description: context.l10n.logsFocusedDashboardBody,
          ),
          cards: _filteredMode(context, showAi),
        );
      case LegacyLogMode.off:
        return (
          hero: LogsDashboardHero(
            title: context.l10n.logsServiceOverview,
            description:
                context.l10n.logsPrivacyBody,
          ),
          cards: _offMode(context),
        );
    }
  }

  /// All-records mode: eight blocks of bare cards. Horizontal padding always comes
  /// from [_CardColumn], never from the cards themselves, or it doubles up.
  List<Widget> _allMode(BuildContext context, bool showAi) => [
    TrafficMonitorCard(
      // Full screen like the hub entry: the bar belongs to the shell, so only a push on the root
      // navigator hides it and gives the title bar a back arrow.
      onDetail: () => pushStandalone(context, Routes.traffic),
    ),
    const RequestOverviewCard(),
    if (showAi) const AiInsightCard(),
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
  List<Widget> _filteredMode(BuildContext context, bool showAi) => [
    const FilteredHighlightCard(),
    if (showAi) const AiInsightCard(),
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

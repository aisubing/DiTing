import 'package:diting/pages/home/dashboard/dashboard_board.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/widgets/home_power_button.dart';
import 'package:diting/pages/home/widgets/home_provider_card.dart';
import 'package:diting/pages/home/widgets/home_resolution_card.dart';
import 'package:diting/router.dart';
import 'package:diting/routes/routes.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/log_refresh_providers.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Home page / dashboard: power, tagline, provider, resolution mode, cards. Server mode
/// does not branch here: app_shell swaps the whole tree and would double the bottom bar.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  /// Capture the notifier while mounted: dispose() cannot call ref.read, Riverpod 3
  /// throws when ref is used on an unmounted widget.
  SpeedSeriesNotifier? _speed;
  LogLiveRefreshNotifier? _logRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The provider's own timer drives the curve; home and /traffic share one series,
    // and a second timer would halve the 60-point window. Tests disable it.
    _speed = ref.read(speedSeriesProvider.notifier);
    _speed!.attachPolling();
    // Cache, bootstrap and log cards read tables the native writers fill while the tunnel
    // runs; without this timer they would only refresh on a manual bump. Tests disable it.
    _logRefresh = ref.read(logLiveRefreshProvider.notifier);
    _logRefresh!.attachPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The notification action can stop the tunnel while the app is in the
      // background; re-read the native status instead of trusting local state.
      ref.read(powerProvider.notifier).syncStatus();
      // Server mode can likewise be stopped in the background.
      ref.read(serverStatusProvider.notifier).syncStatus();
    }
  }

  @override
  void dispose() {
    _speed?.detachPolling();
    _logRefresh?.detachPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(workModeProvider);
    final power = ref.watch(powerProvider);
    final sentence = ref.watch(homeSentenceProvider);
    final opacity = ref.watch(homeOpacityProvider);
    final editing = ref.watch(dashboardEditingProvider);
    final scale = DashboardDensityScope.scaleOf(context);
    return DashboardDensityScopeHost(
      child: CommonScaffold(
        title: editing ? '编辑仪表盘' : _titleOf(mode),
        primaryAction: IconButtonData(
          glyph: editing ? AppGlyphs.check : AppGlyphs.customize,
          tooltip: editing ? '完成' : '编辑仪表盘',
          onPressed: () => ref.read(dashboardEditingProvider.notifier).toggle(),
        ),
        // The mode is already in the title, so the bar uses a round icon of the same
        // size as its neighbour instead of a text pill wedged between two buttons.
        actions: [
          if (!editing)
            IconButton(
              tooltip: '切换工作模式',
              onPressed: () => context.push(Routes.modeSelect),
              icon: const GlyphIcon(AppGlyphs.swap),
            ),
        ],
        body: PageBody(
          children: [
            // Edit mode hides the fixed blocks so only cards remain and the drag targets
            // are obvious.
            if (!editing) ...[
              SizedBox(height: 8 * scale),
              Opacity(
                opacity: opacity[HomeLayer.powerButton] ?? 1,
                child: HomePowerButton(
                  state: power,
                  onPressed: () => ref.read(powerProvider.notifier).toggle(),
                ),
              ),
              if (sentence.forState(power) case final text?
                  when text.isNotEmpty)
                Opacity(
                  opacity: opacity[HomeLayer.poem] ?? 1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 20, 32, 4),
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: AppTextStyle.subheadline
                          .of(context)
                          .copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Opacity(
                  opacity: opacity[HomeLayer.providerSelector] ?? 1,
                  child: const HomeProviderCard(),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Opacity(
                  opacity: opacity[HomeLayer.modeButton] ?? 1,
                  child: HomeResolutionCard(mode: mode),
                ),
              ),
              const SizedBox(height: 12),
            ],
            DashboardBoard(
              actions: DashboardCardActions(
                onOpenDetail: (widget) {
                  final path = homeDetailPathOf(widget);
                  if (path != null) context.push(path);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _titleOf(AppWorkMode mode) => switch (mode) {
    AppWorkMode.normal => '谛听 · 普通',
    AppWorkMode.server => '谛听 · 服务器',
    AppWorkMode.express => '谛听 · 极速',
  };
}

extension on ({String running, String stopped}) {
  String? forState(PowerState state) =>
      state.isRunning || state == PowerState.starting ? running : stopped;
}

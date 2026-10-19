import 'package:diting/pages/home/dashboard/dashboard_board.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/widgets/home_power_button.dart';
import 'package:diting/pages/home/widgets/home_provider_card.dart';
import 'package:diting/pages/home/widgets/home_quick_entries.dart';
import 'package:diting/pages/home/widgets/home_resolution_card.dart';
import 'package:diting/router.dart';
import 'package:diting/routes/routes.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 首页 / 仪表盘。
///
/// 结构（对齐上游 `views/dashboard/dashboard.dart` 的移动分支）：
/// 电源区 → 首页句子 → 服务商卡 → 解析模式卡 → **可编排卡片区** → 快捷入口。
///
/// 上游那张「卡片编排 + 编辑模式」的实现在 `dashboard_board.dart`；这里只负责
/// 顶部固定区与编排区的拼接。固定区不参与编排——上游同样把电源区留在了
/// 仪表盘之外（它是 `home.dart` 的层，不是卡片）。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// 速率曲线靠定时器推进：只有页面在树上时才走，离开就停。
  ///
  /// 刻意不用 `AnimationController`：图表要的是「每秒一个新采样点」而不是逐帧
  /// 重绘，用 `Ticker` 会让 60fps 都在重建整棵卡片树。
  ///
  /// 每拍都重建并排帧，因此**测试里必须关掉**（[debugDisableDashboardLiveUpdates]），
  /// 否则 `pumpAndSettle` 永远等不到静止。
  bool _ticking = false;

  @override
  void initState() {
    super.initState();
    _startTicking();
  }

  void _startTicking() {
    if (_ticking || debugDisableDashboardLiveUpdates) {
      return;
    }
    _ticking = true;
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_ticking) {
        return;
      }
      ref.read(speedSeriesProvider.notifier).tick();
      _startTicking();
    });
  }

  @override
  void dispose() {
    _ticking = false;
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
        actions: [
          if (!editing)
            _ModeChip(
              mode: mode,
              onPressed: () => context.push(Routes.modeSelect),
            ),
        ],
        primaryAction: IconButtonData(
          glyph: editing ? AppGlyphs.check : AppGlyphs.customize,
          tooltip: editing ? '完成' : '编辑仪表盘',
          onPressed: () =>
              ref.read(dashboardEditingProvider.notifier).toggle(),
        ),
        menuItems: [
          CommonPopupMenuItem(
            label: '工作模式',
            glyph: AppGlyphs.layers,
            onPressed: () => context.push(Routes.modeSelect),
          ),
          CommonPopupMenuItem(
            label: '三步引导',
            glyph: AppGlyphs.puzzle,
            onPressed: () => context.push(Routes.modeOnboarding),
          ),
          CommonPopupMenuItem(
            label: '代理',
            glyph: AppGlyphs.proxies,
            onPressed: () => context.push(ProxiesPaths.proxies),
          ),
          CommonPopupMenuItem(
            label: '配置档案',
            glyph: AppGlyphs.profiles,
            onPressed: () => context.push(ProfilesPaths.profiles),
          ),
          CommonPopupMenuItem(
            label: '外观',
            glyph: AppGlyphs.palette,
            onPressed: () => context.push(SystemPaths.theme),
          ),
          CommonPopupMenuItem(
            label: '组件画廊',
            glyph: AppGlyphs.sparkle,
            onPressed: () => context.push(Routes.demo),
          ),
        ],
        body: PageBody(
          children: [
            // 编辑态藏掉固定区：上游编辑模式只显示卡片，让「拖什么」一目了然。
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
                      style: AppTextStyle.subheadline.of(context).copyWith(
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
              onOpenConnections: () => context.push(
                ObservabilityPaths.connections,
              ),
              onOpenGroup: (groupName) => context.push(
                ProxiesPaths.proxies,
              ),
              onOpenProfiles: () => context.push(ProfilesPaths.profiles),
            ),
            if (!editing) ...[
              const SizedBox(height: 16),
              HomeQuickEntries(mode: mode),
            ],
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

/// 把 [DashboardDensityScope] 挂到仪表盘子树上。
///
/// 密度由可用宽度与高度共同决定（上游同名判定），因此需要一次 `LayoutBuilder`
/// 才能拿到；文本缩放从 `MediaQuery` 取，与 `AppScopes` 夹过的值一致。
class DashboardDensityScopeHost extends StatelessWidget {
  const DashboardDensityScopeHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width,
          constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height,
        );
        return DashboardDensityScope(
          density: DashboardDensity.of(size),
          scale: MediaQuery.textScalerOf(context).scale(1),
          child: child,
        );
      },
    );
  }
}

/// 句子按电源状态二选一；运行/启动中显示「运行」那句。
extension on ({String running, String stopped}) {
  String? forState(PowerState state) =>
      state.isRunning || state == PowerState.starting ? running : stopped;
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode, required this.onPressed});

  final AppWorkMode mode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TonalChip(
        label: mode.title,
        color: context.colorScheme.primaryContainer,
        foregroundColor: context.colorScheme.onPrimaryContainer,
        onPressed: onPressed,
      ),
    );
  }
}

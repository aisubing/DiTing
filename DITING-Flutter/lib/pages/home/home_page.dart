import 'package:diting/pages/home/dashboard/dashboard_board.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/widgets/home_power_button.dart';
import 'package:diting/pages/home/widgets/home_provider_card.dart';
import 'package:diting/pages/home/widgets/home_resolution_card.dart';
import 'package:diting/router.dart';
import 'package:diting/routes/routes.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 首页 / 仪表盘。
///
/// 结构对齐 1.4.3 的 `MainScreenContent.kt`（`DnsHomeContent`）：
/// 电源区 → 首页句子 → 服务商选择 → 解析模式（含当前解析地址）→ 可编排卡片区。
///
/// 与旧版的三处差异，都是产品决策：
/// 1. 旧版首页只有固定块，本仓保留了「卡片编排 + 编辑模式」
///    （`dashboard_board.dart`）；卡片集前五块照 FlClash 0.9.1 的仪表盘
///    （状态 / 网络速度 / 网络测速 / 内存 / 内网 IP），其余是 1.4.3 真实存在的
///    统计块；
/// 2. 旧版把「DNS 服务详情」画成解析模式按钮**下面**的一段裸文字；这里并进
///    解析模式卡内（`home_resolution_card.dart`），地址与它所属的模式不再分家；
/// 3. 旧版没有快捷入口与顶栏菜单——上一轮的 `HomeQuickEntries` 与服务统计条、
///    以及「工作模式 / 三步引导 / 代理 / 配置档案 / 外观 / 组件画廊」六项菜单
///    已在本轮删除（FlClash 遗留，1.4.3 无对应物）。
///
/// 服务器模式**不在这里分支**：`lib/shell/app_shell.dart` 在壳这一层就把整棵树
/// 换成了 `ServerModeShell`，这里再套一层会出现两套底栏。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  /// 进页面时抓住 notifier 引用。
  ///
  /// `dispose()` 里不能 `ref.read`——Riverpod 3 会抛「Using ref when a widget is
  /// about to or has been unmounted」。缓存在字段里是官方推荐的写法。
  SpeedSeriesNotifier? _speed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 速率曲线由 provider 自己的定时器推进（`SpeedSeriesNotifier.attachPolling`）：
    // 首页与 `/traffic` 共用一条序列，谁在树上谁「持有」它，两处各起一个定时器
    // 会让 60 点窗口缩短一半。测试里 `debugDisableDashboardLiveUpdates` 关掉了
    // 自动推进，否则 `pumpAndSettle` 永远等不到静止。
    _speed = ref.read(speedSeriesProvider.notifier);
    _speed!.attachPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The notification action can stop the tunnel while the app is in the
      // background; re-read the native status instead of trusting local state.
      ref.read(powerProvider.notifier).syncStatus();
      // 服务器模式同样可能在后台被停止（通知栏或系统回收）。
      ref.read(serverStatusProvider.notifier).syncStatus();
    }
  }

  @override
  void dispose() {
    _speed?.detachPolling();
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
        // 模式已在标题里写明，顶栏不再放文字胶囊——它夹在两个圆形按钮之间
        // 显得突兀。改用同尺寸圆形图标，两种动作保持同一种形状。
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
                onOpenRequests: () => context.push(ObservabilityPaths.requests),
                onOpenCache: () => context.push(LogPaths.cache),
                onOpenRace: () => context.push(LogPaths.race),
                onOpenBootstrap: () => context.push(LogPaths.bootstrap),
                onOpenSubscriptionStats: () =>
                    context.push(LogPaths.subscriptionStats),
                onOpenTraffic: () => openLocation(context, Routes.traffic),
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

/// 句子按电源状态二选一；运行/启动中显示「运行」那句。
extension on ({String running, String stopped}) {
  String? forState(PowerState state) =>
      state.isRunning || state == PowerState.starting ? running : stopped;
}

import 'package:diting/app/bootstrap.dart';
import 'package:diting/app/initial_agreement.dart';
import 'package:diting/app/l10n/ui_strings.dart';
import 'package:diting/app/theme/colors.dart';
import 'package:diting/app/theme/manager.dart';
import 'package:diting/router.dart';
import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/auto_update_runner.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 应用根。
///
/// 三个必须按这个顺序摆的层：
/// 1. `MaterialApp` 提供 `Theme` / `MediaQuery` / `Navigator`；
/// 2. [ThemeCrossFade] 包在 `builder` 里，用上一帧截图淡出——它依赖
///    `ThemeData` 每次重建都不相等，因此主题必须走 [AppThemeCache]；
/// 3. [AppScopes] 必须在 `Navigator` **之上**（也就是 `builder` 里），
///    否则浮层路由拿不到 `MeasureScope` / `ViewScope`。
class DitingApp extends ConsumerStatefulWidget {
  const DitingApp({super.key, this.initialLocation});

  /// 仅测试用：直接从某个路由起跑，免得每个用例都要点一路过去。
  final String? initialLocation;

  @override
  ConsumerState<DitingApp> createState() => _DitingAppState();
}

class _DitingAppState extends ConsumerState<DitingApp> {
  final _themes = AppThemeCache();
  late final GoRouter _router = createRouter(
    initialLocation: widget.initialLocation ?? Routes.home,
  );

  /// 自动更新的前台补跑（旧版由 WorkManager 周期任务驱动，本仓没有该调度器）。
  ///
  /// 触发点是「启动」与「回到前台」两处：只在启动检查会让长期挂后台的用户
  /// 永远等不到更新，只在回前台检查会让首启不跑。`_autoUpdateChecked` 只是
  /// 防抖，真正的到期判据在 [AutoUpdateRunner] 里按 `lastAttemptAt` 算。
  AppLifecycleListener? _lifecycle;
  bool _autoUpdateChecking = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _maybeRunAutoUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRunAutoUpdate());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _maybeRunAutoUpdate() async {
    if (_autoUpdateChecking || !mounted) {
      return;
    }
    _autoUpdateChecking = true;
    try {
      final run = await ref.read(autoUpdateRunnerProvider).runIfDue();
      if (!mounted) {
        return;
      }
      if (run.didRun) {
        // 有真实执行才写入「上次自动更新」；跳过（未到期 / 关闭）不刷新时间，
        // 否则页面会把「刚刚检查过」误读成「刚刚更新过」。
        ref.read(autoUpdateLastRunProvider.notifier).record(run);
      }
    } finally {
      _autoUpdateChecking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final palette = ref.watch(paletteProvider);
    final pureBlack = ref.watch(pureBlackProvider);
    final textScale = ref.watch(textScaleProvider);
    final pair = AppThemePair(
      seedColor: palette.effectiveSeed,
      pureBlack: pureBlack,
    );

    return MaterialApp.router(
      title: '谛听 DITING',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      themeMode: switch (mode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      theme: _themes.of(pair.lightSpec),
      darkTheme: _themes.of(pair.darkSpec),
      localizationsDelegates: const [
        AppUiLocalizations.delegate,
        // `DefaultMaterialLocalizations` 只带英文；zh_CN 必须用 intl 生成的
        // 全局实现，否则 AppBar 之类在 build 期直接抛「No MaterialLocalizations」。
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('zh', 'CN')],
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        // `child` 是 Navigator（含当前路由与浮层路由）；scopes 必须在它之上。
        //
        // `LiquidGlassScope` 也挂在这一层：`lib/ui` 的浮条与卡片用它决定要不要
        // 走模糊路径，挂在 Navigator 之下会让浮层里的玻璃效果失效。
        //
        // `LiquidGlassHost` 必须与它成对挂上，而且必须包住**所有**玻璃面：
        // 它负责在合成阶段把玻璃背后的内容抓成一张图，供各个 pane 折射/模糊。
        // 少挂这一层时每个 pane 只能走 `_addFrost` 的兜底——只剩下 tint + 描边，
        // 看起来「玻璃没生效」（本轮真机复现的正是这个：开关切到标准/极致，
        // 浮条渲染与关闭时逐像素相同）。上游 `theme_manager.dart` 里
        // `_LiquidGlassSetting` 也是 Scope + Host 一起挂。
        // 首启「使用须知与免责声明」也挂在这一层（旧版 `InitialAgreementDialog`
        // 在 Activity 里弹一次）：它必须盖住整棵树，包括浮层路由。已同意时
        // `InitialAgreementGate` 直接返回 child，不增加任何布局层级。
        final glass = ref.watch(liquidGlassModeProvider);
        return ThemeCrossFade(
          child: AppSystemUi(
            child: AppScopes(
              textScale: textScale,
              child: LiquidGlassScope(
                enabled: glass.enabled,
                quality: glass.quality,
                child: LiquidGlassHost(
                  enabled: glass.enabled,
                  child: InitialAgreementGate(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

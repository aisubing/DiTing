import 'package:diting/app/bootstrap.dart';
import 'package:diting/app/initial_agreement.dart';
import 'package:diting/app/l10n/ui_strings.dart';
import 'package:diting/app/theme/colors.dart';
import 'package:diting/app/theme/manager.dart';
import 'package:diting/router.dart';
import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/state/appearance_providers.dart';
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
                child: InitialAgreementGate(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

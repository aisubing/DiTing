import 'package:diting/app/bootstrap.dart';
import 'package:diting/app/initial_agreement.dart';
import 'package:diting/app/l10n/ui_strings.dart';
import 'package:diting/app/theme/colors.dart';
import 'package:diting/app/theme/manager.dart';
import 'package:diting/router.dart';
import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/auto_update_runner.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/background_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// App root.
///
/// Layer order matters: [ThemeCrossFade] lives in `builder` and relies on
/// [ThemeData] comparing unequal on every rebuild, so themes must come from
/// [AppThemeCache]. [AppScopes] must also sit above the `Navigator` (i.e. in
/// `builder`), otherwise overlay routes cannot resolve their scopes.
class DitingApp extends ConsumerStatefulWidget {
  const DitingApp({super.key, this.initialLocation});

  /// Test-only: start at a route directly instead of navigating there.
  final String? initialLocation;

  @override
  ConsumerState<DitingApp> createState() => _DitingAppState();
}

class _DitingAppState extends ConsumerState<DitingApp> {
  final _themes = AppThemeCache();
  late final GoRouter _router = createRouter(
    initialLocation: widget.initialLocation ?? Routes.home,
  );

  /// Foreground catch-up for auto update (upstream used a WorkManager job).
  ///
  /// Runs on both start and resume: start-only would starve long-backgrounded
  /// users, resume-only would skip the first launch. `_autoUpdateChecking` is
  /// just a debounce; the real due check lives in [AutoUpdateRunner].
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
        // Only a real run refreshes the timestamp; a skip (not due / disabled)
        // must not be shown as "just updated".
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
    // Custom background: a wallpaper behind the root, pages go transparent.
    final background = ref.watch(customBackgroundProvider);
    final backgroundUri = background.enabled ? background.currentUri : null;
    final showBackground = backgroundUri != null && backgroundUri.isNotEmpty;
    final pair = AppThemePair(
      seedColor: palette.effectiveSeed,
      pureBlack: pureBlack,
      transparentPage: showBackground,
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
        // `DefaultMaterialLocalizations` is English only; zh_CN needs the
        // generated globals or AppBar throws "No MaterialLocalizations".
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('zh', 'CN')],
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        // `child` is the Navigator; all scopes must sit above it.
        //
        // `LiquidGlassScope` and `LiquidGlassHost` are a pair: the host captures
        // what sits behind each glass pane during compositing. Without it panes
        // fall back to tint + border only, which looks like glass is off. The
        // first-launch agreement gate lives here too so it covers overlay
        // routes; once accepted it returns `child` with no extra layout.
        final glass = ref.watch(liquidGlassModeProvider);
        // The background sits below the Navigator so every page's transparent
        // fill shows the same wallpaper, and it fades with the theme cross-fade.
        final content = child ?? const SizedBox.shrink();
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
                    child: showBackground
                        ? AppBackgroundLayer(
                            uri: backgroundUri,
                            child: content,
                          )
                        : content,
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

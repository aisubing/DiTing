/// Entry of the floating log window's own Flutter engine (`floatingLogMain` in `main.dart`).
///
/// The window is a separate engine started by the VPN service, so nothing from the app's
/// provider tree exists here: settings are read once from the same SharedPreferences containers,
/// and the theme, language, font and text scale are rebuilt from them.
library;

import 'dart:async';

import 'package:diting/app/bootstrap.dart';
import 'package:diting/app/l10n/l10n.dart';
import 'package:diting/app/l10n/ui_strings.dart';
import 'package:diting/app/theme/colors.dart';
import 'package:diting/app/theme/manager.dart';
import 'package:diting/data/fonts/font_repository.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/overlay/floating_log_data.dart';
import 'package:diting/overlay/floating_log_panel.dart';
import 'package:diting/overlay/floating_log_rows.dart';
import 'package:diting/state/settings_providers.dart' show AppLanguageMode;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

Future<void> runFloatingLog() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await loadLegacyPrefsStore();
  final settings = LegacySettings(store);
  // Same reason as the app: an unregistered family silently falls back to the system font.
  await FontRepository(settings: settings).registerAll();
  runApp(FloatingLogApp(settings: settings));
}

/// Native side of the window: size, focus and the few actions only Android can take.
class FloatingLogWindowChannel {
  FloatingLogWindowChannel({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.haoze.diting/floating_log_window');

  final MethodChannel _channel;

  /// Resizes the window, which stays hidden until [reveal]. The reply is the side edge the panel
  /// rests on: -1 left, 1 right.
  Future<int> setExpanded(
    bool expanded, {
    Size size = Size.zero,
    double dragStrip = 0,
  }) async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'setExpanded',
        {
          'expanded': expanded,
          'width': size.width.round(),
          'height': size.height.round(),
          'dragStrip': dragStrip.round(),
        },
      );
      return (raw?['side'] as num?)?.sign.toInt() ?? 1;
    } on PlatformException {
      return 1;
    } on MissingPluginException {
      return 1;
    }
  }

  /// Shows the window again once a frame at the new size is on screen.
  Future<void> reveal() => _call('reveal');

  Future<void> setFocusable(bool value) =>
      _call('setFocusable', {'value': value});

  Future<void> openApp() => _call('openApp');

  Future<void> dismiss() => _call('dismiss');

  /// Back reaches the window only while it is focusable, i.e. while the search field is focused.
  void onBack(VoidCallback handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'back') handler();
    });
  }

  Future<void> _call(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // The window is going away; nothing to recover.
    } on MissingPluginException {
      // Widget tests and non-Android hosts.
    }
  }
}

class FloatingLogApp extends StatefulWidget {
  const FloatingLogApp({
    super.key,
    required this.settings,
    this.window,
    this.source,
  });

  final LegacySettings settings;

  /// Replaceable for tests.
  final FloatingLogWindowChannel? window;
  final FloatingLogSource? source;

  @override
  State<FloatingLogApp> createState() => _FloatingLogAppState();
}

class _FloatingLogAppState extends State<FloatingLogApp> {
  final _themes = AppThemeCache();

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final pair = AppThemePair(
      seedColor: AppPalette.fromStorageValue(settings.paletteRaw).effectiveSeed,
      pureBlack: settings.pureBlackEnabled,
      fontFamily: settings.fontFamily,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      themeMode: switch (AppThemeMode.fromStorageValue(settings.themeModeRaw)) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      theme: _themes.of(pair.lightSpec),
      darkTheme: _themes.of(pair.darkSpec),
      locale: AppLanguageMode.fromStorageValue(settings.appLanguageModeRaw)
          .locale,
      localizationsDelegates: const [
        AppUiLocalizations.delegate,
        AppL10n.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppL10n.supportedLocales,
      builder: (context, child) {
        setCurrentL10n(AppL10n.of(context));
        return AppScopes(
          textScale: settings.textScale,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: FloatingLogHost(
        settings: settings,
        window: widget.window ?? FloatingLogWindowChannel(),
        source: widget.source ?? FloatingLogSource(),
      ),
    );
  }
}

/// Panel sizes in dp, indexed by the legacy `floating_log_panel_size` value.
const floatingLogPanelSizes = [Size(300, 380), Size(340, 460), Size(380, 560)];

/// Switches between the ball and the panel and owns the "new blocked" badge.
class FloatingLogHost extends StatefulWidget {
  const FloatingLogHost({
    super.key,
    required this.settings,
    required this.window,
    required this.source,
  });

  final LegacySettings settings;
  final FloatingLogWindowChannel window;
  final FloatingLogSource source;

  @override
  State<FloatingLogHost> createState() => _FloatingLogHostState();
}

class _FloatingLogHostState extends State<FloatingLogHost>
    with SingleTickerProviderStateMixin {
  static const _badgeInterval = Duration(seconds: 4);

  /// Slides the panel in from, and back out to, the screen edge it rests against.
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final _slideCurve = CurvedAnimation(
    parent: _slide,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  int _side = 1;

  bool _expanded = false;
  bool _switching = false;
  late int _sizeIndex = widget.settings.floatingLogPanelSize;

  /// Blocked requests since the panel was last closed; the ball shows the number.
  int _badge = 0;
  int _seenAt = DateTime.now().millisecondsSinceEpoch;
  Timer? _badgeTimer;
  AppLifecycleListener? _lifecycle;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _startBadge();
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _lifecycle?.dispose();
    _slideCurve.dispose();
    _slide.dispose();
    super.dispose();
  }

  /// The native side pauses the engine while the screen is off; polling stops with it.
  void _onLifecycle(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _active) return;
    _active = active;
    if (!_expanded) active ? _startBadge() : _badgeTimer?.cancel();
  }

  void _startBadge() {
    _badgeTimer?.cancel();
    if (!_active) return;
    _badgeTimer = Timer.periodic(_badgeInterval, (_) => _refreshBadge());
  }

  Future<void> _refreshBadge() async {
    final count = await widget.source.blockedSince(_seenAt);
    if (!mounted || _expanded || count == _badge) return;
    setState(() => _badge = count);
  }

  Future<void> _expand() async {
    if (_switching || _expanded) return;
    _switching = true;
    _badgeTimer?.cancel();
    final side = await widget.window.setExpanded(
      true,
      size: floatingLogPanelSizes[_sizeIndex],
      dragStrip: FloatingLogPanel.headerHeight,
    );
    if (!mounted) return;
    _slide.value = 0;
    setState(() {
      _side = side;
      _expanded = true;
      _badge = 0;
    });
    await _revealAfterLayout();
    if (mounted) await _slide.forward();
    _switching = false;
  }

  Future<void> _collapse() async {
    if (_switching || !_expanded) return;
    _switching = true;
    await _slide.reverse();
    await widget.window.setExpanded(false);
    _seenAt = DateTime.now().millisecondsSinceEpoch;
    if (!mounted) return;
    setState(() => _expanded = false);
    await _revealAfterLayout();
    _startBadge();
    _switching = false;
  }

  Future<void> _resize(int index) async {
    if (index == _sizeIndex || _switching) return;
    _switching = true;
    widget.settings.setFloatingLogPanelSize(index);
    setState(() => _sizeIndex = index);
    await widget.window.setExpanded(
      true,
      size: floatingLogPanelSizes[index],
      dragStrip: FloatingLogPanel.headerHeight,
    );
    await _revealAfterLayout();
    _switching = false;
  }

  /// The native window hides itself on every resize: until Flutter lays out at the new size, the
  /// texture shows the old frame stretched over the window. Reveal once that frame is drawn.
  Future<void> _revealAfterLayout() async {
    // One frame for the new window metrics to arrive, one drawn at them.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) await widget.window.reveal();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The window resizes a frame after the state flips; never lay the panel out in the
          // ball's 56 dp square.
          if (_expanded && constraints.maxWidth > 160) {
            return ClipRect(
              child: SlideTransition(
                position: _slideCurve.drive(
                  Tween(begin: Offset(_side.toDouble(), 0), end: Offset.zero),
                ),
                child: FloatingLogPanel(
                  source: widget.source,
                  window: widget.window,
                  sizeIndex: _sizeIndex,
                  onResize: _resize,
                  onCollapse: _collapse,
                ),
              ),
            );
          }
          return Center(
            child: FloatingLogBall(badge: _badge, onTap: _expand),
          );
        },
      ),
    );
  }
}

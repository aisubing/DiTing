import 'package:diting/app/theme/layout.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// The scopes `lib/ui` asserts on, mounted **above the `Navigator`**.
///
/// Every vendored component resolves `MeasureScope`, `ViewScope` and
/// `UiLocalizations` with `assert(scope != null)`, and the overlay helpers
/// (`CommonPopupBox`, `showFloatingDialog`, `showSheet`, `showSnackBar`-alikes)
/// push routes on the nearest `Navigator`. A route's context is a child of the
/// `Navigator`, *not* of whatever sits inside `MaterialApp.home`, so scopes
/// mounted there are invisible to overlay content.
///
/// Mounting them in `MaterialApp.builder` puts them above the `Navigator`,
/// which is the only place that satisfies both. Verified in this repo's test
/// suite (`test/app_shell_test.dart`): dialogs, sheets and popup menus all
/// resolve their scopes from a builder-mounted host.
class AppScopes extends StatelessWidget {
  const AppScopes({super.key, required this.child, this.textScale = 1});

  final Widget child;

  /// Linear text scale the user picked; clamped to [minTextScale]–[maxTextScale]
  /// and then further clamped by the platform's own accessibility setting.
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final scale = clampTextScale(textScale * mediaQuery.textScaler.scale(1));
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: TextScaler.linear(scale),
        // The dock draws its own bottom margin; the framework's inset would
        // double it, so the demo keeps the safe area in one place only.
        viewPadding: mediaQuery.viewPadding,
      ),
      child: MeasureScope(
        measure: Measure.of(context, scale),
        child: ViewScope(
          size: size,
          isMobile: isMobileWidth(size.width),
          child: child,
        ),
      ),
    );
  }
}

/// Applies the status-bar overlay style the current theme asks for.
///
/// `MaterialApp` does this itself for `theme`/`darkTheme`, but only from the
/// resolved theme; a `ThemeCrossFade` wrapping the whole app keeps it out of
/// reach, so the app states it explicitly.
class AppSystemUi extends StatefulWidget {
  const AppSystemUi({super.key, required this.child});

  final Widget child;

  @override
  State<AppSystemUi> createState() => _AppSystemUiState();
}

class _AppSystemUiState extends State<AppSystemUi> {
  Brightness? _applied;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness != _applied) {
      _applied = brightness;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        SystemChrome.setSystemUIOverlayStyle(
          brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
        );
      });
    }
    return widget.child;
  }
}

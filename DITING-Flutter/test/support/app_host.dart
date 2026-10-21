import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'ui_localizations_stub.dart';

/// The theme the demo app builds, assembled the same way
/// `lib/app/theme/manager.dart` does: seed → pure-black pass → shape/surface/
/// type extensions.
ThemeData demoTheme(Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: seededColorScheme(
      seedColor: const Color(0xFF007AFF),
      brightness: brightness,
    ).toPureBlack(false),
  ).withAppShapes.withAppSurfaces.withAppTypography;
}

/// Mounts [child] under the scaffolds the vendored design system asserts on.
///
/// `lib/ui` resolves `MeasureScope`, `ViewScope` and `UiLocalizations` with
/// `assert(scope != null)`, so a bare `MaterialApp(home: …)` throws before it
/// paints.
///
/// The scopes MUST go in `builder`, not in `home:`. `builder`'s `child` is the
/// `Navigator` itself, so the scopes end up *above* it and every route and
/// overlay can see them. Mounting them in `home:` only covers the first route:
/// a `showSheet` / `showFloatingDialog` listener is pushed onto the root
/// `Navigator` *as a sibling of `home:`*, so anything inside the overlay that
/// reads `ViewScope` (e.g. `ViewScope.isMobileOf`) hits
/// `Failed assertion: 'scope != null'`. This was verified with a probe — the
/// app layer does the same thing in `lib/app/bootstrap.dart`, and the two must
/// stay in sync.
class AppHost extends StatefulWidget {
  const AppHost({
    super.key,
    required this.child,
    this.size = const Size(411, 891),
    this.isMobile = true,
    this.brightness = Brightness.light,
  });

  final Widget child;
  final Size size;
  final bool isMobile;
  final Brightness brightness;

  @override
  State<AppHost> createState() => _AppHostState();
}

class _AppHostState extends State<AppHost> {
  late final ThemeData _theme = demoTheme(widget.brightness);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme,
      localizationsDelegates: const [
        StubUiLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
      ],
      builder: (context, child) => MeasureScope(
        measure: Measure.of(context, 1),
        child: ViewScope(
          size: widget.size,
          isMobile: widget.isMobile,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: widget.child,
    );
  }
}

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

import 'ui_localizations_stub.dart';

/// The theme the demo app builds, assembled like `lib/app/theme/manager.dart`
ThemeData demoTheme(Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: seededColorScheme(
      seedColor: const Color(0xFF007AFF),
      brightness: brightness,
    ).toPureBlack(false),
  ).withAppShapes.withAppSurfaces.withAppTypography;
}

/// Mounts [child] with the scopes the vendored design system asserts on. They MUST go in
/// `builder` (above the `Navigator`), not `home:`, so every route and overlay sees them
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

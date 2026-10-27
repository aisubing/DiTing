import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Dashboard density, matching upstream layout.dart: mobile below 640px width.
enum DashboardDensity {
  standard,
  compact,
  mobile;

  bool get isDesktop => this != mobile;

  bool get isCompact => this == compact;

  static DashboardDensity of(Size size) {
    if (size.width < minDesktopWidth) {
      return mobile;
    }
    final narrowColumns =
        dashboardColumnsOf(size.width) == 4 &&
        size.width < minStandardFourColumnWidth;
    return narrowColumns || size.height < minStandardHeight
        ? compact
        : standard;
  }
}

const minDesktopWidth = 640.0;
const minFourColumnWidth = 860.0;
const minStandardFourColumnWidth = 1040.0;
const minStandardHeight = 824.0;
const mobileMaxWidth = 560.0;

int dashboardColumnsOf(double width) => width < minFourColumnWidth ? 2 : 4;

double dashboardMobileSideOf(double width) =>
    math.max(16, (width - mobileMaxWidth) / 2);

/// Every fixed height is scaled by [scale] so enlarged text is not clipped. lib/ui scales
/// text itself; dashboard cards hard-code heights, which must be scaled explicitly.
class DashboardDensityScope extends InheritedWidget {
  const DashboardDensityScope({
    super.key,
    required this.density,
    required this.scale,
    required super.child,
  });

  final DashboardDensity density;
  final double scale;

  static DashboardDensityScope? _maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DashboardDensityScope>();

  static DashboardDensity of(BuildContext context) =>
      _maybeOf(context)?.density ?? DashboardDensity.mobile;

  static double scaleOf(BuildContext context) => _maybeOf(context)?.scale ?? 1;

  @override
  bool updateShouldNotify(DashboardDensityScope oldWidget) =>
      density != oldWidget.density || scale != oldWidget.scale;
}

/// Puts [DashboardDensityScope] above the dashboard subtree. Density needs a
/// LayoutBuilder, text scale comes from MediaQuery; home and the log dashboard share it.
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

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// 仪表盘密度。
///
/// 上游 `views/dashboard/layout.dart:18-38`：宽度 <640 走 `mobile`（单列卡片、
/// 大字号），否则按列数与高度落到 `compact` / `standard`。DITING 是 Android
/// 单栏应用，实际几乎总是 `mobile`，但桌面/Web 调试会跨过 640，因此判定必须
/// 与上游一致，否则同一页面在两种宿主里排版不同。
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

/// 移动端卡片与编辑模式共用的居中列宽。
double dashboardMobileSideOf(double width) =>
    math.max(16, (width - mobileMaxWidth) / 2);

/// 所有固定高度都按 [scale] 放大，让放大字号下文字不被裁切。
///
/// `lib/ui` 里的组件已经自己处理字号缩放；仪表盘卡片有大量写死的高度（图表、
/// 徽标、圆钮），这些必须显式乘缩放，否则 1.4 倍字号会溢出——这是本轮
/// `layout_regression_test` 会抓的回归点。
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

/// 把 [DashboardDensityScope] 挂到仪表盘子树上。
///
/// 密度由可用宽度与高度共同决定（上游同名判定），因此需要一次 `LayoutBuilder`
/// 才能拿到；文本缩放从 `MediaQuery` 取，与 `AppScopes` 夹过的值一致。
///
/// 首页与日志仪表盘都用它：两处的卡片是同一批组件，作用域挂法必须一致，否则
/// 同一张卡在两个页面上的圆角与固定高度会不同。
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

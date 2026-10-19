// 移动端布局常量。上游对应 `DITING lib/common/layout.dart` 与
// `lib/common/constant.dart`；本仓库只保留演示页面真正用得到的部分。
//
// `maxMobileWidth` 决定 `ViewScope.isMobile`：≤600 时浮条 + 底部面板，
// 否则侧栏 + 桌面转场。Android 上通常不会跨过 600，但桌面/Web 调试会，
// 因此判定必须与上游一致，否则同一页面在两种宿主里布局不同。

/// 宽度 ≤ 该值判定为 mobile 布局。
const maxMobileWidth = 600.0;

/// 宽度 ≤ 该值判定为 laptop；其后为 desktop。Android 用不到，保留以对齐上游。
const maxLaptopWidth = 840.0;

/// 文本缩放上限（`MediaQuery.textScaler` 的线性系数）。
const maxTextScale = 1.4;

/// 文本缩放下限。
const minTextScale = 0.8;

/// 浮条（`NavigationDock`）容纳的下标上限：超过后改用 `NavigationBar`。
const maxDockDestinations = 5;

/// [maxMobileWidth] 的判定，宿主与测试共用同一口径。
bool isMobileWidth(double width) => width <= maxMobileWidth;

/// 把任意来源的文本缩放夹到 [minTextScale]–[maxTextScale]。
double clampTextScale(double scale) =>
    scale.clamp(minTextScale, maxTextScale);

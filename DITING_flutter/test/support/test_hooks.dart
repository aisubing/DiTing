import 'package:diting/state/dashboard_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// 全局测试前置：把「会自己排帧」的演示功能关掉。
///
/// 目前只有一项：仪表盘的速率曲线每秒推进一个采样点。它是永不停歇的周期
/// 回调，每拍都重建并排一帧，于是任何 `pumpAndSettle` 都会等到超时
/// （`pumpAndSettle timed out`）。这不是页面 bug——真机上它就该一直动——
/// 但测试里「结算」的前提是没有待处理帧，两者不可兼得。
///
/// 任何挂载 `DitingApp`（含首页）的测试文件都必须在自己的 `main()` 顶部调
/// 一次 [installGlobalTestHooks]。忘了的表现是 `pumpAndSettle timed out`，
/// 且栈里能看到 `LineChart`。
void installGlobalTestHooks() {
  setUp(() {
    debugDisableDashboardLiveUpdates = true;
  });
  tearDown(() {
    debugDisableDashboardLiveUpdates = false;
  });
}

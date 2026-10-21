import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/settings_providers.dart';
// `Override` 不在 `flutter_riverpod.dart` 的公开导出里，只在 `misc.dart`。
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// 挂载 `DitingApp` 前必须调一次：关掉自排帧的演示动画、跳过首启免责声明。
///
/// ## 为什么要关仪表盘实时刷新
///
/// 仪表盘的速率曲线每秒推进一个采样点。它是永不停歇的周期回调，每拍都重建并
/// 排一帧，于是任何 `pumpAndSettle` 都会等到超时（`pumpAndSettle timed out`）。
/// 这不是页面 bug——真机上它就该一直动——但测试里「结算」的前提是没有待处理帧，
/// 两者不可兼得。
///
/// ## 首启免责声明为什么要跳过
///
/// 第三轮把旧版的「使用须知与免责声明」补成了应用层首启弹窗
/// （`lib/app/initial_agreement.dart`，挂在 `DitingApp.builder` 里）。未确认时它
/// 盖一层**模糊遮罩 + 模态对话框**，于是：
/// - `find.text('…')` 仍能找到下层文字（widget 树还在），但 `tap` 会被遮罩吃掉；
/// - 表现是一堆与功能无关的点击失败 + 「the finder corresponds to this
///   RenderBox」的命中测试警告，而不是「弹窗挡住了」这种一眼能懂的错。
///
/// 因此默认把 `initialAgreementProvider` 覆盖成「已同意」。要测弹窗本身的用例
/// 传 `skipInitialAgreement: false`，否则测的永远是「已同意」分支。
void installGlobalTestHooks({bool skipInitialAgreement = true}) {
  setUp(() {
    debugDisableDashboardLiveUpdates = true;
  });
  tearDown(() {
    debugDisableDashboardLiveUpdates = false;
  });
}

/// 所有挂载 `DitingApp` 的测试都应把这份列表塞进 `ProviderScope`。
///
/// 集中在一处的原因：之前每个测试文件各写一份 `ProviderScope(child: DitingApp(…))`，
/// 新增一条全局前置（本次的首启弹窗）就要改十几个文件，而漏改的那个文件只会以
/// 「点不到」的形式失败，看不出根因。
List<Override> appTestOverrides({bool skipInitialAgreement = true}) => [
  if (skipInitialAgreement)
    initialAgreementProvider.overrideWith(InitialAgreementAccepted.new),
];

/// 始终返回「已同意」的实现，供 [appTestOverrides] 注入。
class InitialAgreementAccepted extends InitialAgreementNotifier {
  @override
  bool build() => true;
}

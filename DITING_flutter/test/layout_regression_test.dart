import 'package:diting/app/app.dart';
import 'package:diting/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// 全路由 × 多尺寸的布局回归。
///
/// `app_shell_test.dart` 只保证「路由能构建」，那是 411×891 一档下的结果。
/// 真实溢出多半只在小屏或超大字号下出现，所以这里在 3 档宽度上各跑一遍，
/// 并在最窄档再叠一次 1.4 倍字号（`clampTextScale` 的上界）。
///
/// 溢出在 widget 测试里会以 `FlutterError` 形式冒泡到 `takeException()`，
/// 不需要额外断言 `RenderFlex`。
void main() {
  /// 覆盖所有路由；`/rules/*` 三种 kind 都要单独点，因为它们分支不同。
  const routes = <String>[
    Routes.home,
    Routes.hub,
    Routes.logs,
    Routes.traffic,
    Routes.tools,
    Routes.settings,
    '/rules/block',
    '/rules/allow',
    '/rules/rewrite',
    Routes.batchEditor,
    Routes.subscriptions,
    Routes.apps,
    Routes.agent,
    Routes.about,
    Routes.server,
    Routes.demo,
    Routes.modeSelect,
    Routes.modeOnboarding,
  ];

  /// (标签, 逻辑尺寸)。320 是 iPhone SE 一代宽度，412 是主流 Android，
  /// 834 是 iPad 竖屏——跨过 `maxMobileWidth = 600` 这个断点。
  const sizes = <(String, Size)>[
    ('se', Size(320, 568)),
    ('pixel', Size(412, 915)),
    ('tablet', Size(834, 1112)),
  ];

  Future<void> pumpAt(
    WidgetTester tester, {
    required String route,
    required Size size,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(child: DitingApp(initialLocation: route)),
    );
    // 本地化 delegate 异步加载，首帧后再推一帧才有文案。
    await tester.pump();
    await tester.pumpAndSettle();
  }

  for (final (sizeLabel, size) in sizes) {
    testWidgets('所有路由在 $sizeLabel 尺寸下无溢出', (tester) async {
      for (final route in routes) {
        await pumpAt(tester, route: route, size: size);
        expect(
          tester.takeException(),
          isNull,
          reason: '$route 在 $sizeLabel (${size.width}x${size.height}) 布局异常',
        );
      }
    });
  }

  testWidgets('小屏 + 1.4 倍字号下所有路由无溢出', (tester) async {
    // 1.4 是 clampTextScale 的上界，也是本工程承诺支持的最大字号。
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final route in routes) {
      await pumpAt(tester, route: route, size: const Size(320, 568));
      expect(
        tester.takeException(),
        isNull,
        reason: '$route 在 320 宽 + 1.4 倍字号下布局异常',
      );
    }
  });
}

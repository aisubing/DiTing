import 'package:diting/app/app.dart';
import 'package:diting/pages/system/unknown_route_page.dart';
import 'package:diting/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'route_catalog_test.dart' show idRoutes, topLevelRoutes;
import 'support/test_hooks.dart';

/// Layout regression over every route at three widths; overflow surfaces via `takeException()`
void main() {
  installGlobalTestHooks();

  /// Every route, including the rule, subscription and mode pages beyond the six tabs.
  final routes = <String>[
    Routes.hub,
    Routes.logs,
    Routes.traffic,
    Routes.tools,
    Routes.settings,
    Routes.batchEditor,
    Routes.subscriptions,
    Routes.about,
    Routes.modeSelect,
    Routes.modeOnboarding,
    ...topLevelRoutes.values,
    ...idRoutes.values,
  ];

  /// (label, logical size): 320 iPhone SE, 412 mainstream Android, 834 iPad, crossing the 600
  /// breakpoint
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
      ProviderScope(
        overrides: appTestOverrides(),
        child: DitingApp(initialLocation: route),
      ),
    );
    // The localization delegate loads async: pump once more for labels.
    await tester.pump();
    await tester.pumpAndSettle();
  }

  for (final (sizeLabel, size) in sizes) {
    testWidgets('所有路由在 $sizeLabel 尺寸下无溢出', (tester) async {
      for (final route in routes) {
        await pumpAt(tester, route: route, size: size);
        expectNoLayoutFailure(tester, '$route 在 $sizeLabel (${size.width}x${size.height})');
      }
    });
  }

  testWidgets('小屏 + 1.4 倍字号下所有路由无溢出', (tester) async {
    // 1.4 is the `clampTextScale` upper bound, the largest size supported.
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final route in routes) {
      await pumpAt(tester, route: route, size: const Size(320, 568));
      expectNoLayoutFailure(tester, '$route 在 320 宽 + 1.4 倍字号下');
    }
  });
}

/// One pump must neither throw nor fall through to the unregistered-route fallback page.
void expectNoLayoutFailure(WidgetTester tester, String context) {
  expect(tester.takeException(), isNull, reason: '$context 布局异常');
  expect(
    find.byType(UnknownRoutePage),
    findsNothing,
    reason: '$context 路由未注册，落到了兜底页',
  );
}

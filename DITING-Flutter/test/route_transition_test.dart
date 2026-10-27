import 'package:diting/app/app.dart';
import 'package:diting/app/theme/manager.dart';
import 'package:diting/pages/about/about_page.dart';
import 'package:diting/router.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'support/test_hooks.dart';

/// Guards second-level pages are full-screen with the Android transition: `builder:`-only routes
/// get `NoTransitionPage`, and a theme without `TargetPlatform.android` falls back to zoom
void main() {
  installGlobalTestHooks();

  testWidgets('二级页 push 出来的是带转场的 MaterialPage', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(overrides: appTestOverrides(), child: const DitingApp()),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(NavigationDock).first))
        .push(Routes.about);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // Mid-transition: `/about` is mounted but not yet in place.
    expect(find.byType(AboutPage), findsOneWidget);
    final route = ModalRoute.of(tester.element(find.byType(AboutPage)));
    expect(route, isNotNull);
    expect(
      route!.transitionDuration,
      greaterThan(Duration.zero),
      reason: '没有转场时长 = go_router 退化成 `NoTransitionPage`，页面是硬切的',
    );

    // Still moving: animation below 1 and the position differs from the final one.
    expect(route.animation!.value, lessThan(1.0));
    final midX = tester.getTopLeft(find.byType(AboutPage)).dx;
    await tester.pumpAndSettle();
    final settledX = tester.getTopLeft(find.byType(AboutPage)).dx;
    expect(
      midX,
      isNot(closeTo(settledX, 0.5)),
      reason: '转场期间页面的横向位置必须和落位后不同，否则动画没生效',
    );
    expect(route.animation!.value, 1.0);

    expect(
      find.byWidgetPredicate((widget) => widget is NoTransitionPage),
      findsNothing,
      reason:
          '路由用了 `builder:` 而不是 `pageBuilder`：go_router 的 '
          '`isMaterialApp` 认不出 material_ui 的 MaterialApp，会退化成无转场页',
    );
  });

  test('安卓的转场就是系统默认的那个 builder', () {
    final theme = buildAppTheme(
      const AppThemeSpec(
        seedColor: Color(0xFF007AFF),
        brightness: Brightness.light,
      ),
    );
    final builder = theme.pageTransitionsTheme.builders[TargetPlatform.android];
    expect(
      builder,
      isA<PredictiveBackPageTransitionsBuilder>(),
      reason:
          '缺省会兜底到 ZoomPageTransitionsBuilder，那是 Android 10 的动画，'
          '不是用户要的系统默认转场',
    );
  });
}

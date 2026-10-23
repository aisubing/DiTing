import 'package:diting/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/app_host.dart';

/// Guards that the scopes sit above the `Navigator`: mounted in `home:` they only cover the
/// first route, and overlay content reading `ViewScope` asserts
void main() {
  /// Reads `ViewScope` from overlay content; only works with scopes above Navigator.
  Widget sheetBodyThatReadsScopes() => Builder(
    builder: (context) {
      final isMobile = ViewScope.isMobileOf(context);
      final width = ViewScope.sizeOf(context).width;
      return Text('sheet:$isMobile:$width');
    },
  );

  testWidgets('宿主 AppHost 的 scopes 覆盖浮层内容', (tester) async {
    await tester.pumpWidget(
      AppHost(
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showSheet(
                  context: context,
                  builder: (_) => SizedBox(
                    height: 200,
                    child: sheetBodyThatReadsScopes(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 411 is the default AppHost width.
    expect(find.text('sheet:true:411.0'), findsOneWidget);
  });

  testWidgets('反例：scopes 装 home: 时浮层读 scope 会 assert', (tester) async {
    // Reproduces the wrong placement on purpose, proving this catches the regression.
    await tester.pumpWidget(
      MaterialApp(
        theme: demoTheme(Brightness.light),
        home: Builder(
          builder: (outer) => MeasureScope(
            measure: Measure.of(outer, 1),
            child: ViewScope(
              size: const Size(411, 891),
              isMobile: true,
              child: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => showSheet(
                        context: context,
                        builder: (_) => SizedBox(
                          height: 200,
                          child: sheetBodyThatReadsScopes(),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final error = tester.takeException();
    expect(error, isNotNull, reason: 'home: 装法必须能被这条用例抓出来');
    expect('$error', contains('No ViewScope found'));
  });
}


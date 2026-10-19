import 'package:diting/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/app_host.dart';

/// 守住「scopes 必须在 `Navigator` 之上」这条不变量。
///
/// 这是本会话里被误判过两次的地方：旧版 `AGENT_MISTAKES.md` 与旧版
/// `test/support/app_host.dart` 都声称 scopes 要装在 `home:`，理由是
/// 「装 `builder` 会让浮层报 `Navigator operation requested with a context
/// that does not include a Navigator`」。实测两个方向都能 push，真正的差别
/// 在**浮层内容能不能读到 scope**：`showSheet` / `showFloatingDialog` 的
/// 监听器是挂在根 `Navigator` 上的、与 `home:` **平级**的兄弟路由，所以
/// `home:` 里的 scopes 覆盖不到它，浮层内一读 `ViewScope` 就 assert。
///
/// 下面两条用例把两种装法的行为差异钉住，防止有人再把它改回 `home:`。
void main() {
  /// 浮层内容里主动读 `ViewScope`；只有在 scopes 位于 Navigator 之上时才会成功。
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
    // 411 是 AppHost 的默认宽度。
    expect(find.text('sheet:true:411.0'), findsOneWidget);
  });

  testWidgets('反例：scopes 装 home: 时浮层读 scope 会 assert', (tester) async {
    // 故意复刻错误装法，证明这条用例确实能抓到回归。
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


import 'package:diting/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/app_host.dart';

/// 移植层的最小球探：`lib/ui` 里每个组件都通过 `assert(scope != null)` 依赖
/// [MeasureScope]/[ViewScope]/[UiLocalizations]，且浮层需要 Navigator 之上的
/// 上下文。这里用 [AppHost] 一次性装好这些前置条件，再逐个挂载公开 API。
void main() {
  Widget host(Widget child) => AppHost(child: child);

  testWidgets('CommonScaffold 渲染标题与内容', (tester) async {
    await tester.pumpWidget(
      host(
        CommonScaffold(
          title: '测试',
          body: ListView(children: const [ListItem(title: Text('一行'))]),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('测试'), findsOneWidget);
    expect(find.text('一行'), findsOneWidget);
  });

  testWidgets('ListItem 具名构造器', (tester) async {
    await tester.pumpWidget(
      host(
        Scaffold(
          body: ListView(
            children: [
              ListItem(title: const Text('默认')),
              ListItem(
                title: const Text('开关'),
                trailing: Switch(value: true, onChanged: (_) {}),
              ),
              ListItem<int>.options(
                title: const Text('选项'),
                options: const [1, 2],
                value: 1,
                textBuilder: (value) => '$value',
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('默认'), findsOneWidget);
    expect(find.text('选项'), findsOneWidget);
  });

  testWidgets('NavigationDock 与 insetOf', (tester) async {
    late double inset;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            inset = NavigationDock.insetOf(context);
            return Scaffold(
              body: NavigationDock(
                destinations: const [
                  NavigationDockDestination(
                    glyph: AppGlyphs.dashboard,
                    label: '首页',
                  ),
                  NavigationDockDestination(glyph: AppGlyphs.settings, label: '设置'),
                ],
                selectedIndex: 0,
                onSelected: (_) {},
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(NavigationDock), findsOneWidget);
    // 62dp 浮条 + 21dp 边距（MediaQuery 底部安全区为 0）。
    expect(inset, greaterThan(62));
  });

  testWidgets('NullStatus 空状态', (tester) async {
    await tester.pumpWidget(
      host(
        const Scaffold(
          body: NullStatus(label: '暂无内容', description: '换个关键词试试'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('暂无内容'), findsOneWidget);
  });

  testWidgets('CommonCircleLoading 旋转', (tester) async {
    await tester.pumpWidget(host(const Center(child: CommonCircleLoading())));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CommonCircleLoading), findsOneWidget);
  });

  testWidgets('CommonPopupMenu 弹出并可关闭', (tester) async {
    await tester.pumpWidget(
      host(
        Scaffold(
          body: Builder(
            builder: (outer) => Center(
              child: CommonPopupBox(
                targetBuilder: (open) =>
                    TextButton(onPressed: open, child: const Text('弹菜单')),
                popupBuilder: (_) => CommonPopupMenu(
                  items: [
                    CommonPopupMenuItem(label: '第一项', onPressed: () {}),
                    CommonPopupMenuItem(label: '删除', danger: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('弹菜单'));
    await tester.pumpAndSettle();
    expect(find.text('第一项'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('第一项'));
    await tester.pumpAndSettle();
    expect(find.text('第一项'), findsNothing);
  });

  testWidgets('showFloatingDialog 弹出并可关闭', (tester) async {
    await tester.pumpWidget(
      host(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showFloatingDialog(
                  context: context,
                  child: const Text('对话框内容'),
                ),
                child: const Text('弹对话框'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('弹对话框'));
    await tester.pumpAndSettle();
    expect(find.text('对话框内容'), findsOneWidget);

    // 遮罩可点空关闭；这里用路由出栈验证同一语义，避开遮罩动画的时序。
    Navigator.of(tester.element(find.text('对话框内容'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('对话框内容'), findsNothing);
  });

  testWidgets('showSheet 弹出底部面板', (tester) async {
    await tester.pumpWidget(
      host(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showSheet(
                  context: context,
                  builder: (_) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('底部面板'),
                  ),
                ),
                child: const Text('弹面板'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('弹面板'));
    await tester.pumpAndSettle();
    expect(find.text('底部面板'), findsOneWidget);
  });
}

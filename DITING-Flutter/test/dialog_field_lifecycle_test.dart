// 弹窗输入框的生命周期回归。
//
// 缺陷形态：把 TextEditingController 建在调用方、`await showFloatingDialog(...)`
// 之后立刻 `dispose()`。`pop` 一调用弹窗的 future 就完成，而退场动画
// （`_alertDuration` = 404 ms）还没跑完、`TextField` 仍在树上挂着这个
// controller；此时释放会让输入框在动画中途重建到已失效的依赖上，在模拟器上
// 直接整屏红：
//
//   framework.dart: Failed assertion: line 6281 pos 12:
//   '_dependents.isEmpty': is not true.
//
// 只在输入框获得过焦点（软键盘弹出过）时触发，所以「点开 → 点保存」的用例
// 会漏掉它。下面这条先让输入框拿到焦点再提交，并把退场动画完整跑完，断言
// 全程没有异常。
//
// 注意 import 必须是 `package:material_ui/material_ui.dart`：项目用的设计系统
// 是 material_ui 这份 fork，`TextField` 断言的是**它自己的** `Material`
// 祖先。从 `package:flutter/material.dart` 引入的 TextField 在 material_ui 的
// `Material`（或这里 AppHost 的 `MaterialApp`）下会报「No Material widget found」。
import 'package:diting/pages/system/demo_page_notice.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/app_host.dart';

void main() {
  testWidgets('弹窗输入框聚焦后提交不会踩 framework 断言', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      AppHost(
        child: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  submitted = await showFloatingDialog<String>(
                    context: context,
                    child: const _FieldDialog(),
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    // 关键一步：让输入框真正拿到焦点（真机上这一步会拉起软键盘）。
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'api.example.com');
    await tester.pump();

    await tester.tap(find.text('提交'));
    // 先只走一帧让 pop 发生，再把退场动画跑完——崩溃就发生在这一段。
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(submitted, 'api.example.com');
  });

  testWidgets('演示页标注文案只有一处定义', (tester) async {
    // 五个页面共用同一句，措辞漂移过一次，这里钉住。
    expect(DemoPageNotice.label, '演示页：不属于旧版 1.4.3 的界面');
  });
}

/// 与生产代码同构的最小弹窗：控制器由 `State` 持有。
class _FieldDialog extends StatefulWidget {
  const _FieldDialog();

  @override
  State<_FieldDialog> createState() => _FieldDialogState();
}

class _FieldDialogState extends State<_FieldDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '输入',
      hasFields: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('提交'),
        ),
      ],
      child: TextField(controller: _controller),
    );
  }
}

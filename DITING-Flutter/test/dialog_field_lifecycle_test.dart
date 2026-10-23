// Regression: disposing the controller right after `showFloatingDialog` returns kills the field
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

    // Let the field really take focus; on a device this raises the keyboard.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'api.example.com');
    await tester.pump();

    await tester.tap(find.text('提交'));
    // One frame lets pop happen, then finish the exit animation: the crash is here.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(submitted, 'api.example.com');
  });

  testWidgets('演示页标注文案只有一处定义', (tester) async {
    // Five pages share this wording; it drifted once, so pin it.
    expect(DemoPageNotice.label, '演示页：不属于旧版 1.4.3 的界面');
  });
}

/// Minimal dialog shaped like production: the controller is owned by `State`.
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

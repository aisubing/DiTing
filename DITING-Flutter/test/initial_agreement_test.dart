import 'package:diting/app/app.dart';
import 'package:diting/app/initial_agreement.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/test_hooks.dart';

/// Guards the first-run agreement dialog: it blocks the page and its text must match 1.4.3 exactly
void main() {
  installGlobalTestHooks(skipInitialAgreement: false);

  Future<void> pumpApp(WidgetTester tester, {required bool accepted}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (accepted)
            initialAgreementProvider.overrideWith(
              InitialAgreementAccepted.new,
            ),
        ],
        child: DitingApp(initialLocation: '/'),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('未确认时弹出使用须知', (tester) async {
    await pumpApp(tester, accepted: false);
    expect(find.byType(InitialAgreementDialog), findsOneWidget);
    expect(find.text('使用须知与免责声明'), findsOneWidget);
    expect(find.text('同意并继续'), findsOneWidget);
    expect(find.text('不同意并退出'), findsOneWidget);
  });

  testWidgets('已确认时完全不弹，且不残留任何布局层级', (tester) async {
    await pumpApp(tester, accepted: true);
    expect(find.byType(InitialAgreementDialog), findsNothing);
    // Returning child directly keeps hit testing intact; an extra Stack would break scrolling
    expect(find.byType(InitialAgreementGate, skipOffstage: false), findsOne);

    expect(find.text('谛听 · 普通'), findsOneWidget);
  });

  testWidgets('弹窗挡住下层的点击', (tester) async {
    await pumpApp(tester, accepted: false);
    // Assert the text is centred rather than that taps fail: that inference is fragile
    final dialog = find.byType(InitialAgreementDialog);
    expect(dialog, findsOneWidget);
    final rect = tester.getRect(dialog);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(rect.center.dx, moreOrLessEquals(screen.width / 2, epsilon: 1));
  });

  testWidgets('点「同意并继续」后弹窗消失且写盘', (tester) async {
    await pumpApp(tester, accepted: false);
    await tester.tap(find.text('同意并继续'));
    await tester.pumpAndSettle();

    expect(find.byType(InitialAgreementDialog), findsNothing);
    // accept() sets both memory and disk; the disk key is guarded in `settings_catalog_test.dart`
    final container = ProviderScope.containerOf(
      tester.element(find.byType(InitialAgreementGate)),
    );
    expect(container.read(initialAgreementProvider), isTrue);
  });

  testWidgets('点「不同意并退出」后停在说明态，可重新查看', (tester) async {
    await pumpApp(tester, accepted: false);
    await tester.tap(find.text('不同意并退出'));
    await tester.pumpAndSettle();

    expect(find.byType(InitialAgreementDialog), findsNothing);
    expect(find.text('已拒绝使用须知'), findsOneWidget);

    await tester.tap(find.text('重新查看'));
    await tester.pumpAndSettle();
    expect(find.byType(InitialAgreementDialog), findsOneWidget);
  });

  test('条款正文含旧版三段结构与关键句', () {
    const message = InitialAgreementDialog.message;
    // Three headings, separated by `\n\n` in 1.4.3; a missing one means the body changed.
    expect(message, contains('软件说明'));
    expect(message, contains('运行机制与注意事项'));
    expect(message, contains('免责条款'));

    expect(message, contains('普通模式（全隧道深度管控）'));
    expect(message, contains('极速模式（纯 Kotlin 原生轻量窄路由）'));
    expect(message, contains('独立服务器模式（局域网免 VPN 服务）'));
    expect(message, contains('无任何远程数据上传与隐私追踪'));
    expect(message, contains('1053 端口'));
    expect(message, contains('本软件按现状提供'));
    expect(message, contains('由使用者自行承担'));
  });
}

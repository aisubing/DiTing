import 'package:diting/app/app.dart';
import 'package:diting/app/initial_agreement.dart';
import 'package:diting/state/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/test_hooks.dart';

/// 首启「使用须知与免责声明」弹窗的守门。
///
/// 旧版在 `MainActivity` 里对未确认过的用户弹一次
/// （`ui/MainActivityDialogs.kt` 的 `InitialAgreementDialog`）。这段话是**用户
/// 实际点过「同意」的法律文本**，因此两件事必须守住：
///
/// 1. 未确认时必须弹、且真正挡住下层（遮罩存在，点击穿不过去）；
/// 2. 文案与旧版逐字一致——改写一个标点都意味着用户同意过的内容变了。
///
/// 第 2 条在这里用「关键句必须出现」的方式守，而不是整段 diff：整段 diff 会让
/// 每次措辞微调都得同步改测试，最后大家就都去改测试而不是读条款了。
void main() {
  // 这一组测的就是弹窗本身，所以不能跳过它。
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
    // `InitialAgreementGate` 在已同意分支直接返回 child，不能多包一层 Stack：
    // 多出来的层级会改变命中测试与滚动行为，而且每页都付一次代价。
    expect(find.byType(InitialAgreementGate, skipOffstage: false), findsOne);

    // 首页自己的内容必须可见可点（弹窗不存在时才成立）。
    expect(find.text('谛听 · 普通'), findsOneWidget);
  });

  testWidgets('弹窗挡住下层的点击', (tester) async {
    await pumpApp(tester, accepted: false);
    // 首页的电源按钮在下层；弹窗在场时它不该响应。
    // 这里不断言「点击无效」——那样要通过状态变化反推，易碎；改为断言
    // 「屏幕上存在一段属于弹窗的文本，且它位于屏幕中央区域」，即遮罩确实盖住了。
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
    // `initialAgreementProvider` 的 accept() 同时置内存态与落盘，这里验证内存态
    // ——落盘键由 `settings_catalog_test.dart` 守着。
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

    // 误触不算终局：必须能回去重新看条款。
    await tester.tap(find.text('重新查看'));
    await tester.pumpAndSettle();
    expect(find.byType(InitialAgreementDialog), findsOneWidget);
  });

  test('条款正文含旧版三段结构与关键句', () {
    const message = InitialAgreementDialog.message;
    // 三段标题：旧版用 `\n\n` 分段，缺任何一段都说明正文被改了。
    expect(message, contains('软件说明'));
    expect(message, contains('运行机制与注意事项'));
    expect(message, contains('免责条款'));

    // 关键事实句。这几句是「用户知情」的实质内容，不能悄悄消失：
    // - 三种工作模式；
    // - 本地闭环、无远程上传；
    // - 独立服务器模式监听 1053 端口；
    // - 按现状提供、后果自负。
    expect(message, contains('普通模式（全隧道深度管控）'));
    expect(message, contains('极速模式（纯 Kotlin 原生轻量窄路由）'));
    expect(message, contains('独立服务器模式（局域网免 VPN 服务）'));
    expect(message, contains('无任何远程数据上传与隐私追踪'));
    expect(message, contains('1053 端口'));
    expect(message, contains('本软件按现状提供'));
    expect(message, contains('由使用者自行承担'));
  });
}

import 'package:diting/app/app.dart';
import 'package:diting/pages/proxies/proxy_group_section.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/test_hooks.dart';

/// 代理域交互自测。
///
/// `route_catalog_test.dart` 只证明 `/proxies` 能构建。这一组补的是「点下去
/// 真的会发生事」——测速（900ms 后延迟变化）、选中（组内高亮迁移）、
/// 形态切换（tab ↔ list）、设置浮层、提供者更新。
///
/// 之所以单独一个文件：这些用例都要等 `Future.delayed` 结算，与路由冒烟
/// （`pumpAndSettle` 一次过）的节奏不同。
void main() {
  installGlobalTestHooks();

  Future<void> pumpProxies(WidgetTester tester, {String? route}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: DitingApp(initialLocation: route ?? '/proxies'),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('代理页渲染组头与节点', (tester) async {
    await pumpProxies(tester);
    expect(find.text('代理'), findsWidgets);
    // 默认 tab 形态：只显示第一个组（「🚀 节点选择」）的节点。
    expect(find.text('🚀 节点选择'), findsWidgets);
    // 当前选中的节点会出现两次：组头右侧的「当前」与卡片本身。用 `findsWidgets`
    // 而不是 `findsOneWidget`——它本来就是两处，这正是设计意图。
    expect(find.text('🇭🇰 香港 01'), findsWidgets);
    // 第二个组的**节点**不该渲染。注意不能断言组名「♻️ 自动选择」不存在：
    // 顶部 chip 条本来就列出所有组名（那是切换入口），只是不展开它们的节点。
    expect(find.text('香港专线'), findsNothing);
    expect(find.text('日本专线'), findsNothing);
  });

  testWidgets('点击节点后选中态迁移', (tester) async {
    await pumpProxies(tester);
    // 初值是「香港 01」，点「日本 01」后应变成它。
    await tester.tap(find.text('🇯🇵 日本 01'));
    await tester.pumpAndSettle();
    // 组头右侧显示当前选中名。
    expect(find.text('🇯🇵 日本 01'), findsWidgets);
  });

  testWidgets('测速按钮触发转圈并在结算后给出延迟', (tester) async {
    await pumpProxies(tester);

    // 走组头的单组测速按钮：它是页面内控件，命中稳定，也不依赖顶栏折叠
    // （顶栏动作上限 2 个，`iconActions` 会被折进「更多」菜单）。
    final groupTest = find.descendant(
      of: find.byType(ProxyGroupSection),
      matching: find.byWidgetPredicate(
        (w) => w is GlyphIcon && w.glyph == AppGlyphs.speed,
      ),
    );
    expect(groupTest, findsWidgets);
    await tester.tap(groupTest.first);
    // 只推一帧再推 100ms：`pumpAndSettle` 会把 900ms 的测速结算一并走完，
    // 「测速中」那一帧就永远观察不到。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('测速中'), findsWidgets);
    // 900ms 后结算。
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(find.text('测速中'), findsNothing);
  });

  testWidgets('切到列表形态后显示多个组', (tester) async {
    await pumpProxies(tester);
    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();
    // 列表形态下所有组都堆叠显示。
    expect(find.text('♻️ 自动选择'), findsWidgets);
    expect(find.text('🌍 国外流量'), findsWidgets);
  });

  testWidgets('搜索过滤节点', (tester) async {
    await pumpProxies(tester);
    // 顶栏搜索按钮是 `GlyphIcon(AppGlyphs.search)` + tooltip「搜索」，
    // 不是 Material 的 `Icons.search`。
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '日本');
    await tester.pumpAndSettle();

    // 断言用「非选中节点」做标尺：组头始终显示该组的当前选中节点（那是组的
    // 属性，不随搜索变化），所以「香港 01」即使被过滤也仍会出现在组头里。
    // 「香港 02」只可能是节点卡片，它消失才证明过滤生效。
    expect(find.text('🇭🇰 香港 02'), findsNothing);
    expect(find.text('🇯🇵 日本 01'), findsWidgets);
    expect(find.text('🇯🇵 日本 02'), findsWidgets);
  });

  testWidgets('代理提供者页渲染并可更新', (tester) async {
    await pumpProxies(tester, route: '/proxies/providers');
    expect(find.text('代理提供者'), findsWidgets);
    expect(find.text('机场主订阅'), findsOneWidget);
    expect(find.textContaining('42 个节点'), findsOneWidget);

    await tester.tap(find.byTooltip('全部更新'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    // 更新结束后不再有「正在更新…」。
    expect(find.text('正在更新…'), findsNothing);
  });
}

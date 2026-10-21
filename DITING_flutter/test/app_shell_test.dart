import 'package:diting/app/app.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/vpn/vpn_bridge.dart';
import 'package:diting/pages/hub/feature_hub_page.dart';
import 'package:diting/pages/home/widgets/home_power_button.dart';
import 'package:diting/router.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'route_catalog_test.dart' show idRoutes, topLevelRoutes;
import 'support/fake_vpn_controller.dart';
import 'support/test_hooks.dart';

/// 整机冒烟：把真实 `DitingApp`（含路由、主题、scopes）挂起来。
///
/// 这组用例守的是三件容易悄悄坏掉的事：
/// 1. scopes 挂在 `Navigator` 之上——浮层路由拿得到 `MeasureScope`/`ViewScope`；
/// 2. 底栏 tab 切换不重建 branch（`indexedStack` 保活）；
/// 3. 每个路由都能 build 且不 assert。
void main() {
  installGlobalTestHooks();

  Future<void> pumpApp(
    WidgetTester tester, {
    String? initialLocation,
    FakeVpnController? vpn,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appTestOverrides(),
          if (vpn != null) vpnControllerProvider.overrideWithValue(vpn),
        ],
        child: DitingApp(initialLocation: initialLocation),
      ),
    );
    // LocalizationsDelegate.load 是异步的，首帧之后要再 pump 一次才拿到文案。
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('首页渲染标题、电源按钮与底栏', (tester) async {
    await pumpApp(tester);
    expect(find.text('谛听 · 普通'), findsOneWidget);
    expect(find.byType(HomePowerButton), findsOneWidget);
    expect(find.byType(NavigationDock), findsOneWidget);
  });

  testWidgets('电源按钮经历启动中并回到运行态', (tester) async {
    final fake = FakeVpnController(
      delay: const Duration(milliseconds: 200),
    )..statusValue = const VpnStatus(running: true, persisted: true);
    await pumpApp(tester, vpn: fake);
    await tester.tap(find.byType(HomePowerButton));
    await tester.pump();
    expect(find.byType(CommonCircleLoading), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(CommonCircleLoading), findsNothing);
    // 圆钮下面不再写「停止」：状态改由语义标签承载（视觉上由运行/停止两态的
    // 配色区分）。所以这里断言语义标签，而不是可见文本。
    expect(find.bySemanticsLabel('停止'), findsOneWidget);
  });

  testWidgets('底栏切页后 branch 保留状态', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('功能中心'));
    await tester.pumpAndSettle();
    // 断言分类标题而不是卡片文案：卡片标题会与底栏项重名（「日志」既是底栏
    // tab 也是卡片），`findsOneWidget` 必然失败。分类标题只在功能中心出现。
    expect(
      find.descendant(
        of: find.byType(FeatureHubPage),
        matching: find.text(mockFeatureCategories.first.title),
      ),
      findsWidgets,
    );    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    expect(find.text('谛听 · 普通'), findsOneWidget);
  });

  testWidgets('浮层（面板）在 scopes 之上可弹出', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('解析服务商'));
    await tester.pumpAndSettle();
    expect(find.text('选择解析服务商'), findsOneWidget);
    // 预设名在 DNS/DoH/DoT 三组里重复，这里只验证点选后面板关闭。
    await tester.tap(find.text('腾讯云 DNSPod').first);
    await tester.pumpAndSettle();
    expect(find.text('选择解析服务商'), findsNothing);
  });

  testWidgets('浮条高度不截断页面的滚动视口', (tester) async {
    await pumpApp(tester, initialLocation: Routes.settings);
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final list = find.descendant(
      of: find.byType(PageBody),
      matching: find.byType(ListView),
    );
    // `SafeArea` 会把外壳注入的浮条高度变成底部内边距，滚动视口便停在浮条
    // 上沿；页面应一直铺到屏幕底，由 `DockSpacer` 在内容末尾给浮条让位。
    expect(tester.getRect(list).bottom, screenHeight);
  });

  testWidgets('订阅页读真实表：无旧库时是空状态而不是 mock 订阅', (tester) async {
    await pumpApp(tester, initialLocation: Routes.subscriptions);
    // 测试宿主没有 1.4.3 数据库文件，`LegacyDatabase.open` 返回 null，页面必须
    // 渲染空状态。这里同时反证 mock 播种已删除：旧文案「AdGuard 基础」不该出现。
    expect(find.text('AdGuard 基础'), findsNothing);
    expect(find.text('EasyList China'), findsNothing);
    expect(find.text('还没有订阅'), findsOneWidget);
    // 边界说明必须始终可见：本轮只下载正文与统计行数，不入规则表。
    expect(find.textContaining('规则解析与入库将在后续版本接入'), findsWidgets);
  });

  testWidgets('每个路由都能构建', (tester) async {
    for (final route in _routes) {
      await pumpApp(tester, initialLocation: route);
      expect(tester.takeException(), isNull, reason: '路由 $route 构建抛异常');
    }
  });
}

/// 冒烟用的路由清单。
///
/// 与 `route_catalog_test.dart` 的两张表合并使用，而不是各写一份：三份清单必然
/// 漂移，而漂移的表现是「新页面只在一个测试里被覆盖」，不报错、只留洞。
final _routes = <String>[
  Routes.home,
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

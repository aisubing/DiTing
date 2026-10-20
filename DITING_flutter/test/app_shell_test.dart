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
    expect(find.text('停止'), findsOneWidget);
  });

  testWidgets('底栏切页后 branch 保留状态', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('功能中心'));
    await tester.pumpAndSettle();
    // 断言分类标题而不是卡片文案：卡片标题会与底栏项重名（「代理」既是底栏
    // tab 也是卡片），`findsOneWidget` 必然失败。分类标题只在功能中心出现。
    expect(
      find.descendant(
        of: find.byType(FeatureHubPage),
        matching: find.text(mockFeatureCategories.first.title),
      ),
      findsWidgets,
    );
    await tester.tap(find.text('首页'));
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

  testWidgets('首页统计条读当日聚合而不是 mock 常量', (tester) async {
    await pumpApp(tester);
    // 统计条在仪表盘卡片下方：直接跳到底，避免 scrollUntilVisible 对
    // 「ListView 包 Scrollable」这类层级差异敏感。
    final scrollable = find
        .descendant(
          of: find.byType(PageBody),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    // 停止态三格归零 / 破折号：数字不再是 mockServiceStatsSnapshot 里
    // 写死的 28,471 / 98% / 14ms。
    expect(find.text('28,471'), findsNothing);
    expect(find.text('缓存命中'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
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

  testWidgets('网络工具页不再显示 mock 统计数字', (tester) async {
    await pumpApp(tester, initialLocation: Routes.tools);
    // `mockServiceStats.averageLatencyMs`(14ms) / `uptimeLabel`(3小时42分) 已移除，
    // 顶部信息条改读 networkInfo()；无原生通道时三格都是破折号。
    expect(find.text('3小时42分'), findsNothing);
    expect(find.text('当前解析'), findsNothing);
    expect(find.text('活动接口'), findsOneWidget);
    expect(find.text('本机地址'), findsOneWidget);
    // 「网络测速」面板已删除（无真实后端）。
    expect(find.text('网络测速'), findsNothing);
  });

  testWidgets('每个路由都能构建', (tester) async {
    for (final route in _routes) {
      await pumpApp(tester, initialLocation: route);
      expect(tester.takeException(), isNull, reason: '路由 $route 构建抛异常');
    }
  });
}

const _routes = <String>[
  Routes.home,
  Routes.hub,
  Routes.logs,
  Routes.traffic,
  Routes.tools,
  Routes.settings,
  '/rules/block',
  Routes.batchEditor,
  Routes.subscriptions,
  Routes.apps,
  Routes.agent,
  Routes.about,
  Routes.server,
  Routes.demo,
  Routes.modeSelect,
  Routes.modeOnboarding,
];

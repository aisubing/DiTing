import 'package:diting/app/app.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/vpn/vpn_bridge.dart';
import 'package:diting/pages/hub/feature_hub_page.dart';
import 'package:diting/pages/home/dashboard/cards/network_speed_card.dart';
import 'package:diting/pages/home/widgets/home_power_button.dart';
import 'package:diting/pages/settings/settings_page.dart';
import 'package:diting/pages/tools/tools_page.dart';
import 'package:diting/pages/traffic/traffic_page.dart';
import 'package:diting/router.dart';
import 'package:diting/state/appearance_providers.dart';
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
    List<BottomBarDestination>? dock,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appTestOverrides(),
          if (vpn != null) vpnControllerProvider.overrideWithValue(vpn),
          if (dock != null) bottomBarProvider.overrideWith(() => _Dock(dock)),
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
    // 解析链已移植：文案必须改成「解析并写入规则库」，不能还挂着旧免责说明。
    expect(find.textContaining('解析并写入规则库'), findsWidgets);
    expect(find.textContaining('后续版本接入'), findsNothing);
  });

  testWidgets('每个路由都能构建', (tester) async {
    for (final route in _routes) {
      await pumpApp(tester, initialLocation: route);
      expect(tester.takeException(), isNull, reason: '路由 $route 构建抛异常');
    }
  });

  group('底栏点击落到正确的 tab', () {
    // 回归：底栏回调给的是 destinations 下标，`goBranch` 要的是 branch 下标。
    // 两者顺序不同（branch 固定六项，底栏是它的子集），直接透传会让「网络工具」
    // 打开日志仪表盘、「设置」打开流量统计。用户现场配的就是这四项，因此这里
    // 用同一套顺序覆盖——默认的「首页 / 功能中心 / 日志仪表盘」恰好顺序对齐，
    // 反而照不出错位。
    const userDock = [
      BottomBarDestination.home,
      BottomBarDestination.featureHub,
      BottomBarDestination.networkTools,
      BottomBarDestination.settings,
    ];

    testWidgets('四个底栏项各自打开自己的页面', (tester) async {
      await pumpApp(tester, dock: userDock);
      const expectations = {
        '功能中心': FeatureHubPage,
        '网络工具': ToolsPage,
        '设置': SettingsPage,
      };
      for (final entry in expectations.entries) {
        await tester.tap(find.text(entry.key).last);
        await tester.pumpAndSettle();
        expect(
          find.byType(entry.value),
          findsOneWidget,
          reason: '点「${entry.key}」应打开 ${entry.value}',
        );
      }
    });

    // 回归：功能中心里「应用流量统计」「网络诊断」「其他设置」指向的是别的
    // tab 的根路径。push 这些路径会复制一份带底栏的壳，那条底栏切不动 branch，
    // 用户被卡住——必须走 `goBranch`。
    testWidgets('功能中心里指向其它 tab 的卡片切 tab 而不是叠页', (tester) async {
      await pumpApp(tester, initialLocation: Routes.hub, dock: userDock);
      final shellsBefore = find.byType(Scaffold).evaluate().length;
      final card = find.text('应用流量统计');
      // 手动拖到正文中部：`ensureVisible` 会把目标顶到标题栏底下，点它会打偏。
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(TrafficPage), findsOneWidget);
      // 换 tab 不新增页面栈：壳的数量不变，也没有多出一条返回键的二级页。
      expect(find.byType(Scaffold).evaluate().length, shellsBefore);
      expect(find.byType(BackButton), findsNothing);
      // 再点底栏「首页」必须真的回得去（旧实现会留在复制出来的那一页上）。
      await tester.tap(find.text('首页').last);
      await tester.pumpAndSettle();
      expect(find.text('谛听 · 普通'), findsOneWidget);
    });

    testWidgets('首页网络速度卡进入流量统计后可切回其它 tab', (tester) async {
      await pumpApp(tester, dock: userDock);
      final detail = find.descendant(
        of: find.byType(NetworkSpeedCard),
        matching: find.byTooltip('详情'),
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(detail);
      await tester.pumpAndSettle();
      expect(find.byType(TrafficPage), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      await tester.tap(find.text('设置').last);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });
}

/// 测试用的底栏配置：只换首页列表，不落盘。
class _Dock extends BottomBarNotifier {
  _Dock(this._dock);

  final List<BottomBarDestination> _dock;

  @override
  List<BottomBarDestination> build() => _dock;
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

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

import 'support/fake_vpn_controller.dart';
import 'support/test_hooks.dart';

/// Whole-app smoke test of `DitingApp`: scopes above `Navigator`, tab state, route building
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
    await tester.pump();
    await tester.pumpAndSettle();
  }

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
    expect(find.bySemanticsLabel('停止'), findsOneWidget);
  });

  testWidgets('底栏切页后 branch 保留状态', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('功能中心'));
    await tester.pumpAndSettle();
    // Assert category headings: card titles collide with bottom-bar labels
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
    // `SafeArea` would pad the dock inset into the scroll view; `DockSpacer` gives way instead
    expect(tester.getRect(list).bottom, screenHeight);
  });

  testWidgets('订阅页读真实表：无旧库时是空状态而不是 mock 订阅', (tester) async {
    await pumpApp(tester, initialLocation: Routes.subscriptions);
    // No 1.4.3 database on the test host, so the page renders its empty state
    expect(find.text('AdGuard 基础'), findsNothing);
    expect(find.text('EasyList China'), findsNothing);
    expect(find.text('还没有订阅'), findsOneWidget);
    expect(find.textContaining('解析并写入规则库'), findsWidgets);
    expect(find.textContaining('后续版本接入'), findsNothing);
  });

  group('底栏点击落到正确的 tab', () {
    // Regression: the bar reports destination indices, `goBranch` wants branch indices
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

    // Regression: hub entries pointing at other tabs' roots clone the shell
    testWidgets('功能中心里指向其它 tab 的卡片切 tab 而不是叠页', (tester) async {
      await pumpApp(tester, initialLocation: Routes.hub, dock: userDock);
      final shellsBefore = find.byType(Scaffold).evaluate().length;
      final card = find.text('应用流量统计');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(TrafficPage), findsOneWidget);
      expect(find.byType(Scaffold).evaluate().length, shellsBefore);
      expect(find.byType(BackButton), findsNothing);
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

    // Regression: a page outside the bar must report -1, not light up "home"
    testWidgets('当前页不在底栏里时底栏不点亮任何一项', (tester) async {
      await pumpApp(tester, initialLocation: Routes.traffic, dock: userDock);
      final dock = tester.widget<NavigationDock>(find.byType(NavigationDock));
      expect(dock.selectedIndex, -1);
    });
  });
}

class _Dock extends BottomBarNotifier {
  _Dock(this._dock);

  final List<BottomBarDestination> _dock;

  @override
  List<BottomBarDestination> build() => _dock;
}

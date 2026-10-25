import 'package:diting/app/app.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/pages/system/unknown_route_page.dart';
import 'package:diting/router.dart';
import 'package:diting/routes/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/test_hooks.dart';

/// Guards that every hub card points at a registered route; per-route layout and fallback are
/// covered by `layout_regression_test.dart`, which pumps the same catalogue at three sizes
void main() {
  installGlobalTestHooks();

  Future<void> pumpAt(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: appTestOverrides(),
        child: DitingApp(initialLocation: location),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// Asserts the mounted page neither threw nor landed on the fallback page.
  void expectReached(WidgetTester tester, String route, String label) {
    expect(tester.takeException(), isNull, reason: '$label ($route) 构建抛异常');
    expect(
      find.byType(UnknownRoutePage),
      findsNothing,
      reason: '$label ($route) 没有注册：落到了未知路由兜底页',
    );
  }

  group('功能中心卡片可达', () {
    testWidgets('每张卡片的 route 都能构建', (tester) async {
      // Deduplicate: several entries can point at the same page.
      final routes = <String>{
        for (final category in mockFeatureCategories)
          for (final card in category.cards) card.route,
      };
      expect(routes, isNotEmpty);

      for (final route in routes) {
        await pumpAt(tester, route);
        expectReached(tester, route, '功能中心卡片');
      }
    });
  });

  group('兜底页', () {
    testWidgets('未注册的路径落到 UnknownRoutePage', (tester) async {
      await pumpAt(tester, '/definitely/not/a/route');
      expect(find.byType(UnknownRoutePage), findsOneWidget);
      expect(find.text('/definitely/not/a/route'), findsOneWidget);
    });
  });
}

/// First-level pages, everything without path parameters; shared with `layout_regression_test.dart`
final Map<String, String> topLevelRoutes = {
  '首页': DashboardPaths.dashboard,
  '请求': ObservabilityPaths.requests,
  '主题': SystemPaths.theme,
  '日夜模式': SystemPaths.dayNight,
  '主题色配置': SystemPaths.colorStyle,
  '首页透明度': SystemPaths.homeOpacity,
  '底栏自定义': SystemPaths.bottomBar,
  '首页句子': SystemPaths.homeSentence,
  '通知栏设置': SystemPaths.notification,
  '软件背景': SystemPaths.background,
  '字体设置': SystemPaths.fontFamily,
  '字号': SystemPaths.fontSize,
  '前后台行为': SystemPaths.foregroundBackground,
  '语言设置': SystemPaths.language,
  '开发者': SystemPaths.developer,
  '赞助': SystemPaths.sponsor,
  'IP 质量': SystemPaths.ipQuality,
  '组件画廊': SystemPaths.demo,
  '缓存表': LogPaths.cache,
  '竞速排行': LogPaths.race,
  'Bootstrap DNS': LogPaths.bootstrap,
  '订阅拦截统计': LogPaths.subscriptionStats,
  'User-Agent': ConfigPaths.userAgents,
  '按需连接': ConfigPaths.onDemand,
  '自定义资源': ConfigPaths.customResources,
  '服务商管理': HubPaths.providerManagement,
  '引导解析设置': HubPaths.bootstrap,
  '解析模式': HubPaths.resolution,
  '单一服务配置': HubPaths.resolutionMode('single'),
  '智能选择配置': HubPaths.resolutionMode('smart'),
  '最快响应配置': HubPaths.resolutionMode('parallel'),
  '依次尝试配置': HubPaths.resolutionMode('backup'),
  '缓存设置': HubPaths.cache,
  '规则控制': HubPaths.ruleControl,
  '拦截响应': HubPaths.blockResponse,
  '自动更新设置': HubPaths.autoUpdate,
  '镜像站模板': HubPaths.mirrorTemplates,
  '应用独立规则': HubPaths.appRules,
  '禁止联网应用': HubPaths.blockedApps,
  '排除应用': HubPaths.excludedApps,
  'HTTPS 流量检查': HubPaths.httpInspection,
  'HTTPS 目标应用': HubPaths.httpInspectionApps,
  'CA 证书设置': HubPaths.caCertificate,
  'CA 证书指南': HubPaths.caGuide,
  '出站代理': HubPaths.outboundProxy,
  '出站代理应用': HubPaths.outboundProxyApps,
  'AI 分析': HubPaths.agentApi,
  'AI 厂商管理': HubPaths.agentProviders,
  'AI 参数与提示词': HubPaths.agentParams,
  '服务显示': HubPaths.providerVisibility,
  '隐藏功能': HubPaths.hiddenFeatures,
  '日志模式': HubPaths.logRetention,
  '故障排查': HubPaths.troubleshooting,
  '数据清理': HubPaths.dataCleanup,
  '备份与迁移': HubPaths.configTransfer,
  'WebDAV 云同步': HubPaths.configTransferWebdav,
  '赞助者名单': HubPaths.sponsorList,
  '共建者名单': HubPaths.coBuilders,
  '订阅': Routes.subscriptions,
  '关于': Routes.about,
  '批量编辑': Routes.batchEditor,
  '模式选择': Routes.modeSelect,
  '模式引导': Routes.modeOnboarding,
};

/// Second-level pages with path parameters: ids must exist in the mock data, or the branch proves
/// nothing
final Map<String, String> idRoutes = {
  '规则-黑名单': Routes.rulesOf('block'),
  '规则-白名单': Routes.rulesOf('allow'),
  '规则-覆写': Routes.rulesOf('rewrite'),
};

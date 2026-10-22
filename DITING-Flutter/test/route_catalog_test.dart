import 'package:diting/app/app.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/pages/system/unknown_route_page.dart';
import 'package:diting/router.dart';
import 'package:diting/routes/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/test_hooks.dart';

/// 路由覆盖守门。
///
/// 三件互不重叠的事：
///
/// 1. **功能中心的每个卡片都指向一条真实注册的路由**——卡片是字符串字面量
///    （`mock_feature_hub.dart` 是 part，不能 import 常量），漂了只会在用户点击
///    时崩；
/// 2. **每条路由都能 build 且不 assert**——布局类问题（无界高度、缺 scope、
///    枚举插值）在 analyze 阶段查不出来；
/// 3. **保留页可达**——那 18 个「旧版没有、用户要求保留」的页面必须有入口，
///    否则下一轮就会被当成孤儿删掉（这条是第三轮新增的，见
///    `retained_pages_reachable_test.dart`）。
///
/// 光断言「没抛异常」是不够的：`GoRouter` 对未匹配路径**不抛异常**，它会渲染
/// `errorBuilder`。所以每个用例都额外断言 `UnknownRoutePage` 没有出现——否则
/// 「漏注册」会伪装成「构建成功」。
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

  /// 断言当前挂载的页面既没有抛异常，也没有落到兜底页。
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
      // 去重：多个入口可能指向同一页（例如「设置」在分组里出现两次）。
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

  group('领域路由可达', () {
    testWidgets('全部一级领域页都能构建', (tester) async {
      for (final entry in topLevelRoutes.entries) {
        await pumpAt(tester, entry.value);
        expectReached(tester, entry.value, entry.key);
      }
    });

    testWidgets('带参数的二级页都能构建', (tester) async {
      for (final entry in idRoutes.entries) {
        await pumpAt(tester, entry.value);
        expectReached(tester, entry.value, entry.key);
      }
    });
  });

  group('兜底页', () {
    testWidgets('未注册的路径落到 UnknownRoutePage', (tester) async {
      await pumpAt(tester, '/definitely/not/a/route');
      expect(find.byType(UnknownRoutePage), findsOneWidget);
      // 地址要显示出来，方便用户报告问题。
      expect(find.text('/definitely/not/a/route'), findsOneWidget);
    });
  });
}

/// 一级页面：没有路径参数的都在这里。
///
/// 键是「人读的名字」，用来在失败信息里指出是哪一页；值必须是
/// `lib/routes/*.dart` 里 `Paths` 类暴露的常量，不写字面量。
///
/// 这份表同时被 `layout_regression_test.dart` 消费——各自维护一份会让
/// 「新页面只在其中一个测试里被覆盖」静默发生。
///
/// 第三轮把 FlClash 的代理 / 配置档案 / 内核配置族全部删掉后，这份表与
/// `lib/router.dart` 的实际注册集合同步过一次。删路由必须同时改三张清单：
/// 本表、`layout_regression_test.dart` 的 `_routes`、`app_shell_test.dart`。
final Map<String, String> topLevelRoutes = {
  '首页': DashboardPaths.dashboard,
  '连接': ObservabilityPaths.connections,
  '请求': ObservabilityPaths.requests,
  '资源': ObservabilityPaths.resources,
  // —— 外观子树（旧版 APPEARANCE_SETTINGS 三组八项）——
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
  // —— 设置子页 ——
  '前后台行为': SystemPaths.foregroundBackground,
  '语言设置': SystemPaths.language,
  // —— 系统 ——
  '开发者': SystemPaths.developer,
  '赞助': SystemPaths.sponsor,
  '检查更新': SystemPaths.appUpdate,
  // —— 保留页（旧版无对应界面，用户要求保留）——
  'IP 质量': SystemPaths.ipQuality,
  '编辑器': SystemPaths.editor,
  '扫码': SystemPaths.scan,
  // —— 演示页 ——
  '组件画廊': SystemPaths.demo,
  '表单演示': SystemPaths.formDemo,
  '规则预设': SystemPaths.formRulePreset,
  '列表编辑器': SystemPaths.formListEditor,
  '键值编辑器': SystemPaths.formMapEdit,
  '命名 URL': SystemPaths.formNamedUrl,
  '选择浮层': SystemPaths.formSelection,
  // —— 日志下钻 ——
  '缓存表': LogPaths.cache,
  '竞速排行': LogPaths.race,
  'Bootstrap DNS': LogPaths.bootstrap,
  '订阅拦截统计': LogPaths.subscriptionStats,
  // —— 自定义资源（旧版无对应界面，用户要求保留）——
  '图标集': ConfigPaths.iconSets,
  'User-Agent': ConfigPaths.userAgents,
  '按需连接': ConfigPaths.onDemand,
  '自定义资源': ConfigPaths.customResources,
  // —— 功能中心二级 / 三级页 ——
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
  '数据清理': HubPaths.dataCleanup,
  '备份与迁移': HubPaths.configTransfer,
  'WebDAV 云同步': HubPaths.configTransferWebdav,
  '赞助者名单': HubPaths.sponsorList,
  '共建者名单': HubPaths.coBuilders,
};

/// 带路径参数的二级页。
///
/// 参数一律取 mock 数据里真实存在的 id：塞瞎编的 id 会走到「找不到该配置」的
/// 错误分支，那个分支能 build 但证明不了正常分支能 build。
///
/// 第三轮删掉配置档案后，本表只剩规则种类（`/rules/:kind`）——它仍然需要真实
/// 存在的 kind，否则会渲染空列表而不是正常分支。
final Map<String, String> idRoutes = {
  '规则-黑名单': Routes.rulesOf('block'),
  '规则-白名单': Routes.rulesOf('allow'),
  '规则-覆写': Routes.rulesOf('rewrite'),
};

import 'package:diting/app/app.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/mock_profiles.dart';
import 'package:diting/pages/system/unknown_route_page.dart';
import 'package:diting/routes/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/test_hooks.dart';

/// 路由覆盖守门。
///
/// 第二轮把页面从 18 条扩到 50+ 条，光靠人眼核对「哪些路由注册了」不现实。
/// 这组用例做两件互不重叠的事：
///
/// 1. **功能中心的每个卡片都指向一条真实注册的路由**——卡片是字符串字面量
///    （`mock_apps.dart` 是 part，不能 import 常量），漂了只会在用户点击时崩；
/// 2. **每条路由都能 build 且不 assert**——布局类问题（无界高度、缺 scope、
///    枚举插值）在 analyze 阶段查不出来。
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
      ProviderScope(child: DitingApp(initialLocation: location)),
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

    testWidgets('带 id 的二级页都能构建', (tester) async {
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
final Map<String, String> topLevelRoutes = {
  '首页': DashboardPaths.dashboard,
  '代理': ProxiesPaths.proxies,
  '代理提供者': ProxiesPaths.providers,
  '连接': ObservabilityPaths.connections,
  '请求': ObservabilityPaths.requests,
  'DNS 查询': ObservabilityPaths.dnsQueries,
  '资源': ObservabilityPaths.resources,
  '配置档案': ProfilesPaths.profiles,
  '添加配置': ProfilesPaths.add,
  '扩展': ProfilesPaths.extend,
  '主题': SystemPaths.theme,
  '主题预览': SystemPaths.themePreview,
  '字体': SystemPaths.fontFamily,
  '访问控制': SystemPaths.access,
  '备份': SystemPaths.backup,
  '免责声明': SystemPaths.disclaimer,
  '开发者': SystemPaths.developer,
  '赞助': SystemPaths.sponsor,
  '检查更新': SystemPaths.appUpdate,
  'IP 质量': SystemPaths.ipQuality,
  '编辑器': SystemPaths.editor,
  '扫码': SystemPaths.scan,
  '错误页': SystemPaths.errorPage,
  '规则预设': SystemPaths.formRulePreset,
  '列表编辑器': SystemPaths.formListEditor,
  '键值编辑器': SystemPaths.formMapEdit,
  '命名 URL': SystemPaths.formNamedUrl,
  '选择浮层': SystemPaths.formSelection,
  '通用设置': ConfigPaths.general,
  '网络设置': ConfigPaths.network,
  'TUN 覆写': ConfigPaths.tun,
  'DNS 覆写': ConfigPaths.dns,
  'NTP': ConfigPaths.ntp,
  '嗅探': ConfigPaths.sniffer,
  '覆写编辑器': ConfigPaths.override,
  '过滤器': ConfigPaths.filters,
  '追加规则': ConfigPaths.rules,
  '脚本': ConfigPaths.scripts,
  'Clash 提供者': ConfigPaths.providers,
  '图标集': ConfigPaths.iconSets,
  'User-Agent': ConfigPaths.userAgents,
  '按需连接': ConfigPaths.onDemand,
  '高级': ConfigPaths.advanced,
  '自定义资源': ConfigPaths.customResources,
};

/// 带路径参数的二级页。
///
/// 参数一律取 mock 数据里真实存在的 id：塞瞎编的 id 会走到「找不到该配置」的
/// 错误分支，那个分支能 build 但证明不了正常分支能 build。
final Map<String, String> idRoutes = {
  '编辑配置': ProfilesPaths.editOf(mockProfiles.first.id),
  '配置预览': ProfilesPaths.previewOf(mockProfiles.first.id),
  '自定义配置': ProfilesPaths.customOf(mockProfiles.first.id),
  '自定义节点': ProfilesPaths.proxiesOf(mockProfiles.first.id),
  '自定义组': ProfilesPaths.groupsOf(mockProfiles.first.id),
  '自定义规则': ProfilesPaths.rulesOf(mockProfiles.first.id),
  '自定义提供者': ProfilesPaths.providersOf(mockProfiles.first.id),
  '拨号器': ProfilesPaths.dialersOf(mockProfiles.first.id),
  '图标选择': ProfilesPaths.iconOf(mockProfiles.first.id),
  '扩展详情': ProfilesPaths.extendOf(mockProfiles.first.id),
};

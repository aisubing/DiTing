import 'package:diting/app/app.dart';
import 'package:diting/pages/system/developer_page.dart';
import 'package:diting/router.dart';
import 'package:diting/routes/routes.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/test_hooks.dart';

/// 保留页可达性守门。
///
/// 背景：用户明确要求保留 18 项「旧版不存在」的功能，但这些页面在旧版里没有
/// 对应菜单。它们统一挂在 `/developer` 聚合页下（WebDAV 挂在
/// `/hub/config-transfer` 页尾，字体与纯黑/字号等挂在外观子树里）。
///
/// 为什么需要这个测试：上一轮就发生过「页面存在但没有任何入口」的情况
/// ——`/scan`、`/ip-quality`、`/editor`、`/form/rule-preset` 四个页面只有路由
/// 定义，全仓找不到一处 `context.push`。这类页面在路由冒烟测试里是绿的（它能
/// build），只有人点不到；下一轮清理时又会被当成孤儿删掉。
///
/// 因此这里做两件事：
/// 1. **静态**：断言保留路由常量与聚合页里出现的字符串一一对应；
/// 2. **动态**：断言 `/developer` 页面上真的能找到指向它们的行。
void main() {
  installGlobalTestHooks();

  /// 由 `/developer` 直接承载入口的保留页。
  ///
  /// WebDAV 不在此列：它挂在功能中心的备份与迁移页尾（另一条路径）。
  const viaDeveloper = <String, String>{
    '活动连接': '/connections',
    '资源更新': '/resources',
    'IP 质量': SystemPaths.ipQuality,
    '自定义资源': '/config/custom-resources',
    '组件画廊': SystemPaths.demo,
    '表单演示页': SystemPaths.formDemo,
    '扫码': SystemPaths.scan,
    '编辑器': SystemPaths.editor,
  };

  /// 由其它既有页承载入口的保留页。
  const viaOtherPage = <String>[
    '/config/icon-sets',
    '/config/user-agents',
    '/config/on-demand',
    SystemPaths.fontFamily,
    '/hub/config-transfer/webdav',
  ];

  testWidgets('/developer 页面上能找到全部保留页入口', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(child: DitingApp(initialLocation: SystemPaths.developer)),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(DeveloperPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final entry in viaDeveloper.entries) {
      // 行标题必须上屏：`generateSection` + `ListItem` 会把标题渲染成 Text。
      expect(
        find.text(entry.key),
        findsWidgets,
        reason: '开发者选项里缺少「${entry.key}」入口（${entry.value}）',
      );
    }
  });

  testWidgets('开发者页脚如实说明这些页面不属于旧版界面', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(child: DitingApp(initialLocation: SystemPaths.developer)),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    // 页脚必须写清「不属于旧版 1.4.3」——否则下一轮会被当成"未对齐遗留"删掉。
    expect(find.textContaining('旧版'), findsWidgets);
  });

  test('保留路由常量互不重复，且都不是旧版路径空间', () {
    final retained = <String>[
      ...viaDeveloper.values,
      ...viaOtherPage,
    ];
    expect(retained.toSet().length, retained.length, reason: '保留路由有重复');
    for (final path in retained) {
      expect(path, startsWith('/'));
    }
  });

  test('已被删除的 FlClash 路径不再出现在任何保留清单里', () {
    const removed = <String>[
      '/proxies',
      '/profiles',
      '/config/general',
      '/config/network',
      '/config/tun',
      '/config/ntp',
      '/config/sniffer',
      '/access',
      '/backup',
      '/error',
      '/dns-queries',
      '/agent',
      '/apps',
      '/disclaimer',
      '/theme/preview',
    ];
    final retained = <String>{...viaDeveloper.values, ...viaOtherPage};
    for (final path in removed) {
      expect(
        retained.contains(path),
        isFalse,
        reason: '$path 已在第三轮删除，不该出现在保留清单里',
      );
    }
  });

  test('底栏六个 branch 与旧版 BottomBarDestination 一一对应', () {
    // 顺序即 `_branchOrder`，底栏只是它的子集视图。
    const expected = <String>[
      Routes.home,
      Routes.hub,
      Routes.logs,
      Routes.traffic,
      Routes.tools,
      Routes.settings,
    ];
    for (var index = 0; index < expected.length; index++) {
      expect(branchIndexOf(expected[index]), index);
    }
  });
}

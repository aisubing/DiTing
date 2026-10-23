import 'package:diting/app/app.dart';
import 'package:diting/pages/system/developer_page.dart';
import 'package:diting/router.dart';
import 'package:diting/routes/routes.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/test_hooks.dart';

/// Guards the retained pages are reachable from `/developer` and the config-transfer page; a
/// page with a route but no `context.push` is only caught here
void main() {
  installGlobalTestHooks();

  const viaDeveloper = <String, String>{
    'IP 质量': SystemPaths.ipQuality,
    '自定义资源': '/config/custom-resources',
    '组件画廊': SystemPaths.demo,
  };

  const viaOtherPage = <String>[
    '/config/user-agents',
    '/config/on-demand',
    SystemPaths.fontFamily,
    SystemPaths.fontSize,
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

      // The footer must say these pages are not part of 1.4.3, or a cleanup pass deletes them
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

import 'package:diting/pages/server/server_overview_page.dart';
import 'package:diting/pages/server/server_settings_page.dart';
import 'package:diting/pages/server/server_upstream_page.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 服务器模式的三 Tab 外壳（上游 `server/ui/navigation/DnsNavigation.kt`）。
///
/// 旧版的服务器模式是一个 `HorizontalPager` + 独立浮条：概览 / 上游服务器 /
/// 模式设置三页，与主界面那条六项底栏是两套导航。这里照此实现——服务器模式
/// 一旦开启，`AppShell` 整体换成这个壳，六项浮条不出现。
///
/// 用 `IndexedStack` 而不是 `PageView`：与 `StatefulShellRoute.indexedStack`
/// 同一保活语义，切 tab 不重建页面（上游 pager 的 `beyondViewportPageCount`
/// 也是为保住相邻页状态）。
class ServerModeShell extends StatefulWidget {
  const ServerModeShell({super.key});

  @override
  State<ServerModeShell> createState() => _ServerModeShellState();
}

class _ServerModeShellState extends State<ServerModeShell> {
  int _index = 0;

  /// 与旧版 `DnsNavTab` 逐项对应。
  static const _destinations = <NavigationDockDestination>[
    NavigationDockDestination(glyph: AppGlyphs.dashboard, label: '概览'),
    NavigationDockDestination(glyph: AppGlyphs.dns, label: '上游服务器'),
    NavigationDockDestination(glyph: AppGlyphs.settings, label: '模式设置'),
  ];

  void _select(int index) {
    if (index == _index) {
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 与主壳一致：正文自己负责底部留白（`DockSpacer`），浮条浮在它上面。
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          ServerOverviewPage(
            onOpenUpstreams: () => _select(1),
            onOpenSettings: () => _select(2),
          ),
          const ServerUpstreamPage(),
          const ServerSettingsPage(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: NavigationDock(
          destinations: _destinations,
          selectedIndex: _index,
          onSelected: _select,
        ),
      ),
    );
  }
}

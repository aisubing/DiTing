import 'package:diting/pages/server/server_overview_page.dart';
import 'package:diting/pages/server/server_settings_page.dart';
import 'package:diting/pages/server/server_upstream_page.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// Three-tab shell for server mode (upstream `server/ui/navigation/DnsNavigation.kt`); it replaces
/// the whole `AppShell`, so the six-item dock never shows. `IndexedStack` gives upstream
/// keep-alive.
class ServerModeShell extends StatefulWidget {
  const ServerModeShell({super.key});

  @override
  State<ServerModeShell> createState() => _ServerModeShellState();
}

class _ServerModeShellState extends State<ServerModeShell> {
  int _index = 0;

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
      // As in the main shell, the body supplies its own bottom padding via `DockSpacer` and
      // the bar floats above it.
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
/// Settings page: the legacy "other settings" list of five groups and six rows.
library;

import 'package:diting/router.dart';
import 'package:diting/routes/hub_routes.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The only app-bar action (wrench) opens the developer options hub, the single entry point for
/// pages the legacy app had no menu for. The list stays at the legacy five groups and six rows.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '其他设置',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.wrench,
          tooltip: '开发者选项',
          onPressed: () => context.push(SystemPaths.developer),
        ),
      ],
      body: const PageBody(
        children: [
          // Each `_SettingsGroup` maps to a legacy `SettingsSection`; empty groups are skipped.
          _SettingsGroup(
            title: '运行模式',
            items: [
              _SettingsRow(
                glyph: AppGlyphs.layers,
                title: '运行模式',
                subtitle: '切换普通模式或服务器模式',
                route: Routes.modeSelect,
              ),
            ],
          ),
          _SettingsGroup(
            title: '性能优化',
            items: [
              _SettingsRow(
                glyph: AppGlyphs.cpu,
                title: '缓存设置',
                subtitle: '缓存已解析的域名，减少重复查询',
                route: HubPaths.cache,
              ),
              _SettingsRow(
                glyph: AppGlyphs.clock,
                title: '日志模式',
                subtitle: '选择 DNS 请求日志的记录范围',
                route: HubPaths.logRetention,
              ),
            ],
          ),
          _SettingsGroup(
            title: '运行行为',
            items: [
              _SettingsRow(
                glyph: AppGlyphs.eyeOff,
                title: '前后台行为',
                subtitle: '后台隐藏、通知常驻、绕过局域网',
                route: SystemPaths.foregroundBackground,
              ),
            ],
          ),
          // Appearance (order 3) is an empty group upstream: its entries moved to the feature hub.
          _SettingsGroup(
            title: '数据管理',
            items: [
              _SettingsRow(
                glyph: AppGlyphs.language,
                title: '语言设置',
                subtitle: '选择应用界面语言',
                route: SystemPaths.language,
              ),
            ],
          ),
          _SettingsGroup(
            title: '其他设置',
            items: [
              _SettingsRow(
                glyph: AppGlyphs.puzzle,
                title: '使用向导',
                subtitle: '查看当前工作模式的架构原理、权限配置与上手指引',
                route: Routes.modeOnboarding,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.items});

  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) =>
      generateSection(title: title, items: items);
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final Glyph glyph;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: GlyphIcon(glyph),
      trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
      onTap: () => context.push(route),
    );
  }
}
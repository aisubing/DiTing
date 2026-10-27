/// Settings page: the legacy "other settings" list of five groups and six rows.
library;

import 'package:diting/router.dart';
import 'package:diting/routes/hub_routes.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/nav_entry_row.dart';
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
      body: PageBody(
        children: [
          // Each `_SettingsGroup` maps to a legacy `SettingsSection`; empty groups are skipped.
          _SettingsGroup(
            title: '运行模式',
            items: [
              NavEntryRow(
                glyph: AppGlyphs.layers,
                title: '运行模式',
                subtitle: '切换普通模式或服务器模式',
                onPressed: () => context.push(Routes.modeSelect),
              ),
            ],
          ),
          _SettingsGroup(
            title: '性能优化',
            items: [
              NavEntryRow(
                glyph: AppGlyphs.cpu,
                title: '缓存设置',
                subtitle: '缓存已解析的域名，减少重复查询',
                onPressed: () => context.push(HubPaths.cache),
              ),
              NavEntryRow(
                glyph: AppGlyphs.clock,
                title: '日志模式',
                subtitle: '选择 DNS 请求日志的记录范围',
                onPressed: () => context.push(HubPaths.logRetention),
              ),
            ],
          ),
          _SettingsGroup(
            title: '运行行为',
            items: [
              NavEntryRow(
                glyph: AppGlyphs.eyeOff,
                title: '前后台行为',
                subtitle: '后台隐藏、通知常驻、绕过局域网',
                onPressed: () => context.push(SystemPaths.foregroundBackground),
              ),
            ],
          ),
          // Appearance (order 3) is an empty group upstream: its entries moved to the feature hub.
          _SettingsGroup(
            title: '数据管理',
            items: [
              NavEntryRow(
                glyph: AppGlyphs.language,
                title: '语言设置',
                subtitle: '选择应用界面语言',
                onPressed: () => context.push(SystemPaths.language),
              ),
            ],
          ),
          _SettingsGroup(
            title: '其他设置',
            items: [
              NavEntryRow(
                glyph: AppGlyphs.puzzle,
                title: '使用向导',
                subtitle: '查看当前工作模式的架构原理、权限配置与上手指引',
                onPressed: () => context.push(Routes.modeOnboarding),
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
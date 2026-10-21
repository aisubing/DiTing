/// 设置页：旧版「其他设置」五组六行。
///
/// 权威依据是 1.4.3 的渲染逻辑，而不是枚举声明：
/// `SettingsScreen.kt` 遍历 `SettingsSection.entries.sortedBy { order }`，
/// 每组取 `ScreenDestinations.mainEntries.filter { mainSection == section }`，
/// **空组直接跳过**。`mainEntries` 又只来自 `ScreenDestinations.all`（六个条目），
/// 那些声明了却不在 `all` 里的（出站代理 / 解析模式 / 数据清理 / AI 分析 /
/// 四个 resolution 子页）根本不会被渲染。
///
/// 因此上屏的正好是五组六行，顺序固定：
///
/// | 组（按 order） | 行 | 路由 |
/// |---|---|---|
/// | 运行模式 (0) | 运行模式 | `/mode/select` |
/// | 性能优化 (1) | 缓存设置 / 日志模式 | `/hub/cache` / `/hub/log-retention` |
/// | 运行行为 (2) | 前后台行为 | `/settings/background` |
/// | 外观 (3) | —— | 空组，不渲染 |
/// | 数据管理 (4) | 语言设置 | `/settings/language` |
/// | 其他设置 (5) | 使用向导 | `/mode/onboarding` |
///
/// 页面标题是 `R.string.other_settings` =「其他设置」（底栏 tab 仍叫「设置」）；
/// `OTHER` 这一组的组标题同样改写成「其他设置」，与页面标题重复——这是旧版
/// 真实行为，照抄。
///
/// 上一轮这一页是「外观 / 功能入口 / 观测与配置 / 系统 / 首页 / 底栏 / 解析 / 关于」
/// 八组，绝大多数行指向 FlClash 的代理与内核配置。旧版没有这些概念，已随页面
/// 一起删除。
///
/// 这一页同时是设计系统的「密度验收面」：每一行都由 `ListItem` + `generateSection`
/// 组合，没有手写行样式，否则设计系统一改行高或圆角，这里就会最早露馅。
library;

import 'package:diting/router.dart';
import 'package:diting/routes/hub_routes.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 设置页。
///
/// 顶栏只有一个图标按钮：扳手 → 开发者选项聚合页。这是本轮唯一在设置页上新增
/// 的可点元素，原因是那 18 个「用户要求保留、但旧版没有对应菜单」的页面需要
/// 唯一入口，而设置列表本身必须严格保持旧版的五组六行、一个不多一个不少。
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
          // 每个 `_SettingsGroup` 对应旧版一个 `SettingsSection`，空组不出现。
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
          // 外观（order 3）在旧版是空组：条目都被移到功能中心的「界面与设置」分类，
          // 这里刻意不补任何行。
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

/// 一组设置：组标题 + 若干行。
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.items});

  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) =>
      generateSection(title: title, items: items);
}

/// 一行设置入口：图标 + 标题 + 副标题 + 右箭头。
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

/// Developer options hub, which has no 1.4.3 counterpart.
library;

import 'package:diting/data/mock_system.dart';
import 'package:diting/routes/config_routes.dart';
import 'package:diting/routes/hub_routes.dart';
import 'package:diting/routes/observability_routes.dart';
import 'package:diting/routes/system_routes.dart';
import 'package:diting/state/system_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class DeveloperPage extends ConsumerWidget {
  const DeveloperPage({super.key});

  Future<void> _run(BuildContext context, MockDeveloperAction action) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (action.destructive) {
      final confirmed = await showFloatingDialog<bool>(
        context: context,
        child: CommonDialog(
          title: action.title,
          destructive: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('执行'),
            ),
          ],
          child: Text('${action.subtitle}\n\n该动作会改写演示状态，执行后需要手动恢复。'),
        ),
      );
      if (confirmed != true) {
        return;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    messenger?.showSnackBar(
      SnackBar(
        content: Text('${action.title}：已完成（演示）'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(developerModeProvider);
    return CommonScaffold(
      title: '开发者选项',
      // Avoids `PageBody` (a lazy ListView): this is a directory, and never-built entries stay
      // invisible to the a11y tree and screenshot review. Building them all is cheap.
      body: AppBarClearance(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DeveloperModeCard(),
              generateSection(
                title: '诊断与观测',
                items: [
                  _Entry(
                    glyph: AppGlyphs.connections,
                    title: '活动连接',
                    subtitle: '按应用与目标地址查看当前连接与流量',
                    route: ObservabilityPaths.connections,
                  ),
                  _Entry(
                    glyph: AppGlyphs.resources,
                    title: '资源更新',
                    subtitle: '规则订阅、图标集等资源的下载与更新时间',
                    route: ObservabilityPaths.resources,
                  ),
                  _Entry(
                    glyph: AppGlyphs.target,
                    title: 'IP 质量',
                    subtitle: '实测出口地址与三个公开情报源的类型判断',
                    route: SystemPaths.ipQuality,
                  ),
                ],
              ),
              generateSection(
                title: '配置与资源',
                items: [
                  _Entry(
                    glyph: AppGlyphs.resources,
                    title: '自定义资源',
                    subtitle: '图标集 / User-Agent / 按需连接三张表的入口页',
                    route: ConfigPaths.customResources,
                  ),
                  _Entry(
                    glyph: AppGlyphs.photos,
                    title: '图标集',
                    subtitle: '分组卡片用的「图标名 → 图片」映射',
                    route: ConfigPaths.iconSets,
                  ),
                  _Entry(
                    glyph: AppGlyphs.account,
                    title: 'User-Agent',
                    subtitle: '订阅下载与测速请求携带的 UA',
                    route: ConfigPaths.userAgents,
                  ),
                  _Entry(
                    glyph: AppGlyphs.wifi,
                    title: '按需连接',
                    subtitle: '按 SSID 决定是否启动 VPN',
                    route: ConfigPaths.onDemand,
                  ),
                  _Entry(
                    glyph: AppGlyphs.cloudSync,
                    title: 'WebDAV 云同步',
                    subtitle: '把备份真实上传到自建的 WebDAV 服务',
                    // The WebDAV form is now a sub page of "backup and migration", so this
                    // row points straight at it instead of adding a directory hop.
                    route: HubPaths.configTransferWebdav,
                  ),
                ],
              ),
              generateSection(
                title: '界面与外观保留项',
                items: [
                  _Entry(
                    glyph: AppGlyphs.font,
                    title: '字体',
                    subtitle: '选择界面字体族，独立页',
                    route: SystemPaths.fontFamily,
                  ),
                  _Entry(
                    glyph: AppGlyphs.pureBlack,
                    title: '纯黑',
                    subtitle: '深色表面折叠为纯黑；在外观设置「界面显示」组内联开关',
                    route: SystemPaths.theme,
                  ),
                  _Entry(
                    glyph: AppGlyphs.textSize,
                    title: '字号',
                    subtitle: '全局文字缩放；在外观设置「界面显示」组内联滑杆',
                    route: SystemPaths.theme,
                  ),
                  _Entry(
                    glyph: AppGlyphs.liquidGlass,
                    title: '液态玻璃',
                    subtitle: '浮条与卡片的玻璃质感；在外观设置「背景与动效」组内联选项',
                    route: SystemPaths.theme,
                  ),
                  _Entry(
                    glyph: AppGlyphs.motion,
                    title: 'Tab 动画',
                    subtitle: '切换底部标签时的入场动画；在外观设置「背景与动效」组内联选项',
                    route: SystemPaths.theme,
                  ),
                  _Entry(
                    glyph: AppGlyphs.dashboard,
                    title: '底栏样式',
                    subtitle: '浮条 / 普通底栏二选一；在外观设置「背景与动效」组内联选项',
                    route: SystemPaths.theme,
                  ),
                ],
              ),
              generateSection(
                title: '设计与演示',
                items: [
                  _Entry(
                    glyph: AppGlyphs.palette,
                    title: '组件画廊',
                    subtitle: '设计系统全部组件与字形目录',
                    route: SystemPaths.demo,
                  ),
                  _Entry(
                    glyph: AppGlyphs.compose,
                    title: '表单演示页',
                    subtitle: '表单族组件的输入、校验与提交范式',
                    route: SystemPaths.formDemo,
                  ),
                  _Entry(
                    glyph: AppGlyphs.qrCode,
                    title: '扫码',
                    subtitle: '相机取景与二维码识别（演示页，不调用真实相机）',
                    route: SystemPaths.scan,
                  ),
                  _Entry(
                    glyph: AppGlyphs.code,
                    title: '编辑器',
                    subtitle: 'YAML 高亮编辑器的交互与性能演示',
                    route: SystemPaths.editor,
                  ),
                ],
              ),
              generateSection(
                title: '实验动作',
                items: [
                  for (final action in mockDeveloperActions)
                    _ActionRow(
                      action: action,
                      enabled: enabled,
                      onTap: enabled ? () => _run(context, action) : null,
                    ),
                ],
                footer:
                    '「崩溃核心」只会弹一个致命错误对话框，不会真的让进程退出；'
                    '「清空全部数据」在演示层只重置本页状态。',
              ),
              const ListFooter(
                text:
                    '以上「诊断与观测」「配置与资源」「界面与外观保留项」「设计与演示」'
                    '里的页面都不属于旧版 1.4.3 的界面，保留供调试与组件验收；'
                    '旧版对应的功能仍按旧版菜单进入，不经过本页。',
              ),
              const DockSpacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// When off the actions are disabled, not hidden, so the user sees where to enable them.
class _DeveloperModeCard extends ConsumerWidget {
  const _DeveloperModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(developerModeProvider);
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Row(
              spacing: 10,
              children: [
                GlyphIcon(
                  AppGlyphs.wrench,
                  size: 22,
                  color: enabled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('开发者模式', style: context.listTitleStyle),
                      Text(
                        enabled ? '实验动作已解锁' : '关闭时下面的动作不可用',
                        style: context.listCaptionStyle,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: (value) =>
                      ref.read(developerModeProvider.notifier).toggle(value),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: ShapeDecoration(
                shape: AppShape.md,
                color: colorScheme.warningContainer,
              ),
              child: Row(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlyphIcon(
                    AppGlyphs.warning,
                    size: 16,
                    color: colorScheme.onWarningContainer,
                  ),
                  Expanded(
                    child: Text(
                      '这些动作会直接改写内存状态，可能让界面进入不一致的样子；'
                      '它们只用于验证 UI 的异常分支，不要在生产环境打开。',
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(color: colorScheme.onWarningContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
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
      leading: GlyphIcon(glyph, size: 20),
      trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
      onTap: () => context.push(route),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.action,
    required this.enabled,
    required this.onTap,
  });

  final MockDeveloperAction action;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final glyphColor = !enabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        : action.destructive
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;
    return ListItem(
      title: Text(
        action.title,
        style: action.destructive && enabled
            ? TextStyle(color: colorScheme.error)
            : null,
      ),
      subtitle: Text(action.subtitle),
      leading: GlyphIcon(glyphByName(action.glyphName), color: glyphColor),
      trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
      onTap: onTap,
    );
  }
}
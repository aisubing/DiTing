/// 开发者选项聚合页。
///
/// **这一页在 1.4.3 里不存在**：它是本轮的「保留项入口」。用户明确要求保留
/// 图标集 / UA / 按需连接 / 活动连接 / 资源更新 / WebDAV / 开发者 / 扫码 /
/// IP 质量 / 编辑器 / 字体 / 纯黑 / 字号 / 液态玻璃 / Tab 动画 / 底栏样式 /
/// 组件画廊 / 表单演示页 这些页面，但它们大多没有旧版对应菜单。直接塞回设置页
/// 会破坏「旧版五组六行」的验收基线，因此统一收进本页，入口是设置页顶栏的
/// 一个扳手图标（旧版也没有这一颗按钮，是本轮唯一新增的可点元素）。
///
/// 组织原则：
/// - 每一行都指向一个真实存在、可构建的路由；**没有入口的页面不算保留**，所以
///   图标集 / User-Agent / 按需连接在一页里各占一行，而不是只在副标题里提一句；
/// - 「纯黑 / 字号 / 底栏样式 / tab 动画 / Liquid 玻璃」在旧版与新版的落点都是
///   外观设置页里的**内联控件**，不是独立页；这里照实写成「在外观设置内」，
///   而不是伪造五个并不存在的子页；
/// - 实验动作保留原有总开关与二次确认语义；
/// - 页脚如实写明这些页面不属于旧版界面，避免把「保留」误读成「旧版就有」。
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

/// 开发者选项聚合页。
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
      // 这一页刻意**不用** `PageBody`（懒构建的 ListView）：它是一张目录页，
      // 三十来行轻量条目，滚动可视区外的入口如果没被构建，「保留项在哪」就
      // 只能靠用户自己翻——无障碍树、搜索和无 instrument 的截图审核都会漏。
      // 一次性建完的代价可以忽略，换来的是整页入口同时存在。
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
                    subtitle: '出口地址的归属地、运营商与风险评分（演示数据）',
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
                    subtitle: '把备份上传到自建的 WebDAV 服务（演示层不发真实请求）',
                    // 旧版的 WebDAV 只是备份页里的一张表单；本轮它成了「备份与迁移」
                    // 页尾的子页，这里直接指向那张表单——落在一层目录上再让用户自己
                    // 找第二层，等于把入口做丢。
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

/// 开发者模式总开关卡：关闭时整块实验动作禁用（不是隐藏）。
///
/// 隐藏会让人以为功能没了；置灰能让用户看见「它被关闭了」，并且知道去哪打开。
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

/// 一条「跳到保留页」的入口行：图标 + 标题 + 一句说明 + 箭头。
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

/// 一条实验动作：未解锁时整行禁用并降透明度。
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

part of 'settings_page.dart';

/// 关于分组：版本入口 + 几个跳转项。
///
/// 设置页只放「入口」，内容全在 `/about`：版本号、许可、第三方来源在设置列表
/// 里展开会淹没真正要改的设置项，而这些东西一年也未必看一次。
class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingDone = ref.watch(onboardingProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        generateSection(
          title: '其他',
          items: [
            ListItem(
              title: const Text('关于谛听'),
              subtitle: const Text('版本 $appVersionLabel · 开源许可 · 第三方组件'),
              leading: const GlyphIcon(AppGlyphs.info),
              trailing: const GlyphIcon(AppGlyphs.chevronForward),
              onTap: () => context.push(Routes.about),
            ),
            ListItem(
              title: const Text('服务器模式'),
              subtitle: const Text('局域网 DNS 服务：端口、上游与统计'),
              leading: const GlyphIcon(AppGlyphs.vpn),
              trailing: const GlyphIcon(AppGlyphs.chevronForward),
              onTap: () => context.push(Routes.server),
            ),
            ListItem(
              title: const Text('AI 助手'),
              subtitle: const Text('用自然语言解释域名与规则'),
              leading: const GlyphIcon(AppGlyphs.sparkle),
              trailing: const GlyphIcon(AppGlyphs.chevronForward),
              onTap: () => context.push(Routes.agent),
            ),
            ListItem(
              title: const Text('重新选择工作模式'),
              subtitle: Text(onboardingDone ? '引导已完成，可随时重看' : '三步引导尚未完成'),
              leading: const GlyphIcon(AppGlyphs.layers),
              trailing: const GlyphIcon(AppGlyphs.chevronForward),
              onTap: () => context.push(Routes.modeOnboarding),
            ),
            ListItem(
              title: const Text('组件画廊'),
              subtitle: const Text('lib/ui 公开 API 全量陈列，供视觉回归对照'),
              leading: const GlyphIcon(AppGlyphs.palette),
              trailing: const GlyphIcon(AppGlyphs.chevronForward),
              onTap: () => context.push(Routes.demo),
            ),
          ],
        ),
        const ListFooter(
          text: '本阶段是纯 UI 演示：没有网络、没有数据库、没有 VPN 服务，'
              '所有页面与交互都由本地 mock 状态驱动。',
        ),
      ],
    );
  }
}

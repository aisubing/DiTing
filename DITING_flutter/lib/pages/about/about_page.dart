import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 关于页：图标 + 名称 + 版本 + 三段说明 + 三条信息行。
///
/// 上游「关于」是设置树里的三项（版本/许可/第三方），演示层合成一页：这些
/// 内容只在想确认「这是什么、能不能商用」时才会打开，放在一页里能一次读完，
/// 分散成三个入口反而要来回跳。
///
/// 页首用大图标而不是 Logo 位图：本阶段没有品牌资源，硬塞占位图会显得像
/// 加载失败；用设计系统自己的 Glyph 至少是「有意为之」的观感。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  /// 与 `pubspec.yaml` 的 `version: 1.0.0+1` 手工对齐；发版时两处同改。
  static const _version = '1.0.0';
  static const _repoUrl = 'https://github.com/haoze/diting';

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '关于',
      body: PageBody(
        children: [
          _Hero(version: _version),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: const [
                _Paragraph(
                  title: '这是什么',
                  body: '谛听（DITING）是一款本地 DNS 工具：在本机完成域名解析、'
                      '规则过滤与流量观测，不依赖任何云端账号。它有三种工作模式——'
                      '普通模式接管全部流量，服务器模式把设备变成局域网 DNS 服务器，'
                      '极速模式只做窄路由加速。',
                ),
                _Paragraph(
                  title: '视觉体系来源',
                  body: '界面组件层（lib/ui）整层移植自 DITING 1.4.3：'
                      '形状、表面色阶、排版、图标、动效时序都沿用同一套设计系统，'
                      '以保证迁移前后观感一致。页面内容与状态管理是谛听自己的。',
                ),
                _Paragraph(
                  title: '许可',
                  body: '本项目以 GPL-3.0 发布——因为 lib/ui 来自 GPL-3.0 的 DITING，'
                      '衍生作品必须沿用同一许可。第三方字体与着色器的来源见 NOTICE.md。',
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          generateSection(
            title: '信息',
            items: [
              ListItem(
                title: const Text('开源许可'),
                subtitle: const Text('GPL-3.0-or-later'),
                leading: const GlyphIcon(AppGlyphs.gavel),
                trailing: const GlyphIcon(AppGlyphs.openExternal),
                onTap: () => _toast(context, 'GPL-3.0 全文见仓库根目录 LICENSE'),
              ),
              ListItem(
                title: const Text('第三方组件'),
                subtitle: const Text('DITING 设计系统 · JetBrains Mono · Twemoji'),
                leading: const GlyphIcon(AppGlyphs.puzzle),
                trailing: const GlyphIcon(AppGlyphs.openExternal),
                onTap: () => _toast(context, '来源清单见仓库根目录 NOTICE.md'),
              ),
              ListItem(
                title: const Text('项目主页'),
                subtitle: const Text(_repoUrl),
                leading: const GlyphIcon(AppGlyphs.link),
                trailing: const GlyphIcon(AppGlyphs.openExternal),
                onTap: () => _toast(context, '演示阶段不打开浏览器：$_repoUrl'),
              ),
            ],
          ),
          ListFooter(
            text: '版本 $_version · 纯 UI 演示：没有网络、没有数据库、没有 VPN 服务，'
                '所有页面与交互都由本地 mock 状态驱动。',
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '© 2026 谛听 DITING',
              style: AppTextStyle.caption2.of(context).copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 页首：大图标 + 名称 + 版本徽章。
class _Hero extends StatelessWidget {
  const _Hero({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: AppShape.xxl,
              color: colorScheme.primary,
              shadows: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.30),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: GlyphIcon(
              AppGlyphs.wifi,
              size: 48,
              fill: 1,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '谛听',
            style: AppTextStyle.largeTitle.of(context, emphasized: true),
          ),
          const SizedBox(height: 2),
          Text(
            'DITING · 本地 DNS 工具',
            style: AppTextStyle.footnote.of(context).copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          MetaChip(label: '版本 $version'),
        ],
      ),
    );
  }
}

/// 一段说明：小标题 + 正文。
class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 5,
        children: [
          Text(
            title,
            style: AppTextStyle.headline.of(context, emphasized: true),
          ),
          Text(
            body,
            style: AppTextStyle.footnote.of(context).copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1800),
    ),
  );
}

/// About page (legacy `ui/AboutScreen.kt`); express mode drops two capabilities.
library;

import 'package:diting/pages/system/app_info.dart';
import 'package:diting/pages/system/disclaimer_page.dart';
import 'package:diting/state/app_version_provider.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class _AboutEntry {
  const _AboutEntry(this.title, this.description, this.glyph);

  final String title;
  final String description;
  final Glyph glyph;
}

const _capabilities = <_AboutEntry>[
  _AboutEntry('加密上游', '支持 DNS、DoH 与 DoT，并可管理自定义服务商。', AppGlyphs.lock),
  _AboutEntry('规则与缓存', '以缓存、屏蔽规则、白名单和订阅规则减少重复请求与干扰。', AppGlyphs.rules),
  _AboutEntry(
    '可观测性',
    '通过请求日志、竞速统计、服务商健康和 Bootstrap 数据追踪状态。',
    AppGlyphs.requests,
  ),
  _AboutEntry(
    '独立引导',
    '支持 Bootstrap IP，降低解析加密上游域名时对系统 DNS 的依赖。',
    AppGlyphs.target,
  ),
  _AboutEntry('配置流转', '支持自定义服务、规则订阅的导入导出与自动更新。', AppGlyphs.cloudSync),
  _AboutEntry('快捷控制', '提供系统快捷设置磁贴，方便快速启停 DNS 本地通道。', AppGlyphs.toggle),
  _AboutEntry('应用管控', '按应用排除 VPN 或阻止联网，灵活控制每个应用的网络访问。', AppGlyphs.block),
  _AboutEntry(
    'HTTPS 流量检查',
    '按应用检查 HTTP(S) 请求并应用域名和 URL 规则，需安装 HTTPS 检查根证书。',
    AppGlyphs.lockOpen,
  ),
];

const _boundaries = <_AboutEntry>[
  _AboutEntry(
    '默认仅处理 DNS',
    '默认通过 Android VpnService 建立仅处理 DNS 的本地通道；启用 HTTPS 流量检查或'
        '禁止联网后，Go 隧道使用 Go 用户态网络栈接管 TCP、UDP、DNS 和 HTTP(S) 流量。',
    AppGlyphs.vpn,
  ),
  _AboutEntry('实际解析表现', '解析速度、稳定性和可用性取决于网络环境、所选上游和本机规则。', AppGlyphs.speed),
  _AboutEntry(
    '隐私与本地存储',
    '缓存、日志、规则与配置保存在设备本机。上游仍会收到必要查询；'
        '仅 DoH、DoT 加密到上游的 DNS 传输。',
    AppGlyphs.lock,
  ),
];

const _expressRouteBoundary = _AboutEntry(
  '极速原生 DNS 窄路由',
  '通过纯 Kotlin 原生轻量窄路由接管 UDP/TCP 53 端口 DNS 请求；设备常规应用数据'
      '直连物理网络，不经过 VPN 协议栈，实现零性能损耗与极低功耗。',
  AppGlyphs.bolt,
);

const _normalOnlyCapabilities = {'应用管控', 'HTTPS 流量检查'};

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(workModeProvider);
    final express = mode == AppWorkMode.express;
    // Legacy `rememberDnsServiceRunning`: server mode reads the server status, everything
    // else reads the VPN power state.
    final running = mode == AppWorkMode.server
        ? ref.watch(serverStatusProvider) == ServerStatus.running
        : ref.watch(powerProvider) == PowerState.running;
    final capabilities = express
        ? [
            for (final entry in _capabilities)
              if (!_normalOnlyCapabilities.contains(entry.title)) entry,
          ]
        : _capabilities;
    final boundaries = express
        ? [_expressRouteBoundary, ..._boundaries.skip(1)]
        : _boundaries;
    return CommonScaffold(
      title: '应用信息',
      body: PageBody(
        children: [
          _Hero(
            version: ref.watch(appVersionProvider).name,
            running: running,
          ),
          const SizedBox(height: 4),
          generateSection(
            title: '核心能力',
            items: [for (final entry in capabilities) _EntryRow(entry: entry)],
            footer: express ? '极速模式只做窄路由加速，因此不包含应用管控与 HTTPS 流量检查。' : null,
          ),
          generateSection(
            title: '运行边界',
            items: [for (final entry in boundaries) _EntryRow(entry: entry)],
          ),
          const SizedBox(height: 4),
          const _ProjectCard(),
          const SizedBox(height: 14),
          generateSection(
            title: '免责条款与合规声明',
            items: [
              ListItem.next(
                leading: const GlyphIcon(AppGlyphs.gavel),
                title: const Text('使用须知与免责声明'),
                subtitle: const Text('软件说明、运行机制与免责条款全文'),
                // Consent is enforced by the app-level dialog on first run; this is a
                // read-only re-read.
                widget: const DisclaimerPage(),
              ),
            ],
            footer: '首次启动时必须同意本声明才能继续使用；此处可随时回看。',
          ),
          const SizedBox(height: 10),
          const _Signature(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.version, required this.running});

  final String version;

  final bool running;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Row(
              spacing: 12,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    shape: AppShape.md,
                    color: colorScheme.primaryContainer,
                  ),
                  child: GlyphIcon(
                    AppGlyphs.dns,
                    size: 28,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        '// LOCAL DNS CONTROL PLANE',
                        style: AppTextStyle.caption2
                            .of(context)
                            .copyWith(
                              color: colorScheme.primary,
                              fontFamily: 'JetBrainsMono',
                            ),
                      ),
                      Text(
                        '谛听 本地解析控制台',
                        style: AppTextStyle.title2.of(
                          context,
                          emphasized: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              '在 Android 设备本机管理 DNS 查询路径，让解析策略、缓存、规则与上游连接'
              '处于可控状态。',
              style: context.listSubtitleStyle,
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                MetaChip(label: '版本 $version'),
                const MetaChip(label: 'Android VpnService'),
                const MetaChip(label: '本地优先'),
                _StatusDot(running: running),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Running dot: primary colour while running, error colour otherwise (legacy `titleTrailing`).
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    final color = running
        ? context.colorScheme.primary
        : context.colorScheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: ShapeDecoration(shape: AppShape.circle, color: color),
        ),
        Text(
          running ? '运行中' : '未运行',
          style: AppTextStyle.caption2.of(context).copyWith(color: color),
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final _AboutEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: GlyphIcon(entry.glyph, color: context.colorScheme.primary),
      title: Text(entry.title),
      subtitle: Text(entry.description),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CommonCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  'MAINTAINED BY',
                  style: AppTextStyle.caption2
                      .of(context)
                      .copyWith(
                        color: colorScheme.primary,
                        fontFamily: 'JetBrainsMono',
                      ),
                ),
                Text(
                  'haoze-evolluling',
                  style: AppTextStyle.title3.of(context, emphasized: true),
                ),
                Text('一位集美大学人工智能系大三学子', style: context.listSubtitleStyle),
              ],
            ),
            GestureDetector(
              onTap: () => _copyRepository(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: ShapeDecoration(
                  shape: AppShape.md,
                  color: colorScheme.primary.withValues(alpha: 0.10),
                ),
                child: Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(
                            '开源项目仓库',
                            style: AppTextStyle.subheadline.of(
                              context,
                              emphasized: true,
                            ),
                          ),
                          Text(
                            projectRepositoryUrl.replaceFirst('https://', ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.listCaptionStyle,
                          ),
                        ],
                      ),
                    ),
                    GlyphIcon(
                      AppGlyphs.openExternal,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyRepository(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: projectRepositoryUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('仓库地址已复制：$projectRepositoryUrl'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 2000),
      ),
    );
  }
}

class _Signature extends StatelessWidget {
  const _Signature();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '谛听 / RESOLUTION UNDER YOUR CONTROL',
        textAlign: TextAlign.center,
        style: AppTextStyle.caption2
            .of(context)
            .copyWith(
              color: context.colorScheme.onSurfaceVariant,
              fontFamily: 'JetBrainsMono',
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
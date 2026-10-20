// ignore_for_file: sort_child_properties_last
import 'package:diting/state/hub_settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// CA 证书设置（上游 `CaCertificateSettingsScreen`）。
class CaCertificatePage extends ConsumerWidget {
  const CaCertificatePage({super.key});

  static const _fingerprint =
      '3A:8F:21:9C:4D:7E:12:B5:66:0A:D3:48:9F:15:2C:71:'
      'E4:88:5B:AA:30:6D:92:1F:74:C5:08:BE:63:D7:4A:90';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(httpInspectionProvider);
    final notifier = ref.read(httpInspectionProvider.notifier);
    return CommonScaffold(
      title: 'CA 证书设置',
      body: PageBody(
        children: [
          generateSection(
            title: '证书状态',
            items: [
              ListItem(
                leading: GlyphIcon(
                  state.caReady ? AppGlyphs.verified : AppGlyphs.warning,
                  size: 20,
                ),
                title: const Text('根证书状态'),
                subtitle: const Text('用于目标应用的 HTTPS 流量解密'),
                trailing: Text(
                  state.caReady ? '已验证' : '未验证',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
            footer: '仅已验证的根证书支持流量检查；启用了证书绑定（SSL Pinning）的应用将自动旁路。',
          ),
          generateSection(
            title: '证书操作',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.info),
                title: const Text('安装与卸载指南'),
                subtitle: const Text('查看各机型系统证书的安装、移除及安全说明'),
                onTap: () => context.push('/hub/https-inspection/ca/guide'),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.upload),
                title: const Text('安装根证书'),
                subtitle: const Text('导出证书文件并前往系统设置安装'),
                trailing: Text(
                  state.caReady ? '已安装' : '未安装',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
                onTap: () => _install(context, ref),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.key),
                title: const Text('证书指纹'),
                subtitle: const Text('查看当前根证书的 SHA-256 指纹'),
                onTap: () => _showFingerprint(context),
              ),
            ],
          ),
          generateSection(
            title: '证书管理',
            items: [
              ListItem(
                leading: GlyphIcon(
                  AppGlyphs.reset,
                  color: context.colorScheme.error,
                ),
                title: Text(
                  '重新生成根证书',
                  style: TextStyle(color: context.colorScheme.error),
                ),
                subtitle: const Text('作废当前私钥并生成新证书，重置后需重新安装'),
                onTap: () => _reset(context, notifier),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _install(BuildContext context, WidgetRef ref) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '安装根证书',
        child: const Text(
          '请在系统设置中选择「从存储设备安装 CA 证书」，并选择导出的 '
          'DITING-CA.crt 文件。\n\n返回后谛听将自动验证安装状态。启用证书绑定'
          '（SSL Pinning）或自定义校验的应用将自动旁路转发。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('已完成安装'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(httpInspectionProvider.notifier).setCaReady(true);
    }
  }

  void _showFingerprint(BuildContext context) {
    showFloatingDialog<void>(
      context: context,
      child: CommonDialog(
        title: 'CA 证书指纹',
        child: const SelectableText('SHA-256 指纹：\n$_fingerprint'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _reset(
    BuildContext context,
    HttpInspectionNotifier notifier,
  ) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '重新生成根证书？',
        destructive: true,
        child: const Text(
          '当前私钥会立即作废，已经安装到系统的旧证书将不再生效。'
          '重新生成后需要再次导出并安装。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('重新生成'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      notifier.setCaReady(false);
    }
  }
}

/// CA 证书安装与卸载指南（上游 `CaCertificateGuideScreen`）。
class CaCertificateGuidePage extends StatelessWidget {
  const CaCertificateGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: 'CA 证书安装与卸载指南',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: const [
          _GuideHeading('一、如何安装 CA 证书'),
          _GuideBody(
            'Android 系统中，安装和卸载 CA 证书的步骤因系统版本和手机厂商'
            '（如华为、小米、OPPO、VIVO 等）的定制界面而略有不同，但核心逻辑一致。',
          ),
          _GuideHeading('前提条件'),
          _GuideBody(
            '在开始之前，请确保你已经将证书文件（通常是 .crt、.cer 或 .der 格式）'
            '下载到了手机的本地存储（如「下载」/ Download 文件夹）中。',
          ),
          _GuideHeading('详细步骤'),
          _GuideBody(
            '1. 打开手机的「设置」。\n'
            '2. 找到并点击「安全」或「隐私与安全」（部分机型在「更多设置」→「系统安全」中）。\n'
            '3. 往下滚动，找到「更多安全设置」或「凭据存储」。\n'
            '4. 点击「从存储设备安装证书」（或「安装证书」）。\n'
            '5. 在弹出的选项中选择「CA 证书」。\n'
            '6. 验证手机锁屏密码（指纹、面容或图案）。\n'
            '7. 系统会打开文件管理器，找到并点击事先下载好的证书文件。\n'
            '8. 为证书命名（可自定义），用途保持默认的「VPN 和应用」，点击确定。',
          ),
          _GuideWarning(
            '系统通常会弹出「您的隐私可能受到监视」的警告。请确认证书来源安全，'
            '再点击「仍然安装」。',
          ),
          _GuideHeading('二、如何卸载/删除 CA 证书'),
          _GuideBody(
            '1. 打开「设置」。\n'
            '2. 前往「安全」→「更多安全设置」→「凭据存储」。\n'
            '3. 点击「信任的凭据」（或「查看安全凭据」）。\n'
            '4. 切换到「用户」标签页。\n'
            '5. 找到要删除的证书并点击它。\n'
            '6. 滚动到页面底部，点击「删除」或「移除」。\n'
            '7. 确认删除后，证书会从系统中彻底清除。',
          ),
          _GuideWarning(
            'CA 证书拥有极高的权限，可以截获和解析手机上发出的加密网络流量（HTTPS）。'
            '请务必不要安装任何来自未知来源、陌生网页或不可信应用提示安装的 CA 证书。',
          ),
        ],
      ),
    );
  }
}

class _GuideHeading extends StatelessWidget {
  const _GuideHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(text, style: AppTextStyle.title3.of(context, emphasized: true)),
    );
  }
}

class _GuideBody extends StatelessWidget {
  const _GuideBody(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: AppTextStyle.body.of(context).copyWith(height: 1.6)),
    );
  }
}

class _GuideWarning extends StatelessWidget {
  const _GuideWarning(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CommonCard(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: AppTextStyle.footnote
              .of(context)
              .copyWith(color: context.colorScheme.error, height: 1.5),
        ),
      ),
    );
  }
}

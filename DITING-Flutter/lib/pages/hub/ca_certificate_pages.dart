// ignore_for_file: sort_child_properties_last
import 'package:diting/data/native/ca_bridge.dart';
import 'package:diting/state/ca_inspection_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// CA certificate settings (upstream `CaCertificateSettingsScreen`). State comes from
/// `CaCertificateService.inspect()`: `available`, `installed` and `fingerprintSha256`,
/// never hard-coded.
class CaCertificatePage extends ConsumerWidget {
  const CaCertificatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(caCertificateStateProvider);
    final state = asyncState.value;
    // The first inspect loads the Go engine and may take hundreds of milliseconds, so a
    // "checking" row shows meanwhile rather than a fake "not installed".
    if (state == null) {
      return CommonScaffold(
        title: 'CA 证书设置',
        body: const Center(child: CommonCircleLoading.page()),
      );
    }
    final statusTitle = switch ((state.available, state.installed)) {
      (false, _) => '尚未生成：引擎还没有产出 ca.crt',
      (true, false) => '已生成，但未装进系统信任存储',
      (true, true) => '已生成且已被系统信任',
    };
    final fingerprint = state.fingerprintSha256;
    final pem = state.pem;
    return CommonScaffold(
      title: 'CA 证书设置',
      body: PageBody(
        children: [
          generateSection(
            title: '证书状态',
            items: [
              ListItem(
                leading: GlyphIcon(
                  state.ready ? AppGlyphs.verified : AppGlyphs.warning,
                  size: 20,
                ),
                title: const Text('根证书状态'),
                subtitle: Text(statusTitle),
                trailing: Text(
                  state.ready ? '已验证' : '未验证',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
              ),
              if (state.error case final error?)
                ListItem(
                  leading: GlyphIcon(
                    AppGlyphs.warning,
                    size: 20,
                    color: context.colorScheme.error,
                  ),
                  title: const Text('读取失败'),
                  subtitle: Text(error),
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
                subtitle: const Text('交给系统安装器；Android 11 起还需在设置里手动确认'),
                trailing: Text(
                  state.installed ? '已安装' : '未安装',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
                onTap: () => _install(context, ref, state),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.export),
                title: const Text('保存证书到下载目录'),
                subtitle: const Text('下载目录里的 .crt 可在系统设置里手动安装'),
                onTap: () => _saveToDownloads(context, ref),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.key),
                title: const Text('证书指纹'),
                subtitle: Text(
                  fingerprint == null ? '尚未生成证书时没有指纹' : 'SHA-256（点击查看完整指纹）',
                ),
                onTap: fingerprint == null
                    ? null
                    : () => _showFingerprint(context, fingerprint),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.copy),
                title: const Text('查看证书内容'),
                subtitle: const Text('以可复制的 PEM 文本显示，便于拷到别处安装'),
                onTap: pem == null ? null : () => _showPem(context, pem),
              ),
            ],
          ),
          generateSection(
            title: '证书管理',
            items: [
              ListItem(
                leading: GlyphIcon(
                  AppGlyphs.refresh,
                  color: context.colorScheme.error,
                ),
                title: Text(
                  '重新生成根证书',
                  style: TextStyle(color: context.colorScheme.error),
                ),
                subtitle: const Text('作废当前私钥并生成新证书，重置后需重新安装'),
                onTap: () => _regenerate(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Hands the staged PEM to the system certificate installer through the bridge. Android has no
  /// silent install, and since Android 11 the installer only points back at the settings screen, so
  /// the .crt is also dropped into Download first: that file is what the manual path needs.
  Future<void> _install(
    BuildContext context,
    WidgetRef ref,
    CaCertificateState state,
  ) async {
    if (!state.available || state.pem == null) {
      _toast(context, '还没有可用证书，请先点「重新生成根证书」');
      return;
    }
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '安装根证书',
        child: const Text(
          'Android 只允许用户手动把根证书装进「CA 证书」一栏，应用无法静默写入'
          '系统信任存储。\n\n点「继续」会先保存一份证书文件到下载目录，再尝试打开'
          '系统安装器；若安装器只提示去设置，请用该文件在「设置 → 安全 → 加密与凭据 '
          '→ 安装证书 → CA 证书」里手动选中它。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final notifier = ref.read(caCertificateStateProvider.notifier);
    final saved = await notifier.saveToDownloads();
    if (!context.mounted) {
      return;
    }
    final result = await notifier.install();
    if (!context.mounted) {
      return;
    }
    final hint = saved.saved
        ? '证书已存到 ${saved.name ?? '下载目录'}。'
        : '证书文件保存失败（${saved.error ?? '未知原因'}）。';
    _toast(context, '${switch (result.target) {
      CaInstallTarget.installer => '已打开系统证书安装界面。',
      CaInstallTarget.settings => '系统没有证书安装器，已打开安全设置。',
      CaInstallTarget.none => result.error ?? '无法打开证书安装界面。',
    }}$hint若界面只提示前往设置，请在「加密与凭据 → 安装证书 → CA 证书」里手动选中它。');
    await notifier.refresh();
  }

  /// Fallback for ROMs without a certificate installer: writes the PEM where the user can pick it.
  Future<void> _saveToDownloads(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(caCertificateStateProvider.notifier)
        .saveToDownloads();
    if (!context.mounted) {
      return;
    }
    _toast(
      context,
      result.saved
          ? '已保存到 ${result.name ?? '下载目录'}，可在「加密与凭据 → 安装证书」里选中它'
          : result.error ?? '无法写入下载目录',
    );
  }

  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '重新生成根证书？',
        destructive: true,
        child: const Text(
          '会删除现有的 ca.crt / ca.key 与黑名单缓存。已安装的旧证书随即失效，'
          '之前被信任的所有连接都需要重新安装新证书，HTTPS 检查也会被自动关闭。',
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
    if (confirmed != true || !context.mounted) {
      return;
    }
    final next = await ref
        .read(caCertificateStateProvider.notifier)
        .regenerate();
    if (!context.mounted) {
      return;
    }
    _toast(
      context,
      next.error != null ? '生成失败：${next.error}' : '已生成新证书，请前往系统设置安装',
    );
  }

  Future<void> _showFingerprint(BuildContext context, String fingerprint) {
    return showFloatingDialog<void>(
      context: context,
      child: CommonDialog(
        title: '证书指纹（SHA-256）',
        child: SelectableText(
          fingerprint,
          style: AppTextStyle.footnote
              .of(context)
              .copyWith(fontFamily: 'JetBrainsMono', height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fingerprint));
              if (context.mounted) {
                Navigator.of(context).pop();
                _toast(context, '指纹已复制');
              }
            },
            child: const Text('复制'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPem(BuildContext context, String pem) {
    return showFloatingDialog<void>(
      context: context,
      child: CommonDialog(
        title: '根证书 PEM',
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: SelectableText(
              pem,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(fontFamily: 'JetBrainsMono', height: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: pem));
              if (context.mounted) {
                Navigator.of(context).pop();
                _toast(context, '证书内容已复制');
              }
            },
            child: const Text('复制'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class CaCertificateGuidePage extends StatelessWidget {
  const CaCertificateGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: 'CA 证书指南',
      body: PageBody(
        children: [
          generateSection(
            title: '为什么需要安装',
            items: const [
              _GuideItem(
                'HTTPS 流量检查需要在设备上建立一条本地解密通道。'
                '系统只信任「用户」证书区里手工安装的根证书，应用无法代替你点这一步。',
              ),
            ],
          ),
          generateSection(
            title: '安装步骤',
            items: const [
              _GuideItem('1. 在「CA 证书设置」里点「安装根证书」，应用会把证书文件存进下载目录，再交给系统安装器。'),
              _GuideItem(
                '2. Android 11 起系统安装器通常只提示前往设置，这是平台限制，不是应用故障。'
                '请从「设置 → 安全 → 加密与凭据 → 安装证书 → CA 证书」里选中下载目录里的那个 .crt 文件。',
              ),
              _GuideItem('3. 安装时系统会要求屏幕锁或指纹；设备没有锁屏时无法安装，需先设一个 PIN。'),
              _GuideItem('4. 回到本页，状态应变成「已验证」；没变就退出重进该页重新检查。'),
            ],
          ),
          generateSection(
            title: '哪些应用能被检查',
            items: const [
              _GuideItem(
                '系统只信任「用户」证书区的根证书，而 targetSdk 24（Android 7.0）及以上的应用'
                '默认不信任用户证书。只有自带网络安全配置允许用户 CA 的应用，'
                '其 HTTPS 才能被解密并看到明文。',
              ),
              _GuideWarning(
                '其余应用的 HTTPS 请求会被记录为「失败 / client_tls」，这是应用的证书绑定'
                '或系统策略导致的，属于预期行为；这类应用应加入绕过规则。',
              ),
            ],
          ),
          generateSection(
            title: '卸载与风险',
            items: const [
              _GuideWarning(
                '根证书一旦装进用户信任区，任何持有对应私钥的软件都能解密本机流量。'
                '不再使用时请到系统设置里删除它，并在本页「重新生成根证书」作废旧私钥。',
              ),
              _GuideItem(
                '部分应用使用证书绑定（SSL Pinning），装证书后仍会连接失败；'
                '这类应用应加入绕过规则，而不是反复重装证书。',
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _GuideItem extends StatelessWidget {
  const _GuideItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTextStyle.body.of(context).copyWith(height: 1.6),
      ),
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
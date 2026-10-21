// ignore_for_file: sort_child_properties_last
import 'package:diting/data/native/ca_bridge.dart';
import 'package:diting/state/ca_inspection_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// CA 证书设置（上游 `CaCertificateSettingsScreen`）。
///
/// 状态全部来自 `CaCertificateService.inspect()`：`available`（引擎产出过证书）、
/// `installed`（SHA-256 命中 Android **user** 信任存储）、`fingerprintSha256`
/// （冒号分隔大写）。这里没有任何硬编码指纹——旧实现写死一串十六进制，页面因此
/// 分不清「还没生成」与「生成了但没装」。
class CaCertificatePage extends ConsumerWidget {
  const CaCertificatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(caCertificateStateProvider);
    final state = asyncState.value;
    // 首次 inspect 要加载 Go 引擎（`libgojni.so` + 现造证书），可能几百毫秒，
    // 期间显示一行「正在检查」而不是伪装成「未安装」。
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
                subtitle: const Text('导出证书文件并前往系统设置安装'),
                trailing: Text(
                  state.installed ? '已安装' : '未安装',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
                onTap: () => _install(context, ref, state),
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

  /// 「安装根证书」= 先把 PEM 交到用户手里，再打开系统的「安装证书」界面。
  ///
  /// 取舍：`CaCertificateService.exportTo(uri)` 需要一个 `content://` URI，而 URI
  /// 只能由系统「保存文件」选择器给出。本仓库没有文件选择器依赖
  /// （`pubspec.yaml` 只有 material_ui / riverpod / go_router / sqflite），按任务
  /// 约束不新增 pub 依赖，所以这里**不调用 exportTo**，改为把 PEM 显示成可复制
  /// 文本（`_showPem`），由用户存成 .crt 或直接在文件管理器里打开。
  /// 若后续引入选择器，只需在这里拿到 URI 后调 `exportTo(uri)`，其余不变。
  Future<void> _install(
    BuildContext context,
    WidgetRef ref,
    CaCertificateState state,
  ) async {
    final pem = state.pem;
    if (!state.available || pem == null) {
      _toast(context, '还没有可用证书，请先点「重新生成根证书」');
      return;
    }
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '安装根证书',
        child: const Text(
          'Android 只允许用户手动把根证书装进「CA 证书」一栏，应用无法静默写入'
          '系统信任存储。\n\n下一步会显示证书的 PEM 文本（可复制），随后尝试打开'
          '系统的证书安装界面。',
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
    await _showPem(context, pem);
    if (!context.mounted) {
      return;
    }
    final opened = await ref
        .read(caCertificateStateProvider.notifier)
        .openInstallSettings();
    if (!context.mounted) {
      return;
    }
    _toast(
      context,
      opened
          ? '已在系统设置中打开安装界面；回到本页会重新检查状态'
          : '无法打开系统证书安装界面，请手动前往「设置 → 安全 → 加密与凭据」',
    );
    // 用户可能正是在系统里装完证书回来的，这里主动再查一次。
    await ref.read(caCertificateStateProvider.notifier).refresh();
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

/// 安装指南（上游 `CaCertificateGuideScreen`）。内容与 1.4.3 同源，保持纯文案。
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
              _GuideItem('1. 在「CA 证书设置」里点「安装根证书」，或先「查看证书内容」把 PEM 复制出去。'),
              _GuideItem(
                '2. 系统会跳到证书安装界面；若没有跳转，'
                '前往「设置 → 安全 → 加密与凭据 → 安装证书 → CA 证书」。',
              ),
              _GuideItem('3. 选择刚才导出的 .crt 文件，确认时系统会要求屏幕锁或指纹。'),
              _GuideItem('4. 回到本页，状态应变成「已验证」。没变就下拉重新检查。'),
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

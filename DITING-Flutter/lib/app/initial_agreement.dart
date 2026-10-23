/// First-launch terms and disclaimer.
///
/// Upstream 1.4.3 showed `InitialAgreementDialog` once from `MainActivity` and
/// stored `initial_agreement_accepted`. [InitialAgreementGate] is mounted in
/// `DitingApp.builder` so it also covers overlay routes. The wording is copied
/// verbatim from `ui/MainActivityDialogs.kt`: it is the legal text users
/// actually agreed to.
library;

import 'dart:ui' show ImageFilter;

import 'package:diting/state/settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Gates the app behind the first-launch agreement.
///
/// Returns [child] untouched once accepted, so the gate adds no extra layout
/// level afterwards.
class InitialAgreementGate extends ConsumerStatefulWidget {
  const InitialAgreementGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InitialAgreementGate> createState() =>
      _InitialAgreementGateState();
}

class _InitialAgreementGateState extends ConsumerState<InitialAgreementGate> {
  /// Set when the user declines; scoped to this run, asked again next launch.
  var _declined = false;

  @override
  Widget build(BuildContext context) {
    final accepted = ref.watch(initialAgreementProvider);
    if (accepted) {
      return widget.child;
    }
    return Stack(
      children: [
        // Blur the content behind: upstream's dialog was modal.
        ExcludeSemantics(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: widget.child,
          ),
        ),
        Positioned.fill(
          child: ColoredBox(
            color: context.colorScheme.scrim.withValues(alpha: 0.5),
          ),
        ),
        if (_declined)
          Positioned.fill(
            child: _DeclinedNotice(
              onReopen: () => setState(() => _declined = false),
            ),
          )
        else
          Positioned.fill(
            child: InitialAgreementDialog(
              onAccept: () =>
                  ref.read(initialAgreementProvider.notifier).accept(),
              onDecline: () => setState(() => _declined = true),
            ),
          ),
      ],
    );
  }
}

/// Screen shown after declining.
///
/// Does not kill the process: `SystemNavigator.pop()` is treated as a crash by
/// some vendor ROMs. The user exits on their own, and "review again" is offered
/// so a mis-tap is not final.
class _DeclinedNotice extends StatelessWidget {
  const _DeclinedNotice({required this.onReopen});

  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: CommonCard(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text('已拒绝使用须知', style: context.listTitleStyle),
              Text(
                '未同意使用须知与免责声明，无法继续使用谛听。'
                '你可以直接退出应用，或重新查看条款后再决定。',
                style: context.listSubtitleStyle,
              ),
              FilledButton.tonal(
                onPressed: onReopen,
                child: const Text('重新查看'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The terms dialog itself.
///
/// Wording comes verbatim from the upstream agreement text.
class InitialAgreementDialog extends StatelessWidget {
  const InitialAgreementDialog({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// Upstream `InitialAgreementDialog.message`, with its line breaks.
  static const message =
      '软件说明\n'
      '谛听是一款专注于本地 DNS 解析优化与网络规则过滤的开源工具。提供三种工作模式：'
      '普通模式（全隧道深度管控）、极速模式（纯 Kotlin 原生轻量窄路由）与独立服务器模式'
      '（局域网免 VPN 服务）。本软件完全在设备本地闭环运行，无任何远程数据上传与隐私追踪。'
      '\n\n'
      '运行机制与注意事项\n'
      '普通模式与极速模式依赖 Android 本地 VPN 接口接管 DNS 解析，不连接任何远程 VPN 服务器；'
      '独立服务器模式无需 VPN 权限，直接监听本地 1053 端口供局域网设备接入。规则与日志完整'
      '保存在本机，启用高级扩展功能前请了解其具体影响。'
      '\n\n'
      '免责条款\n'
      '本软件按现状提供。使用者须遵守相关法律法规，自行确认规则与上游解析来源的合法性及'
      '安全性。严禁将本软件用于任何违法用途；使用者因自行配置或使用本软件所产生的后果由'
      '使用者自行承担。';

  @override
  Widget build(BuildContext context) {
    // Three paragraphs of legal text are the longest body copy in the app.
    // A long document needs opposite treatment to a short question such as
    // "delete this?": request full width with a 20 inset and 20 body padding,
    // which widens the body by ~44% on a 411dp screen.
    return CommonDialog(
      title: '使用须知与免责声明',
      width: double.infinity,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      actions: [
        TextButton(onPressed: onDecline, child: const Text('不同意并退出')),
        TextButton(onPressed: onAccept, child: const Text('同意并继续')),
      ],
      // Must scroll: three paragraphs do not fit on a small screen with large
      // text. Line height 1.6 instead of the default 1.33 keeps dense CJK body
      // text legible.
      child: ConstrainedBox(

        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.5,
        ),
        child: SingleChildScrollView(
          child: Text(
            message,
            style: context.listSubtitleStyle.copyWith(height: 1.6),
          ),
        ),
      ),
    );
  }
}

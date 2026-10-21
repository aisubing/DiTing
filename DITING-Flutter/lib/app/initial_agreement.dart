/// 首次启动的「使用须知与免责声明」。
///
/// 1.4.3 在 `MainActivity` 里用 `InitialAgreementDialog` 弹一次，确认后写
/// `initial_agreement_accepted`（`dns_vpn_prefs`）。上一轮 Flutter 版把它做成
/// 一个独立路由页 `/disclaimer`：既没有「首次启动」这个时机（用户得自己找到
/// 那一行才会看到），也没有写那个键，于是免责声明的展示成了纯装饰。
///
/// 本轮改回弹窗：`DitingApp` 在 `builder` 里包一层 [InitialAgreementGate]，
/// 未确认就盖一层遮罩 + 对话框。文案逐字照抄 `ui/MainActivityDialogs.kt` 的
/// `InitialAgreementDialog`——它是用户实际同意过的法律文本，不能改写。
library;

import 'dart:ui' show ImageFilter;

import 'package:diting/state/settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 首次启动的须知门。
///
/// 已同意时直接返回 [child]，零额外布局层级——门在同意后必须完全消失，否则
/// 每个页面都会多一层 `Stack`，命中测试与滚动行为都会跟着变。
class InitialAgreementGate extends ConsumerStatefulWidget {
  const InitialAgreementGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InitialAgreementGate> createState() =>
      _InitialAgreementGateState();
}

class _InitialAgreementGateState extends ConsumerState<InitialAgreementGate> {
  /// 用户点了「不同意」。只在本次运行内有效，下次启动重新询问。
  var _declined = false;

  @override
  Widget build(BuildContext context) {
    final accepted = ref.watch(initialAgreementProvider);
    if (accepted) {
      return widget.child;
    }
    return Stack(
      children: [
        // 弹窗背后的内容整体模糊掉：旧版是模态对话框，背后内容不可交互。
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

/// 「不同意」后的收尾屏。
///
/// 不杀进程：Flutter 侧直接 `SystemNavigator.pop()` 在部分厂商 ROM 上会被判为
/// 异常退出并弹「应用屡次停止运行」。旧版是 Activity 里 `finish()`，这里改为
/// 收起弹窗 + 明确提示，用户自行退出，并留一个「重新查看」——误触不算终局。
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

/// 「使用须知与免责声明」对话框本体。
///
/// 文案逐字来自旧版 `InitialAgreementDialog`：这是用户实际同意过的法律文本。
class InitialAgreementDialog extends StatelessWidget {
  const InitialAgreementDialog({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// 旧版 `InitialAgreementDialog` 的 `message`，含换行结构。
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
    // 三段法律文本是本应用里最长的一段连续正文。此前它被夹在
    // `CommonDialog` 的默认内容上限（348 − 30×2 = 288dp）里，再加上外层
    // `Padding(horizontal: 24)`，真机 411dp 宽的屏上正文只剩约 230dp 宽 ——
    // 一行不到 12 个汉字，滚动条要拖四次才读得完。
    //
    // 长文档与短问句的排版要求是相反的：iOS 的告警宽度（270–348）是为一句
    // 「是否删除」调的，而这段文本需要的是「铺满能铺的宽度」。所以这里显式
    // 请求满宽、把 inset 收到 20，并把正文内缩从 30 降到 20：411 − 20×2 − 20×2
    // = 331dp 的正文宽度，比原来宽 44%。
    return CommonDialog(
      title: '使用须知与免责声明',
      width: double.infinity,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      actions: [
        TextButton(onPressed: onDecline, child: const Text('不同意并退出')),
        TextButton(onPressed: onAccept, child: const Text('同意并继续')),
      ],
      // 正文较长（三段），必须可滚：小屏 + 大字号下整段放不下，写死高度会
      // 把按钮挤出屏幕。行高 1.6 而不是默认的 1.33：连续汉字正文靠行距分辨
      // 行，默认行距在三段法律文本上读起来是糊成一片的（与免责声明页正文
      // `InitialAgreementCard` 的 1.6 一致）。
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

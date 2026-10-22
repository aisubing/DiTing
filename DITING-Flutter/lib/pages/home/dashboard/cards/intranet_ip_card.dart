import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 内网 IP 卡（FlClash `widgets/intranet_ip.dart`）。
///
/// 上游是「内网地址大字 + 复制按钮 + 局域网代理开关」。本仓的对应关系：
/// - **地址**读 `networkInfoProvider`（原生 `DiagnosticsBridge.networkInfo` 的
///   `localIpv4`），与服务器模式「局域网接入」块同一个来源；
/// - **开关换成状态行**：DITING 没有「局域网代理」这个开关——服务器模式的
///   `Engine.startStandalone` 绑定所有网卡，普通/极速模式根本不监听局域网。
///   因此这里显示的是**当前是否真的在监听**以及端口，而不是一个拨不动的开关。
///   给一个永远为关的开关比不给更糟：用户会以为点了就能用。
class IntranetIpCard extends ConsumerWidget {
  const IntranetIpCard({super.key, this.onDetail});

  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final network = ref.watch(networkInfoProvider);
    final snapshot = network.asData?.value;
    final loading = network.isLoading;
    final mode = ref.watch(workModeProvider);
    final serverStatus = ref.watch(serverStatusProvider);
    final port = ref.watch(serverPortProvider);
    final scale = DashboardDensityScope.scaleOf(context);
    final colorScheme = context.colorScheme;
    final localIp = snapshot?.localIpv4 ?? '';
    // 服务器模式下地址后面带上端口才有意义：同一网段的设备要把它填成 DNS。
    final listening =
        mode == AppWorkMode.server && serverStatus == ServerStatus.running;
    final address = localIp.isEmpty
        ? null
        : listening
        ? '$localIp:$port'
        : localIp;
    return DashboardCard(
      semanticLabel: '内网 IP',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.devices,
            title: '内网 IP',
            trailing: [
              DashboardIconButton(
                glyph: AppGlyphs.copy,
                tooltip: '复制地址',
                onPressed: address == null
                    ? null
                    : () => _copy(context, address),
              ),
              // 「详情」的箭头保持在最右，与其他卡片同位置。
              if (onDetail != null)
                DashboardIconButton(
                  glyph: AppGlyphs.chevronForward,
                  tooltip: '详情',
                  onPressed: onDetail,
                ),
            ],
          ),
          SizedBox(height: 12 * scale),
          Text(
            address ?? (loading ? '读取中…' : '无活动网络'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.figure(
              context,
              AppTextStyle.title1,
              color: address == null
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface,
            ).copyWith(letterSpacing: 0),
          ),
          SizedBox(height: 12 * scale),
          DashboardBlock(
            padding: EdgeInsets.symmetric(
              horizontal: 12 * scale,
              vertical: 9 * scale,
            ),
            child: Row(
              spacing: 10,
              children: [
                GlyphIcon(
                  localIp.isEmpty ? AppGlyphs.wifiOff : AppGlyphs.wifi,
                  size: 18,
                  color: listening
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 1,
                    children: [
                      Text(
                        '局域网接入',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DashboardText.rowTitle(context),
                      ),
                      Text(
                        _lanHint(mode, listening, port, localIp.isEmpty),
                        maxLines: 2,
                        style: DashboardText.label(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (snapshot case final info? when info.interfaceName.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8 * scale),
              child: Text(
                '${info.interfaceName}'
                '${(info.gateway ?? '').isEmpty ? '' : ' · 网关 ${info.gateway}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DashboardText.label(context),
              ),
            ),
        ],
      ),
    );
  }

  /// 局域网是否可用：只有服务器模式会绑所有网卡，其余模式连本机都只走 127.0.0.1。
  static String _lanHint(
    AppWorkMode mode,
    bool listening,
    int port,
    bool noNetwork,
  ) {
    if (noNetwork) return '连上 Wi-Fi 或以太网后这里会显示可用地址';
    if (mode != AppWorkMode.server) {
      return '${mode.title}不监听局域网，其他设备无法把这里当 DNS';
    }
    return listening
        ? '已监听 0.0.0.0:$port，其他设备把 DNS 指到上面的地址'
        : '服务未启动：启动后才会绑定 $port 端口';
  }

  static Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('已复制 $text'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }
}

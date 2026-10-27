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
    // The port only matters in server mode: peers must enter it as their DNS.
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

  /// LAN is reachable only in server mode; other modes bind 127.0.0.1 only.
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

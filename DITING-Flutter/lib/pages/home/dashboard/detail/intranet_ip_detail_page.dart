import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/pages/home/dashboard/detail/dashboard_detail_parts.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Intranet IP detail: the card fits one address and a one-line hint. This page lists the whole
/// network snapshot — interface, IPv4/IPv6, gateway, DNS servers, VPN and private-DNS state — plus
/// the exact DNS address other devices should point at, so the user never has to guess the port.
class IntranetIpDetailPage extends ConsumerWidget {
  const IntranetIpDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final network = ref.watch(networkInfoProvider);
    final info = network.asData?.value;
    final mode = ref.watch(workModeProvider);
    final serverStatus = ref.watch(serverStatusProvider);
    final port = ref.watch(serverPortProvider);
    final colorScheme = context.colorScheme;
    final localIp = info?.localIpv4 ?? '';
    final listening =
        mode == AppWorkMode.server && serverStatus == ServerStatus.running;
    final dnsAddress = localIp.isEmpty
        ? null
        : listening
        ? '$localIp:$port'
        : localIp;
    final dnsServers = info?.dnsServers ?? const <String>[];
    return DashboardDetailScaffold(
      title: '内网 IP 详情',
      actions: [
        IconButton(
          tooltip: '刷新网络信息',
          onPressed: () => ref.invalidate(networkInfoProvider),
          icon: const GlyphIcon(AppGlyphs.refresh),
        ),
      ],
      children: [
        DashboardDetailHero(
          glyph: AppGlyphs.wifi,
          label: '本机局域网地址',
          value: dnsAddress ?? (network.isLoading ? '读取中…' : '无活动网络'),
          monospace: dnsAddress != null,
          chipLabel: listening ? '可作 DNS' : '仅本机',
          chipColor: listening
              ? colorScheme.success
              : colorScheme.onSurfaceVariant,
          hint: listening
              ? '同网段设备把 DNS 指到这个地址即可走本机解析。'
              : localIp.isEmpty
              ? '连上 Wi-Fi 或以太网后这里会显示可用地址。'
              : '${mode.title}不监听局域网，其它设备无法把这里当 DNS。',
        ),
        if (dnsAddress != null)
          _CopyCard(address: dnsAddress, withPort: listening),
        DashboardDetailCard(
          glyph: AppGlyphs.connections,
          title: '网络概况',
          child: DashboardStatGrid(
            stats: [
              StatItem(label: 'IPv4', value: localIp.isEmpty ? '—' : localIp),
              StatItem(
                label: 'VPN',
                value: info?.vpnActive == true ? '已启用' : '未启用',
                color: info?.vpnActive == true ? colorScheme.primary : null,
              ),
              StatItem(label: 'DNS 服务器', value: '${dnsServers.length}'),
              StatItem(
                label: '监听端口',
                value: listening ? '$port' : '未监听',
                color: listening ? colorScheme.primary : null,
              ),
            ],
          ),
        ),
        DashboardDetailCard(
          glyph: AppGlyphs.wifi,
          title: '接口',
          footer: info == null || info.interfaceName.isEmpty
              ? '系统没有报告活动网络接口，可能是飞行模式或未联网。'
              : null,
          child: DashboardDetailRows(
            rows: [
              DashboardDetailRow(
                label: '网卡',
                value: networkInterfaceLabel(info ?? _emptyInfo),
                monospace: true,
              ),
              DashboardDetailRow(
                label: 'IPv4',
                value: localIp.isEmpty ? '—' : localIp,
                monospace: true,
              ),
              DashboardDetailRow(
                label: 'IPv6',
                value: info?.localIpv6?.isNotEmpty == true
                    ? info!.localIpv6!
                    : '—',
                monospace: true,
              ),
              DashboardDetailRow(
                label: '网关',
                value: info?.gateway?.isNotEmpty == true ? info!.gateway! : '—',
                monospace: true,
              ),
            ],
          ),
        ),
        DashboardDetailCard(
          glyph: AppGlyphs.dns,
          title: 'DNS',
          footer: info != null && info.privateDns != 'off'
              ? '系统开启了私人 DNS（${info.privateDns}），'
                    '系统解析会走加密通道，可能绕过本地服务。'
              : '系统私人 DNS 未开启，解析请求由本机与代理按模式处理。',
          child: dnsServers.isEmpty
              ? Row(
                  spacing: 10,
                  children: [
                    GlyphIcon(
                      AppGlyphs.info,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    Expanded(
                      child: Text(
                        '没有读到 DNS 服务器：接口未下发 DNS，或当前环境没有诊断通道。',
                        style: AppTextStyle.subheadline.of(
                          context,
                        ).copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                )
              : DashboardDetailRows(
                  rows: [
                    // Numbered: a column of rows all labelled "DNS" left no way to tell
                    // which server was the primary one.
                    for (final (index, server) in dnsServers.indexed)
                      DashboardDetailRow(
                        label: index == 0 ? '首选' : '备用 $index',
                        value: server,
                        monospace: true,
                      ),
                    DashboardDetailRow(
                      label: '私人 DNS',
                      value: info?.privateDns ?? '—',
                    ),
                  ],
                ),
        ),
        const DashboardDetailNote(
          text: '端口只在服务启动时绑定，改动端口后需要重启服务；'
              '把同网段设备的 DNS 指向上面的地址即可让它们走本机解析。',
        ),
      ],
    );
  }

  static const _emptyInfo = NetworkInfoSnapshot(
    interfaceName: '',
    localIpv4: '',
    privateDns: 'off',
    vpnActive: false,
  );
}

/// Tap-to-copy row for the address other devices should use. Kept as its own card so the action
/// reads as a button rather than as one more plain list row.
class _CopyCard extends StatelessWidget {
  const _CopyCard({required this.address, required this.withPort});

  final String address;
  final bool withPort;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final colors = DashboardColors.of(context);
    return DashboardDetailCard(
      semanticLabel: '复制地址 $address',
      onTap: () => _copy(context, address),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: ShapeDecoration(
              color: colors.tone,
              shape: AppShape.all(AppCorner.sm),
            ),
            child: Center(
              child: GlyphIcon(
                AppGlyphs.copy,
                size: 18,
                color: colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Text(
                  withPort ? '复制地址（含端口）' : '复制地址',
                  style: AppTextStyle.subheadline.of(context, emphasized: true),
                ),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.caption1.of(context).copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: appMonospaceFontFamily,
                  ),
                ),
              ],
            ),
          ),
          GlyphIcon(
            AppGlyphs.chevronForward,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
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

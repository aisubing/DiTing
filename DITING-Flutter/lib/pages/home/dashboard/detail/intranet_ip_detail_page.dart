import 'package:diting/data/native/diagnostics_bridge.dart';
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
        DashboardDetailFigure(
          label: '本机局域网地址',
          value: dnsAddress ?? (network.isLoading ? '读取中…' : '无活动网络'),
          hint: listening
              ? '其他设备把 DNS 指到这个地址即可'
              : localIp.isEmpty
              ? '连上 Wi-Fi 或以太网后这里会显示可用地址'
              : '${mode.title}不监听局域网，其它设备无法把这里当 DNS',
        ),
        if (dnsAddress != null)
          generateSection(
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.copy, size: 20),
                title: const Text('复制地址'),
                subtitle: Text(
                  listening ? '$dnsAddress（含端口）' : dnsAddress,
                  style: AppTextStyle.subheadline.of(
                    context,
                  ).copyWith(fontFamily: 'JetBrainsMono'),
                ),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: () => _copy(context, dnsAddress),
              ),
            ],
          ),
        const ListHeader(title: '网络概况'),
        DashboardDetailStats(
          stats: [
            StatItem(
              label: 'IPv4',
              value: localIp.isEmpty ? '—' : localIp,
            ),
            StatItem(
              label: 'VPN',
              value: info?.vpnActive == true ? '已启用' : '未启用',
              color: info?.vpnActive == true ? colorScheme.primary : null,
            ),
            StatItem(label: 'DNS 服务器', value: '${dnsServers.length}'),
            StatItem(
              label: '监听端口',
              value: listening ? '$port' : '—',
              color: listening ? colorScheme.primary : null,
            ),
          ],
        ),
        generateSection(
          title: '接口',
          footer: info == null || info.interfaceName.isEmpty
              ? '系统没有报告活动网络接口，可能是飞行模式或未联网。'
              : null,
          items: [
            KeyValueRow(
              label: '网卡',
              value: networkInterfaceLabel(info ?? _emptyInfo),
              monospace: true,
            ),
            KeyValueRow(
              label: 'IPv4',
              value: localIp.isEmpty ? '—' : localIp,
              monospace: true,
            ),
            KeyValueRow(
              label: 'IPv6',
              value: info?.localIpv6?.isNotEmpty == true
                  ? info!.localIpv6!
                  : '—',
              monospace: true,
            ),
            KeyValueRow(
              label: '网关',
              value: info?.gateway?.isNotEmpty == true ? info!.gateway! : '—',
              monospace: true,
            ),
          ],
        ),
        generateSection(
          title: 'DNS',
          footer: info != null && info.privateDns != 'off'
              ? '系统开启了私人 DNS（${info.privateDns}），'
                    '系统解析会走加密通道，可能绕过本地服务。'
              : '系统私人 DNS 未开启，解析请求由本机与代理按模式处理。',
          items: [
            if (dnsServers.isEmpty)
              const ListItem(
                leading: GlyphIcon(AppGlyphs.dns, size: 20),
                title: Text('没有读到 DNS 服务器'),
                subtitle: Text('接口未下发 DNS，或当前环境没有诊断通道。'),
              )
            else
              for (final server in dnsServers)
                KeyValueRow(label: 'DNS', value: server, monospace: true),
            KeyValueRow(label: '私人 DNS', value: info?.privateDns ?? '—'),
          ],
        ),
        const ListFooter(
          text:
              '端口只在服务启动时绑定，改动端口后需要重启服务；'
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

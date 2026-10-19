/// 网络设置（上游 `views/config/network.dart`，611 行）。
///
/// 上游按平台拼三套完全不同的列表（Android 的 VPN 段、桌面端的系统代理段、
/// 以及共用的 TUN 与选项段）。演示层固定为移动端视角：保留 VPN 段、TUN 段与
/// 出站选项段；系统代理与代理回环是 Windows / macOS 专属能力，不提供。
library;

import 'package:diting/data/mock_config.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/state/config_providers.dart';
import 'package:diting/ui/support/input_limits.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'network_tun_section.dart';
part 'network_options_section.dart';
part 'network_string_list_sheet.dart';

/// 网络设置页。
class NetworkConfigPage extends ConsumerWidget {
  const NetworkConfigPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final network = ref.watch(networkConfigProvider);
    final notifier = ref.read(networkConfigProvider.notifier);
    final vpnOn = network.vpnEnable;
    return CommonScaffold(
      title: '网络',
      body: PageBody(
        children: [
          generateSection(
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.vpn),
                title: const Text('启用 VPN'),
                subtitle: const Text('以系统 VPN 方式接管流量'),
                value: vpnOn,
                onChanged: notifier.setVpnEnable,
              ),
            ],
            footer: vpnOn
                ? '关闭 VPN 会立即断开当前连接，下面依赖它的选项会一并置灰。'
                : 'VPN 已关闭：流量不再经过内核，下面的选项仅影响手动代理。',
          ),
          generateSection(
            title: 'VPN',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.toggle),
                title: const Text('接管系统代理'),
                subtitle: const Text('把系统 HTTP 代理指向混合端口'),
                value: network.vpnSystemProxy,
                onChanged: vpnOn ? notifier.setVpnSystemProxy : null,
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.split),
                title: const Text('允许绕过'),
                subtitle: const Text('允许指定应用绕过 VPN，直接走物理网络'),
                value: network.allowBypass,
                onChanged: vpnOn ? notifier.setAllowBypass : null,
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.rules),
                title: const Text('绕过域名'),
                subtitle: Text(
                  network.bypassDomain.isEmpty
                      ? '未设置，全部流量进入 VPN'
                      : '${configListSummary(network.bypassDomain)}，这些域名直连',
                ),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 16),
                onTap: vpnOn
                    ? () => showNetworkStringListSheet(
                        context,
                        NetworkStringList.bypassDomain,
                      )
                    : null,
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.vpn),
                title: const Text('IPv6 入站'),
                subtitle: const Text('允许 VPN 接管 IPv6 流量'),
                value: network.ipv6,
                onChanged: vpnOn ? notifier.setIpv6 : null,
              ),
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.dns),
                title: const Text('DNS 劫持'),
                subtitle: const Text('把发往 53 端口的请求转给内核 DNS'),
                value: network.dnsHijacking,
                onChanged: vpnOn ? notifier.setDnsHijacking : null,
              ),
            ],
            footer:
                '绕过域名里的匹配项不进入虚拟网卡，'
                '适合保留内网设备发现与投屏。',
          ),
          const TunConfigSection(),
          const NetworkOptionsSection(),
        ],
      ),
    );
  }
}

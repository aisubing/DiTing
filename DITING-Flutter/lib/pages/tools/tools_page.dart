/// Network diagnostics: four tabs; `Stack` + `Offstage` keeps each tab state.
library;

import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/data/native/dns_latency_bridge.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:diting/state/network_tools_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/page_intro.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'tools_dns_panel.dart';
part 'tools_panels.dart';
part 'tools_ping_panel.dart';
part 'tools_speed_panel.dart';
part 'tools_trace_panel.dart';

enum NetworkTool {
  speedTest('测速', AppGlyphs.speed),
  ping('Ping 测试', AppGlyphs.connections),
  dnsLookup('DNS 解析', AppGlyphs.dns),
  traceroute('路由追踪', AppGlyphs.split);

  const NetworkTool(this.label, this.glyph);

  final String label;
  final Glyph glyph;
}

class ToolsPage extends ConsumerStatefulWidget {
  const ToolsPage({super.key});

  @override
  ConsumerState<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends ConsumerState<ToolsPage> {
  /// The default tab matches the legacy view model, which starts on `PING` even though
  /// `SPEED_TEST` is declared first.
  var _tool = NetworkTool.ping;

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '网络诊断',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.refresh,
          tooltip: '刷新网络信息',
          onPressed: () => ref.invalidate(networkInfoProvider),
        ),
      ],
      body: AppBarClearance(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _NetworkOverviewCard(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SegmentedControl<NetworkTool>(
                segments: [
                  for (final tool in NetworkTool.values) (tool, tool.label),
                ],
                value: _tool,
                onChanged: (tool) => setState(() => _tool = tool),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  for (final tool in NetworkTool.values)
                    Offstage(
                      offstage: tool != _tool,
                      child: TickerMode(
                        enabled: tool == _tool,
                        child: switch (tool) {
                          NetworkTool.speedTest => const _SpeedTestPanel(),
                          NetworkTool.ping => const _PingPanel(),
                          NetworkTool.dnsLookup => const _DnsLookupPanel(),
                          NetworkTool.traceroute => const _TraceroutePanel(),
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Current network" overview: type, local addresses and DNS servers. Vertical space is scarce
/// because all four tabs sit below, so the legacy expandable card is collapsed into one line.
class _NetworkOverviewCard extends ConsumerWidget {
  const _NetworkOverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final info = ref.watch(networkInfoProvider).value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            StatStrip(
              stats: [
                StatItem(
                  label: '活动接口',
                  value: info == null ? '—' : networkInterfaceLabel(info),
                  color: info?.vpnActive == true
                      ? colorScheme.warning
                      : colorScheme.success,
                ),
                StatItem(
                  label: '本机地址',
                  value: (info?.localIpv4.isNotEmpty ?? false)
                      ? info!.localIpv4
                      : '—',
                ),
                StatItem(
                  label: 'DNS 服务器',
                  value: (info?.dnsServers.isNotEmpty ?? false)
                      ? '${info!.dnsServers.length}'
                      : '—',
                  unit: (info?.dnsServers.isNotEmpty ?? false) ? '个' : null,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  GlyphIcon(
                    AppGlyphs.info,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Text(
                      info != null && info.privateDns != 'off'
                          ? '探测走物理网络（本应用流量不经过隧道）；'
                                '系统私人 DNS：${info.privateDns}'
                          : '探测走物理网络：本应用自身流量被排除在隧道外，'
                                '下面四个工具测的都是物理链路的真实时延。',
                      style: context.listCaptionStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

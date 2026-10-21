/// 网络诊断：测速 / Ping 测试 / DNS 解析 / 路由追踪四个并列页签。
///
/// 与 1.4.3 `ui/NetworkToolsScreen.kt` 同构：顶部固定一张「当前网络」概览卡，
/// 下面是一条四段控件，正文随页签切换。旧版用 `HorizontalPager`；这里用
/// `Stack` + `Offstage` 保活——四个页签的状态（已填目标、已得结果）在切换时
/// 保留，而 `Offstage` 让非当前页签既不参与布局也不被测试的默认 finder 命中。
///
/// ## 数据来源（全部经原生通道，没有 mock 数字）
/// - 测速 → `com.haoze.diting/dns_latency` 的 `probe`（见
///   `lib/data/native/dns_latency_bridge.dart`）：真实 DoH / DoT / 明文查询，
///   每个服务商 3 次取成功样本平均。通道不存在时页面显示「当前设备不支持测速」
///   并禁用按钮。
/// - Ping → `DiagnosticsRunner.ping`（原生 `NetworkPingTool`：优先系统 `ping`
///   二进制；受限时回退 `isReachable` / TCP 握手，结果带
///   `measuredWithFallback=true`，面板必须如实提示）
/// - DNS 解析 → `DiagnosticsRunner.lookupDns`（`viaTunnel` 决定问引擎还是系统）
/// - 路由追踪 → `DiagnosticsRunner.traceRoute`
/// - 顶部概览卡 → `DiagnosticsRunner.networkInfo`（`NetworkInfoProbe` 快照），
///   不使用任何硬编码延迟与运行时长
///
/// ## 为什么四个工具共用一个路由
/// 它们的操作模型完全相同（填一个目标 → 跑一次 → 看结果），合并后用户换工具
/// 不需要退回上一级；旧版也是同一屏四页签。
library;

import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/data/native/dns_latency_bridge.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:diting/state/network_tools_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'tools_dns_panel.dart';
part 'tools_panels.dart';
part 'tools_ping_panel.dart';
part 'tools_speed_panel.dart';
part 'tools_trace_panel.dart';

/// 四个页签。`label` 逐字照抄旧版 `NetworkToolMode`。
enum NetworkTool {
  speedTest('测速', AppGlyphs.speed),
  ping('Ping 测试', AppGlyphs.connections),
  dnsLookup('DNS 解析', AppGlyphs.dns),
  traceroute('路由追踪', AppGlyphs.split);

  const NetworkTool(this.label, this.glyph);

  final String label;
  final Glyph glyph;
}

/// 网络诊断页。
class ToolsPage extends ConsumerStatefulWidget {
  const ToolsPage({super.key});

  @override
  ConsumerState<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends ConsumerState<ToolsPage> {
  /// 默认页签照抄旧版 `NetworkToolsViewModel`：`_toolMode` 的初值是
  /// `NetworkToolMode.PING`——枚举里虽然 `SPEED_TEST` 排第一，打开时停在
  /// 「Ping 测试」。
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

/// 顶部「当前网络」概览：当前网络类型 / 本机地址 / DNS 服务器。
///
/// 高度必须省着用——四页签的正文都排在它下面。旧版的展开式详情卡（IPv4 /
/// IPv6 / 网关 / DNS 逐条 + 复制）在这里收成一行说明，完整信息仍可从
/// 「本机地址」与 DNS 服务器个数看出；`privateDns` 只在开启时追加一行。
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

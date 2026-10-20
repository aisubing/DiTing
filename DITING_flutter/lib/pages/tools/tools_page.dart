/// 网络工具：Ping / DNS 查询 / 路由追踪三个入口。
///
/// 三个工具共用一个页面而不是三个路由：它们的操作模型完全相同（填一个目标 →
/// 跑一次 → 看结果），合并后用户换工具不需要退回上一级。
///
/// 面板全部走 `showSheet`：工具是「临时用一下」的动作，做成独立路由会留下一串
/// 返回栈，而结果也没有长期保留的价值。
///
/// ## 数据来源（全部经 `lib/data/native/diagnostics_bridge.dart`）
/// - Ping → `DiagnosticsRunner.ping`（原生 `NetworkPingTool`：优先系统 `ping`
///   二进制；受限时回退 `isReachable` / TCP 握手，结果带
///   `measuredWithFallback=true`，面板必须如实提示）
/// - DNS 查询 → `DiagnosticsRunner.lookupDns`（`viaTunnel` 决定问引擎还是系统）
/// - 路由追踪 → `DiagnosticsRunner.traceRoute`
/// - 顶部信息条 → `DiagnosticsRunner.networkInfo`（`NetworkInfoProbe` 快照），
///   不再使用 `mockServiceStats` 里的硬编码延迟与运行时长
///
/// ## 已删除的功能
/// 1.4.3 的第四个入口「网络测速」在本轮**删除**：`NetworkToolsViewModel` 的
/// `SPEED_TEST` 指向 `SpeedTestSection(RaceModeSettingsViewModel)`，那是服务商
/// 竞速，不是带宽测速；本仓没有任何带宽测速后端，保留面板只能显示假数字。
library;

import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'tools_dns_panel.dart';
part 'tools_panels.dart';
part 'tools_ping_panel.dart';
part 'tools_trace_panel.dart';

/// 一个工具入口。
class _ToolEntry {
  const _ToolEntry({
    required this.title,
    required this.subtitle,
    required this.glyph,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final Glyph glyph;
  final WidgetBuilder builder;
}

/// 网络工具页。
class ToolsPage extends ConsumerWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final info = ref.watch(networkInfoProvider).value;
    final entries = <_ToolEntry>[
      _ToolEntry(
        title: 'Ping',
        subtitle: '探测目标可达性与往返延迟',
        glyph: AppGlyphs.connections,
        builder: (_) => const _PingPanel(),
      ),
      _ToolEntry(
        title: 'DNS 查询',
        subtitle: '按记录类型查询域名，可切换是否走隧道',
        glyph: AppGlyphs.dns,
        builder: (_) => const _DnsLookupPanel(),
      ),
      _ToolEntry(
        title: '路由追踪',
        subtitle: '逐跳查看到达目标的路径',
        glyph: AppGlyphs.layers,
        builder: (_) => const _TraceroutePanel(),
      ),
    ];

    return CommonScaffold(
      title: '网络工具',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.refresh,
          tooltip: '刷新网络信息',
          onPressed: () => ref.invalidate(networkInfoProvider),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              child: StatStrip(
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      GlyphIcon(
                        AppGlyphs.info,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      Text('探测走物理网络', style: context.listTitleStyle),
                    ],
                  ),
                  Text(
                    '与 1.4.3 一致：本应用自身流量被排除在隧道外，Ping 与路由追踪测的是'
                    '物理链路的真实时延。需要走隧道时，在各面板里打开对应开关。',
                    style: context.listSubtitleStyle,
                  ),
                  if (info != null && info.privateDns != 'off')
                    Text(
                      '系统私人 DNS：${info.privateDns}',
                      style: context.listCaptionStyle,
                    ),
                ],
              ),
            ),
          ),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: CommonCard(
                onPressed: () =>
                    showSheet<void>(context: context, builder: entry.builder),
                child: ListItem(
                  leading: GlyphIcon(entry.glyph, size: 22),
                  title: Text(entry.title),
                  subtitle: Text(entry.subtitle),
                  trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 18),
                  onTap: () =>
                      showSheet<void>(context: context, builder: entry.builder),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

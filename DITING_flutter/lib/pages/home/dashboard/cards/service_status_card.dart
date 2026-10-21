import 'package:diting/data/native/dns_latency_bridge.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/network_tools_providers.dart';
import 'package:diting/state/service_probe_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

export 'package:diting/state/service_probe_providers.dart'
    show ProbeKind, ProbeService, probeAgoLabel, probeServicesProvider;

/// 服务状态卡（上游 `widgets/service_status.dart`，1050 行）。
///
/// 上游这张卡有「单服务大圆环」与「多服务迷你列表」两种形态，这里取多服务
/// 形态：每行一个探测项 + 状态点 + 可点开看最近一次结果。1050 行里绝大部分是
/// 桌面多列与动画细节，Android 单列用不到。
///
/// ## 探测是真的
/// 点刷新会调 `dnsLatencyRunnerProvider`（原生 `DnsLatencyBridge` → 真实
/// DoH/DoT/UDP 查询），耗时是实测值；失败显示「失败」，设备没有通道则整列
/// 显示「不可用」。**没有**「按行号编一个 12 + index*9」的演示值。
///
/// ## 探测目标也不是写死的
/// 四行的端口、服务商、缓存条数、已测速个数全部来自真实状态，见
/// `state/service_probe_providers.dart` 的 `probeServicesProvider`。
class ServiceStatusCard extends ConsumerStatefulWidget {
  const ServiceStatusCard({super.key, this.onDetail});

  /// 右上角「详情」的落点（有对应下钻页时才给）。
  final VoidCallback? onDetail;

  @override
  ConsumerState<ServiceStatusCard> createState() => _ServiceStatusCardState();
}

class _ServiceStatusCardState extends ConsumerState<ServiceStatusCard> {
  /// 每项实测耗时；`null` = 尚未探测，`-1` = 探测失败。与上游同语义。
  final Map<String, int> _latencies = {};
  var _probing = false;
  var _unavailable = false;
  DateTime? _lastProbeAt;

  @override
  Widget build(BuildContext context) {
    final core = ref.watch(coreStateProvider);
    final services = ref.watch(probeServicesProvider);
    final scale = DashboardDensityScope.scaleOf(context);
    final colorScheme = context.colorScheme;

    final targets = [
      for (final service in services)
        if (service.spec != null) service,
    ];
    final alive = targets
        .where((service) => (_latencies[service.id] ?? -1) > 0)
        .length;
    return DashboardCard(
      semanticLabel: '服务状态',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.status,
            title: '服务状态',
            trailing: [
              if (widget.onDetail != null)
                DashboardIconButton(
                  glyph: AppGlyphs.chevronForward,
                  tooltip: '详情',
                  onPressed: widget.onDetail,
                ),
              DashboardIconButton(
                glyph: AppGlyphs.refresh,
                tooltip: '重新探测',
                onPressed: core.isRunning && !_probing ? _probe : null,
              ),
            ],
          ),
          // 摘要行：活着几个 / 可探测几个。没有可探测项时不给 0/0。
          Row(
            spacing: 8,
            children: [
              DashboardChip(
                label: _probing
                    ? '探测中…'
                    : targets.isEmpty
                    ? '无可探测项'
                    : '$alive / ${targets.length} 正常',
                tone: _probing
                    ? DashboardChipTone.idle
                    : targets.isEmpty || alive < targets.length
                    ? DashboardChipTone.warn
                    : DashboardChipTone.ok,
                dot: true,
              ),
              if (!core.isRunning)
                Text(
                  '内核未运行',
                  style: DashboardText.label(context, color: colorScheme.error),
                ),
            ],
          ),
          for (final service in services)
            _ProbeRow(
              service: service,
              latency: _latencies[service.id],
              probing: _probing,
              unavailable: _unavailable,
              disabled: !core.isRunning,
              onTap: () => showSheet<void>(
                context: context,
                builder: (_) => _ProbeDetailSheet(
                  service: service,
                  latency: _latencies[service.id],
                  lastProbeAt: _lastProbeAt,
                  unavailable: _unavailable,
                ),
              ),
            ),
          SizedBox(height: 2 * scale),
        ],
      ),
    );
  }

  /// 真实探测：把所有带网络目标的项一次性交给原生测速通道。
  ///
  /// 一轮 `probe` 而不是逐项 `await`：原生侧本来就是并发跑的，逐项等待会把
  /// 「N 项 × 3 次查询」串成一条长队。
  Future<void> _probe() async {
    final targets = [
      for (final service in ref.read(probeServicesProvider))
        if (service.spec != null) service,
    ];
    if (targets.isEmpty) return;
    setState(() {
      _probing = true;
      _latencies.clear();
      _unavailable = false;
    });
    try {
      final samples = await ref
          .read(dnsLatencyRunnerProvider)
          .probe(
            providers: [for (final service in targets) service.spec!],
            domain: ref.read(latencyDomainProvider),
            attempts: 1,
          );
      if (!mounted) return;
      final byId = {for (final sample in samples) sample.providerId: sample};
      setState(() {
        _probing = false;
        _lastProbeAt = DateTime.now();
        for (final service in targets) {
          final sample = byId[service.id];
          // 没有回包的项记 -1（失败），不是「仍在探测」——否则状态点会一直
          // 停在灰色，用户以为还在跑。
          _latencies[service.id] = sample == null
              ? -1
              : sample.success
              ? sample.elapsedMs
              : -1;
        }
      });
    } on DnsLatencyUnavailable {
      if (!mounted) return;
      setState(() {
        _probing = false;
        _unavailable = true;
        _latencies.clear();
      });
    }
  }
}

class _ProbeRow extends StatelessWidget {
  const _ProbeRow({
    required this.service,
    required this.latency,
    required this.probing,
    required this.unavailable,
    required this.disabled,
    required this.onTap,
  });

  final ProbeService service;
  final int? latency;
  final bool probing;
  final bool unavailable;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final failed = latency != null && latency! < 0;
    final hasTarget = service.spec != null;
    final pending = probing || (hasTarget && latency == null);
    final dotColor = disabled || pending
        ? colorScheme.outline
        : failed
        ? colorScheme.error
        : colorScheme.success;
    final trailing = !hasTarget
        ? '—'
        : disabled
        ? '—'
        : unavailable
        ? '不可用'
        : pending
        ? '…'
        : failed
        ? '失败'
        : '${latency}ms';
    final shape = AppShape.all(AppCorner.md);
    return Semantics(
      button: true,
      label: '${service.name} $trailing',
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            spacing: 10,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: ShapeDecoration(
                  color: dotColor,
                  shape: const CircleBorder(),
                ),
              ),
              GlyphIcon(
                _glyphOf(service.kind),
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 1,
                  children: [
                    Text(
                      service.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardText.rowTitle(context),
                    ),
                    Text(
                      service.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardText.label(context),
                    ),
                  ],
                ),
              ),
              Text(
                trailing,
                style: DashboardText.label(
                  context,
                  color: failed ? colorScheme.error : null,
                ),
              ),
              GlyphIcon(
                AppGlyphs.chevronForward,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Glyph _glyphOf(ProbeKind kind) => switch (kind) {
    ProbeKind.dns => AppGlyphs.dns,
    ProbeKind.http => AppGlyphs.link,
    ProbeKind.cache => AppGlyphs.layers,
    ProbeKind.upstream => AppGlyphs.cloudSync,
  };
}

class _ProbeDetailSheet extends StatelessWidget {
  const _ProbeDetailSheet({
    required this.service,
    required this.latency,
    required this.lastProbeAt,
    required this.unavailable,
  });

  final ProbeService service;
  final int? latency;
  final DateTime? lastProbeAt;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final measured = latency != null && latency! > 0;
    return CommonScaffold(
      title: service.name,
      body: ListView(
        // 浮层标题浮在正文之上，不预留这段留白首行就被标题压住。
        padding: EdgeInsets.only(top: context.contentTopPadding, bottom: 24),
        children: [
          const ListHeader(title: '探测项'),
          ListItem(
            leading: GlyphIcon(_ProbeRow._glyphOf(service.kind)),
            title: const Text('类型'),
            trailing: Text(service.kind.label),
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.link),
            title: const Text('目标'),
            subtitle: Text(service.description),
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.speed),
            title: const Text('最近结果'),
            trailing: Text(
              service.spec == null
                  ? '无网络目标'
                  : unavailable
                  ? '不可用'
                  : measured
                  ? '${latency}ms'
                  : latency == null
                  ? '尚未探测'
                  : '失败',
            ),
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.clock),
            title: const Text('最近探测'),
            trailing: Text(probeAgoLabel(lastProbeAt)),
          ),
          if (service.spec == null)
            const ListFooter(
              text: '这一项没有网络目标：它显示的是本地表里的实际条数与累计命中，'
                  '不会发起查询。',
            )
          else if (unavailable)
            const ListFooter(text: '当前设备没有可用的测速通道，无法发起真实查询。'),
        ],
      ),
    );
  }
}

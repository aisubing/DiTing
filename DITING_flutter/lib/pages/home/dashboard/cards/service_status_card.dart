import 'package:diting/data/mock_dashboard.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 单个被探测服务（上游 `widgets/service_status.dart` 的 ServiceStatus）。
class ProbeService {
  const ProbeService({
    required this.name,
    required this.description,
    required this.kind,
  });

  final String name;
  final String description;
  final ProbeKind kind;

  Glyph get glyph => switch (kind) {
    ProbeKind.dns => AppGlyphs.dns,
    ProbeKind.http => AppGlyphs.link,
    ProbeKind.cache => AppGlyphs.layers,
    ProbeKind.upstream => AppGlyphs.cloudSync,
  };
}

/// 服务种类。决定图标与探测方式说明，避免把「类型」写成裸字符串。
enum ProbeKind {
  dns('DNS'),
  http('HTTP'),
  cache('缓存'),
  upstream('上游');

  const ProbeKind(this.label);

  final String label;
}

const probeServices = <ProbeService>[
  ProbeService(
    name: '本机解析',
    description: '53 端口 · UDP',
    kind: ProbeKind.dns,
  ),
  ProbeService(
    name: 'DoH 通道',
    description: 'https://doh.example/dns-query',
    kind: ProbeKind.http,
  ),
  ProbeService(
    name: '本地缓存',
    description: '容量 4096 · 命中 98%',
    kind: ProbeKind.cache,
  ),
  ProbeService(
    name: '上游服务商',
    description: '5 个可用 · 1 个异常',
    kind: ProbeKind.upstream,
  ),
];

/// 服务状态卡（上游 `widgets/service_status.dart`，1050 行）。
///
/// 上游这张卡有「单服务大圆环」与「多服务迷你列表」两种形态，这里取多服务
/// 形态：每行一个探测项 + 状态点 + 可点开看延迟历史。1050 行里绝大部分是
/// 桌面多列与动画细节，Android 单列用不到。
class ServiceStatusCard extends ConsumerStatefulWidget {
  const ServiceStatusCard({super.key});

  @override
  ConsumerState<ServiceStatusCard> createState() => _ServiceStatusCardState();
}

class _ServiceStatusCardState extends ConsumerState<ServiceStatusCard> {
  /// 每项延迟；`null` = 尚未探测，`-1` = 探测失败。与上游同语义。
  final Map<String, int?> _latencies = {};
  var _probing = false;

  @override
  Widget build(BuildContext context) {
    final core = ref.watch(coreStateProvider);
    final scale = DashboardDensityScope.scaleOf(context);
    final colorScheme = context.colorScheme;
    final alive = _latencies.entries.where((e) => (e.value ?? -1) > 0).length;
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
              DashboardIconButton(
                glyph: AppGlyphs.refresh,
                tooltip: '重新探测',
                onPressed: core == CoreState.running && !_probing
                    ? _probe
                    : null,
              ),
            ],
          ),
          // 摘要行：活着几个 / 共几个。
          Row(
            spacing: 8,
            children: [
              DashboardChip(
                label: _probing
                    ? '探测中…'
                    : '$alive / ${probeServices.length} 正常',
                tone: _probing
                    ? DashboardChipTone.idle
                    : alive == probeServices.length
                    ? DashboardChipTone.ok
                    : DashboardChipTone.warn,
                dot: true,
              ),
              if (core != CoreState.running)
                Text(
                  '内核未运行',
                  style: DashboardText.label(context, color: colorScheme.error),
                ),
            ],
          ),
          for (final service in probeServices)
            _ProbeRow(
              service: service,
              latency: _latencies[service.name],
              probing: _probing,
              disabled: core != CoreState.running,
              onTap: () => showSheet<void>(
                context: context,
                builder: (_) => _ProbeDetailSheet(service: service),
              ),
            ),
          SizedBox(height: 2 * scale),
        ],
      ),
    );
  }

  /// 演示探测：先清空、900ms 后填回一组稳定值。
  ///
  /// 不用随机数：随机值会让 widget 测试与截图不可复现（AGENT_MISTAKES）。
  Future<void> _probe() async {
    setState(() {
      _probing = true;
      _latencies.clear();
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    setState(() {
      _probing = false;
      for (final (index, service) in probeServices.indexed) {
        // 上游「异常的那个」固定不吃延迟，用来演示红色失败态。
        _latencies[service.name] = index == 3 ? -1 : 12 + index * 9;
      }
    });
  }
}

class _ProbeRow extends StatelessWidget {
  const _ProbeRow({
    required this.service,
    required this.latency,
    required this.probing,
    required this.disabled,
    required this.onTap,
  });

  final ProbeService service;
  final int? latency;
  final bool probing;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final failed = latency != null && latency! < 0;
    final pending = probing || latency == null;
    final dotColor = disabled
        ? colorScheme.outline
        : pending
        ? colorScheme.outline
        : failed
        ? colorScheme.error
        : colorScheme.success;
    final trailing = disabled
        ? '—'
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
                service.glyph,
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
}

class _ProbeDetailSheet extends StatelessWidget {
  const _ProbeDetailSheet({required this.service});

  final ProbeService service;

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: service.name,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListHeader(title: '探测项'),
          ListItem(
            leading: GlyphIcon(service.glyph),
            title: const Text('类型'),
            trailing: Text(service.kind.label),
          ),
          ListItem(
            leading: const GlyphIcon(AppGlyphs.link),
            title: const Text('目标'),
            subtitle: Text(service.description),
          ),
          const ListItem(
            leading: GlyphIcon(AppGlyphs.clock),
            title: Text('最近探测'),
            trailing: Text('12 秒前'),
          ),
          const ListFooter(text: '演示数据：探测结果不来自真实网络。'),
        ],
      ),
    );
  }
}

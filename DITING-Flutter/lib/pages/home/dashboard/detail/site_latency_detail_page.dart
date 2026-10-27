import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/data/site_latency_categories.dart';
import 'package:diting/data/site_latency_targets.dart';
import 'package:diting/pages/home/dashboard/detail/dashboard_detail_parts.dart';
import 'package:diting/pages/home/dashboard/detail/site_latency_category_section.dart';
import 'package:diting/routes/home_detail_routes.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:diting/state/primary_provider_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Site latency detail: every site grouped by category, each group probed on demand. Nothing runs
/// on open — a page that probes 44 hosts on arrival both stalls and burns traffic — so the user
/// picks a category, or asks for everything with the app-bar action.
class SiteLatencyDetailPage extends ConsumerStatefulWidget {
  const SiteLatencyDetailPage({super.key});

  @override
  ConsumerState<SiteLatencyDetailPage> createState() =>
      _SiteLatencyDetailPageState();
}

class _SiteLatencyDetailPageState extends ConsumerState<SiteLatencyDetailPage> {
  final Map<String, PingSummary> _results = {};
  final Set<SiteCategory> _probing = {};
  DateTime? _lastRunAt;

  bool get _anyProbing => _probing.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final primary = ref.watch(primaryProviderProvider);
    final measured = _results.values.toList();
    final alive = measured.where((result) => result.success).length;
    final failed = measured.where((result) => !result.success).length;
    final averages = [for (final result in measured) ?result.avgMs];
    final average = averages.isEmpty
        ? null
        : averages.reduce((a, b) => a + b) / averages.length;
    return DashboardDetailScaffold(
      title: '测速详情',
      actions: [
        IconButton(
          tooltip: '测全部',
          onPressed: _anyProbing ? null : () => _probe(null),
          icon: const GlyphIcon(AppGlyphs.speed),
        ),
        IconButton(
          tooltip: '自定义仪表盘站点',
          onPressed: () => context.push(HomeDetailPaths.latencySites),
          icon: const GlyphIcon(AppGlyphs.customize),
        ),
      ],
      children: [
        DashboardDetailHero(
          glyph: AppGlyphs.target,
          label: '站点连通性',
          value: _anyProbing
              ? '测速中'
              : measured.isEmpty
              ? '未测速'
              : '$alive / ${measured.length}',
          chipLabel: _anyProbing
              ? '进行中'
              : measured.isEmpty
              ? '待测'
              : failed == 0
              ? '全部通畅'
              : '$failed 个失败',
          chipColor: measured.isEmpty
              ? colorScheme.onSurfaceVariant
              : failed == 0
              ? colorScheme.success
              : colorScheme.warning,
          hint: _anyProbing
              ? '正在逐个站点测速…'
              : measured.isEmpty
              ? '选一个分类点测速，或点右上角测全部。'
              : '最近测速 ${elapsedAgoLabel(_lastRunAt)}'
                    '${primary == null ? '' : ' · 解析服务商 ${primary.name}'}',
        ),
        DashboardDetailCard(
          glyph: AppGlyphs.speed,
          title: '本次结果',
          child: DashboardStatGrid(
            stats: [
              StatItem(
                label: '通畅',
                value: '$alive',
                color: colorScheme.success,
              ),
              StatItem(
                label: '失败',
                value: '$failed',
                color: failed > 0 ? colorScheme.error : null,
              ),
              StatItem(
                label: '平均往返',
                value: average == null ? '—' : '${average.round()}',
                unit: average == null ? null : 'ms',
              ),
              StatItem(label: '已测站点', value: '${measured.length}'),
            ],
          ),
        ),
        for (final category in SiteCategory.values)
          SiteLatencyCategorySection(
            category: category,
            targets: siteLatencyInCategory(category),
            results: _results,
            probing: _probing.contains(category),
            lastRunAt: _lastRunAt,
            onProbe: () => _probe(category),
          ),
        const DashboardDetailNote(
          text:
              '每个站点发 3 个 ICMP 回显，取平均值；'
              '系统 ping 不可用时退回 TCP 握手，会标上 * 号，数值略高于真实往返。'
              '本应用自身流量不经过 VPN，测的是物理网络。',
        ),
      ],
    );
  }

  /// Probes one category, or every category when [category] is null. Groups already running are
  /// skipped, so tapping another group's button while one is in flight does not restart it.
  Future<void> _probe(SiteCategory? category) async {
    final pending = category == null
        ? [
            for (final item in SiteCategory.values)
              if (!_probing.contains(item)) item,
          ]
        : _probing.contains(category)
        ? <SiteCategory>[]
        : [category];
    if (pending.isEmpty) return;
    final targets = [
      for (final item in pending) ...siteLatencyInCategory(item),
    ];
    setState(() {
      _probing.addAll(pending);
      for (final target in targets) {
        _results.remove(target.id);
      }
    });
    final runner = ref.read(diagnosticsRunnerProvider);
    final summaries = await Future.wait([
      for (final target in targets)
        runner.ping(target.host, count: 3, timeoutSeconds: 2),
    ]);
    if (!mounted) return;
    setState(() {
      _probing.removeAll(pending);
      _lastRunAt = DateTime.now();
      for (final (index, summary) in summaries.indexed) {
        _results[targets[index].id] = summary;
      }
    });
  }
}

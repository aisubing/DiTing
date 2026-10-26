import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/data/site_latency_targets.dart';
import 'package:diting/pages/home/dashboard/detail/dashboard_detail_parts.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:diting/state/primary_provider_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Site latency detail: the card shows one number per site and hides the rest in a tap sheet.
/// This page puts all four side by side with every measured field (min / max / jitter / loss /
/// resolved address / sample count), so a bad site can be diagnosed without opening four sheets.
class SiteLatencyDetailPage extends ConsumerStatefulWidget {
  const SiteLatencyDetailPage({super.key});

  @override
  ConsumerState<SiteLatencyDetailPage> createState() =>
      _SiteLatencyDetailPageState();
}

class _SiteLatencyDetailPageState extends ConsumerState<SiteLatencyDetailPage> {
  final Map<String, PingSummary> _results = {};
  var _probing = false;
  DateTime? _lastRunAt;
  var _autoRan = false;

  @override
  void initState() {
    super.initState();
    // Same guard as the card: an endless probe loop would keep tests from settling.
    if (debugDisableDashboardLiveUpdates) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoRan) return;
      _autoRan = true;
      _probe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final primary = ref.watch(primaryProviderProvider);
    final alive = _results.values.where((result) => result.success).length;
    final measured = _results.length;
    final failed = _results.values.where((result) => !result.success).length;
    final averages = [
      for (final result in _results.values) ?result.avgMs,
    ];
    return DashboardDetailScaffold(
      title: '测速详情',
      actions: [
        IconButton(
          tooltip: '重新测速',
          onPressed: _probing ? null : _probe,
          icon: const GlyphIcon(AppGlyphs.refresh),
        ),
      ],
      children: [
        DashboardDetailFigure(
          label: '国内站点连通性',
          value: measured == 0 ? '—' : '$alive / ${siteLatencyTargets.length}',
          hint: _probing
              ? '正在逐个站点测速…'
              : measured == 0
              ? '尚未测速，点右上角刷新开始'
              : '最近测速 ${elapsedAgoLabel(_lastRunAt)}'
                    '${primary == null ? '' : ' · 解析服务商 ${primary.name}'}',
          color: measured == 0
              ? null
              : failed == 0
              ? colorScheme.success
              : colorScheme.warning,
        ),
        DashboardDetailStats(
          stats: [
            StatItem(label: '通畅', value: '$alive', color: colorScheme.success),
            StatItem(
              label: '失败',
              value: '$failed',
              color: failed > 0 ? colorScheme.error : null,
            ),
            StatItem(
              label: '平均往返',
              value: averages.isEmpty
                  ? '—'
                  : '${(averages.reduce((a, b) => a + b) / averages.length).round()}',
              unit: 'ms',
            ),
            StatItem(label: '站点', value: '${siteLatencyTargets.length}'),
          ],
        ),
        for (final target in siteLatencyTargets)
          _SiteSection(
            target: target,
            summary: _results[target.id],
            probing: _probing,
            lastRunAt: _lastRunAt,
          ),
        const ListFooter(
          text:
              '每个站点发 3 个 ICMP 回显，取平均值；'
              '系统 ping 不可用时退回 TCP 握手，会标上 * 号，数值略高于真实往返。'
              '本应用自身流量不经过 VPN，测的是物理网络。',
        ),
      ],
    );
  }

  /// Same probe shape as the card: four hosts concurrently, three echoes each. Serial awaits
  /// would take four times the worst case and look frozen.
  Future<void> _probe() async {
    if (_probing) return;
    setState(() {
      _probing = true;
      _results.clear();
    });
    final runner = ref.read(diagnosticsRunnerProvider);
    final summaries = await Future.wait([
      for (final target in siteLatencyTargets)
        runner.ping(target.host, count: 3, timeoutSeconds: 2),
    ]);
    if (!mounted) return;
    setState(() {
      _probing = false;
      _lastRunAt = DateTime.now();
      for (final (index, summary) in summaries.indexed) {
        _results[siteLatencyTargets[index].id] = summary;
      }
    });
  }
}

/// One site: header row, then every field the card dropped.
class _SiteSection extends StatelessWidget {
  const _SiteSection({
    required this.target,
    required this.summary,
    required this.probing,
    required this.lastRunAt,
  });

  final SiteLatencyTarget target;
  final PingSummary? summary;
  final bool probing;
  final DateTime? lastRunAt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final summary = this.summary;
    final pending = probing || summary == null;
    final ok = summary?.success ?? false;
    final (statusText, statusColor) = probing
        ? ('测速中…', colorScheme.onSurfaceVariant)
        : summary == null
        ? ('尚未测速', colorScheme.onSurfaceVariant)
        : summary.success
        ? (_latency(summary), colorScheme.success)
        : ('失败', colorScheme.error);
    return generateSection(
      title: target.name,
      footer: summary == null
          ? null
          : summary.success
          ? summary.measuredWithFallback
                ? '本次数值来自 TCP 握手 / isReachable，不是 ICMP 回显。'
                : null
          : summary.message?.isNotEmpty == true
          ? summary.message!
          : '三个回显请求都没有收到应答，可能是站点限流或当前网络不通。',
      items: [
        ListItem(
          leading: GlyphIcon(
            target.glyph,
            size: 22,
            color: pending
                ? colorScheme.onSurfaceVariant
                : ok
                ? colorScheme.success
                : colorScheme.error,
          ),
          title: Text(
            target.host,
            style: AppTextStyle.subheadline.of(context).copyWith(
              fontFamily: 'JetBrainsMono',
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Text(statusText),
          trailing: Text(
            pending ? '—' : '${summary.transmitted} 次',
            style: AppTextStyle.caption1.of(
              context,
            ).copyWith(color: statusColor),
          ),
        ),
        KeyValueRow(
          label: '平均往返',
          value: _ms(summary?.avgMs),
          monospace: true,
        ),
        KeyValueRow(
          label: '最小 / 最大',
          value: '${_ms(summary?.minMs)} / ${_ms(summary?.maxMs)}',
          monospace: true,
        ),
        KeyValueRow(label: '抖动', value: _ms(summary?.jitterMs), monospace: true),
        KeyValueRow(
          label: '丢包',
          value: summary == null
              ? '—'
              : '${summary.lossPercent.toStringAsFixed(0)}%'
                    '（${summary.received}/${summary.transmitted}）',
          monospace: true,
        ),
        if (summary?.resolvedAddress case final address? when address.isNotEmpty)
          KeyValueRow(
            label: '解析地址',
            value: '${summary!.addressFamily ?? ''} $address'.trim(),
            monospace: true,
          ),
        KeyValueRow(label: '本次测速', value: elapsedAgoLabel(lastRunAt)),
      ],
    );
  }

  static String _ms(double? value) => value == null ? '—' : '${value.round()} ms';

  static String _latency(PingSummary summary) {
    final avg = summary.avgMs;
    if (avg == null) return '无回包';
    return summary.measuredWithFallback
        ? '${avg.round()} ms*'
        : '${avg.round()} ms';
  }
}

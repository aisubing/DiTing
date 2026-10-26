import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/data/site_latency_targets.dart';
import 'package:diting/pages/home/dashboard/cards/site_latency_sheet.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:diting/state/primary_provider_providers.dart';
import 'package:diting/state/site_latency_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Real-site latency card: the four sites the user picked for the board, defaulting to Baidu,
/// Douyin, Bilibili and NetEase Music. Probes use ping with a TCP fallback marked
/// measuredWithFallback; failures show as failed, never as a fake number.
class SiteLatencyCard extends ConsumerStatefulWidget {
  const SiteLatencyCard({super.key, this.onDetail});

  /// Detail target; only set when a drill-down page exists.
  final VoidCallback? onDetail;

  @override
  ConsumerState<SiteLatencyCard> createState() => _SiteLatencyCardState();
}

class _SiteLatencyCardState extends ConsumerState<SiteLatencyCard> {
  /// Latest result per site; a missing key means not probed yet.
  final Map<String, PingSummary> _results = {};
  var _probing = false;
  DateTime? _lastRunAt;

  /// Probe once on first frame, skipped under tests where pumpAndSettle would never settle.
  var _autoRan = false;

  @override
  void initState() {
    super.initState();
    if (debugDisableDashboardLiveUpdates) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoRan) return;
      _autoRan = true;
      _probe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = DashboardDensityScope.scaleOf(context);
    final colorScheme = context.colorScheme;
    final primary = ref.watch(primaryProviderProvider);
    final sites = ref.watch(dashboardSitesProvider);

    // Both tallies only count the sites actually on the card: after the user swaps one out, a
    // stale result left in `_results` must not inflate the header.
    final measured = sites.where((site) => _results.containsKey(site.id)).length;
    final alive = sites
        .where((site) => _results[site.id]?.success ?? false)
        .length;
    final verdict = _probing
        ? '测速中…'
        : measured == 0
        ? '尚未测速'
        : '$alive / ${sites.length} 通畅';
    return DashboardCard(
      semanticLabel: '网络测速',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.speed,
            title: '网络测速',
            leading: [
              DashboardChip(
                label: verdict,
                tone: _probing || measured == 0
                    ? DashboardChipTone.idle
                    : alive == sites.length
                    ? DashboardChipTone.ok
                    : DashboardChipTone.warn,
                dot: true,
              ),
            ],
            trailing: [
              if (widget.onDetail != null)
                DashboardIconButton(
                  glyph: AppGlyphs.chevronForward,
                  tooltip: '详情',
                  onPressed: widget.onDetail,
                ),
              DashboardIconButton(
                glyph: AppGlyphs.refresh,
                tooltip: '重新测速',
                onPressed: _probing ? null : _probe,
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          for (var i = 0; i < sites.length; i += _columns)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8 * scale),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  for (final target in sites.skip(i).take(_columns))
                    Expanded(
                      child: _SiteCell(
                        target: target,
                        summary: _results[target.id],
                        probing: _probing,
                        onTap: () => showSheet<void>(
                          context: context,
                          builder: (_) => SiteLatencyTargetSheet(
                            target: target,
                            summary: _results[target.id],
                            lastRunAt: _lastRunAt,
                          ),
                        ),
                      ),
                    ),
                  if (sites.skip(i).length < _columns) const Spacer(),
                ],
              ),
            ),
          SizedBox(height: 8 * scale),
          Text(
            '最近测速 ${elapsedAgoLabel(_lastRunAt)}'
            '${primary == null ? '' : ' · 解析服务商 ${primary.name}'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.label(
              context,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static const _columns = 2;

  /// Probe the card's four sites concurrently, three ICMP echoes each: serial awaits would make
  /// the worst case 4 x 3 timeouts and look frozen.
  Future<void> _probe() async {
    if (_probing) return;
    final sites = ref.read(dashboardSitesProvider);
    setState(() {
      _probing = true;
      _results.clear();
    });
    final runner = ref.read(diagnosticsRunnerProvider);
    final summaries = await Future.wait([
      for (final target in sites)
        runner.ping(target.host, count: 3, timeoutSeconds: 2),
    ]);
    if (!mounted) return;
    setState(() {
      _probing = false;
      _lastRunAt = DateTime.now();
      for (final (index, summary) in summaries.indexed) {
        _results[sites[index].id] = summary;
      }
    });
  }
}

class _SiteCell extends StatelessWidget {
  const _SiteCell({
    required this.target,
    required this.summary,
    required this.probing,
    required this.onTap,
  });

  final SiteLatencyTarget target;
  final PingSummary? summary;
  final bool probing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final scale = DashboardDensityScope.scaleOf(context);
    final failed = summary != null && !summary!.success;
    final pending = probing || summary == null;
    final dotColor = pending
        ? colorScheme.outline
        : failed
        ? colorScheme.error
        : colorScheme.success;
    final (status, statusColor) = switch (summary) {
      _ when probing => ('测速中…', colorScheme.onSurfaceVariant),
      null => ('尚未测速', colorScheme.onSurfaceVariant),
      final s when !s.success => ('失败', colorScheme.error),
      final s => (_latencyLabel(s), colorScheme.success),
    };
    return Semantics(
      button: true,
      label: '${target.name} $status',
      child: DashboardBlock(
        padding: EdgeInsets.fromLTRB(
          10 * scale,
          10 * scale,
          10 * scale,
          9 * scale,
        ),
        child: InkWell(
          customBorder: AppShape.all(AppCorner.md),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                spacing: 6,
                children: [
                  _Badge(glyph: target.glyph, dot: dotColor),
                  Expanded(
                    child: Text(
                      target.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardText.rowTitle(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6 * scale),
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DashboardText.figure(
                  context,
                  AppTextStyle.caption1,
                  color: statusColor,
                ),
              ),
              Text(
                target.host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DashboardText.label(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Average round trip. With measuredWithFallback the value comes from a TCP
  /// handshake, so it gets a `*` suffix explained in the tooltip.
  static String _latencyLabel(PingSummary summary) {
    final avg = summary.avgMs;
    if (avg == null) return '无回包';
    final rounded = avg.round();
    return summary.measuredWithFallback ? '$rounded ms*' : '$rounded ms';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.glyph, required this.dot});

  final Glyph glyph;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final scale = DashboardDensityScope.scaleOf(context);
    final size = 26.0 * scale;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: ShapeDecoration(
              color: DashboardColors.of(context).card,
              shape: AppShape.all(AppCorner.sm),
            ),
            child: Center(
              child: GlyphIcon(
                glyph,
                // Brand glyphs sit near full size, slightly under the 15dp icon norm.
                size: size * 0.6,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 8,
              height: 8,
              decoration: ShapeDecoration(color: dot, shape: AppShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}


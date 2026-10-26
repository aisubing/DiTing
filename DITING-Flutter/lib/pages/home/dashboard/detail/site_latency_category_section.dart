/// One category block on the site-latency detail page: a header with its own probe button, then a
/// compact row per site. Tapping a row opens every measured field in a sheet.
library;

import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/data/site_latency_categories.dart';
import 'package:diting/data/site_latency_targets.dart';
import 'package:diting/pages/home/dashboard/cards/site_latency_sheet.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/pages/home/dashboard/detail/dashboard_detail_parts.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

class SiteLatencyCategorySection extends StatelessWidget {
  const SiteLatencyCategorySection({
    super.key,
    required this.category,
    required this.targets,
    required this.results,
    required this.probing,
    required this.onProbe,
    required this.lastRunAt,
  });

  final SiteCategory category;
  final List<SiteLatencyTarget> targets;
  final Map<String, PingSummary> results;
  final bool probing;
  final VoidCallback onProbe;
  final DateTime? lastRunAt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final measured = [
      for (final target in targets) ?results[target.id],
    ];
    final alive = measured.where((result) => result.success).length;
    final verdict = probing
        ? '测速中…'
        : measured.isEmpty
        ? '${targets.length} 个站点'
        : '$alive / ${targets.length} 通畅';
    return DashboardDetailCard(
      glyph: category.glyph,
      title: category.label,
      trailing: [
        Text(
          verdict,
          style: DashboardText.label(
            context,
            color: measured.isEmpty
                ? colorScheme.onSurfaceVariant
                : alive == targets.length
                ? colorScheme.success
                : colorScheme.warning,
          ),
        ),
        // `DashboardIconButton` overflows on purpose and needs a bounded height, which the
        // unbounded column of a detail page does not give it.
        IconButton(
          tooltip: '测速${category.label}',
          onPressed: probing ? null : onProbe,
          icon: const GlyphIcon(AppGlyphs.target, size: 18),
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(32),
            fixedSize: const Size.square(32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, target) in targets.indexed) ...[
            if (index > 0)
              Container(
                height: 1,
                color: colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            SiteLatencyRow(
              target: target,
              summary: results[target.id],
              probing: probing,
              onTap: () => showSheet<void>(
                context: context,
                builder: (_) => SiteLatencyTargetSheet(
                  target: target,
                  summary: results[target.id],
                  lastRunAt: lastRunAt,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Name and host on the left, the round trip on the right; the sheet holds min, max, jitter, loss
/// and the resolved address.
class SiteLatencyRow extends StatelessWidget {
  const SiteLatencyRow({
    super.key,
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
    final summary = this.summary;
    final pending = probing || summary == null;
    final ok = summary?.success ?? false;
    final statusColor = pending
        ? colorScheme.onSurfaceVariant
        : ok
        ? colorScheme.success
        : colorScheme.error;
    final status = probing
        ? '测速中…'
        : summary == null
        ? '尚未测速'
        : summary.success
        ? _latency(summary)
        : '失败';
    return Semantics(
      button: true,
      label: '${target.name} $status',
      child: InkWell(
        customBorder: AppShape.all(AppCorner.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            spacing: 12,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: ShapeDecoration(
                  color: DashboardColors.of(context).tone,
                  shape: AppShape.all(AppCorner.sm),
                ),
                child: Center(
                  child: GlyphIcon(target.glyph, size: 17, color: statusColor),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 1,
                  children: [
                    Text(
                      target.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.subheadline.of(
                        context,
                        emphasized: true,
                      ),
                    ),
                    Text(
                      target.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.caption2.of(context).copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: appMonospaceFontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                status,
                style: DashboardText.figure(
                  context,
                  AppTextStyle.footnote,
                  color: statusColor,
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

  static String _latency(PingSummary summary) {
    final avg = summary.avgMs;
    if (avg == null) return '无回包';
    return summary.measuredWithFallback
        ? '${avg.round()} ms*'
        : '${avg.round()} ms';
  }
}

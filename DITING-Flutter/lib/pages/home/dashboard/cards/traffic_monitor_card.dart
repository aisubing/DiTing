import 'package:diting/pages/home/dashboard/cards/dashboard_block_parts.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Today's traffic: each column reports its own missing-data state instead of showing a
/// fake `0 B` or `0 B/s`.
class TrafficMonitorCard extends ConsumerWidget {
  const TrafficMonitorCard({super.key, this.onDetail});

  /// Detail target; null hides the button when the home page has no stats page.
  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(trafficTotalsProvider).value;
    final series = ref.watch(speedSeriesProvider);
    final last = series.last;
    final colorScheme = context.colorScheme;
    final speedText = series.unsupported
        ? '本模式不统计'
        : series.samples.isEmpty
        ? '—'
        : '↓ ${dashboardBinarySpeed(last.down)}  '
              '↑ ${dashboardBinarySpeed(last.up)}';
    return DashboardCard(
      semanticLabel: '流量监控',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.dataUsage,
            title: '流量监控',
            trailing: [
              if (onDetail != null)
                DashboardIconButton(
                  glyph: AppGlyphs.chevronForward,
                  tooltip: '详情',
                  onPressed: onDetail,
                ),
            ],
          ),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text('今日代理流量', style: DashboardText.label(context)),
                    Text(
                      totals == null ? '—' : dashboardBinaryBytes(totals.total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardText.figure(
                        context,
                        AppTextStyle.title3,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text('实时速率', style: DashboardText.label(context)),
                    Text(
                      speedText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: DashboardText.figure(
                        context,
                        AppTextStyle.footnote,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DashboardMetricCell extends StatelessWidget {
  const DashboardMetricCell({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.label(context),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.figure(
            context,
            AppTextStyle.title2,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Merged into one card so the dashboard card border is not doubled per cell.
class DashboardMetricQuadCard extends StatelessWidget {
  const DashboardMetricQuadCard({
    super.key,
    required this.glyph,
    required this.title,
    required this.cells,
    this.onDetail,
    this.trailing,
  });

  final Glyph glyph;
  final String title;

  /// Exactly four cells as (label, value, color); fewer leave the slots unfilled.
  final List<({String label, String value, Color color})> cells;
  final VoidCallback? onDetail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardDensityScope.scaleOf(context);
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      final pair = cells.skip(i).take(2).toList();
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 14 * scale),
          child: Row(
            spacing: 16,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final cell in pair)
                Expanded(
                  child: DashboardMetricCell(
                    label: cell.label,
                    value: cell.value,
                    color: cell.color,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return DashboardCard(
      semanticLabel: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardCardHeader(
            glyph: glyph,
            title: title,
            trailing: [
              ?trailing,
              if (onDetail != null)
                DashboardIconButton(
                  glyph: AppGlyphs.chevronForward,
                  tooltip: '详情',
                  onPressed: onDetail,
                ),
            ],
          ),
          SizedBox(height: 12 * scale),
          ...rows,
        ],
      ),
    );
  }
}

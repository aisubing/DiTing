import 'package:diting/pages/home/dashboard/cards/dashboard_block_parts.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 流量监控卡（旧版 `TrafficMonitorDashboardCard`）。
///
/// 左边「今日代理流量」、右边「实时速率」，两列用 `SpaceBetween` 分开——
/// 旧版就是这样并排的，卡片高度固定在一行数字，不抢下面的概览块。
class TrafficMonitorCard extends ConsumerWidget {
  const TrafficMonitorCard({super.key, this.onDetail});

  /// 右上角「详情」的落点；首页没有流量统计页时传 null，按钮不出现。
  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(trafficTotalsProvider);
    final series = ref.watch(speedSeriesProvider);
    final last = series.last;
    final colorScheme = context.colorScheme;
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
                      dashboardBinaryBytes(totals.total),
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
                      '↓ ${dashboardBinarySpeed(last.down)}  '
                      '↑ ${dashboardBinarySpeed(last.up)}',
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

/// 一格指标：标签在上、数字在下（旧版 `MetricCard`）。
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

/// 一张「四格指标」卡：两行两列。
///
/// 旧版把四个 `MetricCard` 平铺成两行，每格是独立卡片；本仓的仪表盘卡片本身
/// 就有圆角与阴影，四格再各套一层会叠成两层边框，因此合成一张卡、格与格之间
/// 只留间距。视觉层级与「大卡里的小格」一致（`DashboardCard` + `DashboardBlock`
/// 是同一族的做法）。
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

  /// 恰好四项：`(标签, 数值, 颜色)`。少于四项时按顺序填，空位不占宽。
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

import 'dart:math' as math;

import 'package:diting/data/dashboard_models.dart';
import 'package:diting/pages/home/dashboard/cards/dashboard_block_parts.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/pages/home/dashboard/detail/dashboard_detail_chart.dart';
import 'package:diting/pages/home/dashboard/detail/dashboard_detail_parts.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Speed detail: the card draws two 60-point sparklines, no numbers beyond the instant rate. This
/// page separates upload and download into full-height curves and names the numbers the card
/// leaves to the eye — peak, average, sample window and today's cumulative totals.
class NetworkSpeedDetailPage extends ConsumerWidget {
  const NetworkSpeedDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(speedSeriesProvider);
    final totals = ref.watch(trafficTotalsProvider).value;
    final colorScheme = context.colorScheme;
    final colors = DashboardColors.of(context);
    final up = _Stats.of([for (final sample in series.samples) sample.up]);
    final down = _Stats.of([for (final sample in series.samples) sample.down]);
    final unsupported = series.unsupported;
    return DashboardDetailScaffold(
      title: '网速详情',
      children: [
        DashboardDetailHero(
          glyph: AppGlyphs.speed,
          label: '当前下载',
          value: unsupported ? '无数据' : dashboardBinarySpeed(series.last.down),
          chipLabel: unsupported ? '暂停采样' : '实时',
          chipColor: unsupported
              ? colorScheme.onSurfaceVariant
              : colorScheme.success,
          hint: unsupported
              ? _unsupportedHint(series.source)
              : '每秒采样一次，下图是最近一分钟。',
        ),
        DashboardDetailStats(
          stats: [
            StatItem(
              label: '当前上传',
              value: unsupported ? '—' : dashboardBinarySpeed(series.last.up),
              color: colors.series2,
            ),
            StatItem(
              label: '下行峰值',
              value: unsupported ? '—' : dashboardBinarySpeed(down.peak),
              color: colorScheme.primary,
            ),
            StatItem(
              label: '上行峰值',
              value: unsupported ? '—' : dashboardBinarySpeed(up.peak),
              color: colors.series2,
            ),
            StatItem(
              label: '样本',
              value: '${series.samples.length}',
              unit: '/$speedSampleCapacity',
            ),
          ],
        ),
        _CurveCard(
          title: '下载',
          color: colorScheme.primary,
          stats: down,
          values: series.downValues(),
          series: series,
        ),
        _CurveCard(
          title: '上传',
          color: colors.series2,
          stats: up,
          values: series.upValues(),
          series: series,
        ),
        DashboardDetailCard(
          glyph: AppGlyphs.dataUsage,
          title: '今日累计',
          child: totals == null
              ? Text(
                  '流量库还没有今天的记录。',
                  style: AppTextStyle.subheadline.of(
                    context,
                  ).copyWith(color: colorScheme.onSurfaceVariant),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    _TotalsBar(totals: totals, colors: colors),
                    DashboardDetailRows(
                      rows: [
                        DashboardDetailRow(
                          label: '下载',
                          value: dashboardBinaryBytes(totals.down),
                          monospace: true,
                          color: colorScheme.primary,
                        ),
                        DashboardDetailRow(
                          label: '上传',
                          value: dashboardBinaryBytes(totals.up),
                          monospace: true,
                          color: colors.series2,
                        ),
                        DashboardDetailRow(
                          label: '合计',
                          value: dashboardBinaryBytes(totals.total),
                          monospace: true,
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        DashboardDetailNote(
          text: unsupported
              ? _unsupportedHint(series.source)
              : '速率来自内核数据面的实时计数，只包含经过隧道转发的流量；'
                    '本应用自身的探测与测速不计入。今日累计来自应用流量统计，'
                    '与「流量统计」页同一份数据。',
        ),
      ],
    );
  }

  /// Why the curve is empty: one is a product decision, the other a missing host channel.
  static String _unsupportedHint(SpeedSource source) => switch (source) {
    SpeedSource.expressMode => '极速模式不经过内核数据面，因此没有逐秒速率；切回普通模式后恢复。',
    SpeedSource.noNativeChannel => '当前环境没有速率通道（桌面、组件画廊或纯 Dart 测试），读不到实时速率。',
    SpeedSource.available => '',
  };
}

/// Download/upload split of today's traffic, in the same bar language as the memory page.
class _TotalsBar extends StatelessWidget {
  const _TotalsBar({required this.totals, required this.colors});

  final TrafficTotals totals;
  final DashboardColors colors;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        DashboardShareBar(
          height: 10,
          segments: [
            (value: totals.down.toDouble(), color: colorScheme.primary),
            (value: totals.up.toDouble(), color: colors.series2),
          ],
        ),
        Row(
          children: [
            Text(
              '下行 ${dashboardPercent(totals.total <= 0 ? 0 : totals.down / totals.total)}',
              style: AppTextStyle.caption1.of(
                context,
              ).copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const Spacer(),
            Text(
              '上行 ${dashboardPercent(totals.total <= 0 ? 0 : totals.up / totals.total)}',
              style: AppTextStyle.caption1.of(
                context,
              ).copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

/// One direction: a full-height curve plus its own peak and mean.
class _CurveCard extends StatelessWidget {
  const _CurveCard({
    required this.title,
    required this.color,
    required this.stats,
    required this.values,
    required this.series,
  });

  final String title;
  final Color color;
  final _Stats stats;
  final List<double> values;
  final SpeedSeries series;

  @override
  Widget build(BuildContext context) {
    final unsupported = series.unsupported;
    return DashboardDetailChart(
      title: title,
      color: color,
      values: unsupported ? const [] : values,
      revision: series.revision,
      capacity: speedSampleCapacity,
      // 8 KB/s floor, same as the card: idle noise stays a flat line.
      minScale: 8 * 1024,
      emptyLabel: unsupported ? '当前模式下没有速率数据' : '正在等待第一个样本',
      caption: unsupported
          ? null
          : '峰值 ${dashboardBinarySpeed(stats.peak)} · '
                '平均 ${dashboardBinarySpeed(stats.average)}',
    );
  }
}

/// Peak and mean over the visible window; an empty window is all zeros, never NaN.
class _Stats {
  const _Stats({required this.peak, required this.average});

  final double peak;
  final double average;

  static _Stats of(List<double> values) {
    if (values.isEmpty) return const _Stats(peak: 0, average: 0);
    final peak = values.reduce(math.max);
    final sum = values.fold<double>(0, (total, value) => total + value);
    return _Stats(peak: peak, average: sum / values.length);
  }
}

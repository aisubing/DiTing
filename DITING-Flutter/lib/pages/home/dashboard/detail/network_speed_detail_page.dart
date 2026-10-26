import 'dart:math' as math;

import 'package:diting/data/dashboard_models.dart';
import 'package:diting/pages/home/dashboard/cards/dashboard_block_parts.dart';
import 'package:diting/pages/home/dashboard/detail/dashboard_detail_parts.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
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
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final up = _Stats.of([for (final sample in series.samples) sample.up]);
    final down = _Stats.of([for (final sample in series.samples) sample.down]);
    return DashboardDetailScaffold(
      title: '网速详情',
      children: [
        DashboardDetailFigure(
          label: '当前下载',
          value: series.unsupported
              ? '—'
              : dashboardBinarySpeed(series.last.down),
          hint: series.unsupported ? _unsupportedHint(series.source) : '每秒采样一次，下图是最近一分钟',
          color: colorScheme.primary,
        ),
        DashboardDetailStats(
          stats: [
            StatItem(
              label: '上传',
              value: series.unsupported
                  ? '—'
                  : dashboardBinarySpeed(series.last.up),
              color: colors.series2,
            ),
            StatItem(
              label: '下行峰值',
              value: series.unsupported ? '—' : dashboardBinarySpeed(down.peak),
              color: colorScheme.primary,
            ),
            StatItem(
              label: '上行峰值',
              value: series.unsupported ? '—' : dashboardBinarySpeed(up.peak),
              color: colors.series2,
            ),
            StatItem(
              label: '样本',
              value: '${series.samples.length}',
              unit: '/$speedSampleCapacity',
            ),
          ],
        ),
        _CurveSection(
          title: '下载',
          color: colorScheme.primary,
          stats: down,
          values: series.downValues(),
          series: series,
          scale: scale,
          unsupported: series.unsupported,
        ),
        _CurveSection(
          title: '上传',
          color: colors.series2,
          stats: up,
          values: series.upValues(),
          series: series,
          scale: scale,
          unsupported: series.unsupported,
        ),
        generateSection(
          title: '今日累计',
          footer: totals == null
              ? '流量库还没有今天的记录。'
              : '来自应用流量统计，与「流量统计」页同一份数据；'
                    '只统计经过 VPN 的应用流量。',
          items: [
            KeyValueRow(
              label: '下载',
              value: totals == null
                  ? '—'
                  : dashboardBinaryBytes(totals.down),
              monospace: true,
            ),
            KeyValueRow(
              label: '上传',
              value: totals == null ? '—' : dashboardBinaryBytes(totals.up),
              monospace: true,
            ),
            KeyValueRow(
              label: '合计',
              value: totals == null
                  ? '—'
                  : dashboardBinaryBytes(totals.total),
              monospace: true,
            ),
          ],
        ),
        ListFooter(
          text: series.unsupported
              ? _unsupportedHint(series.source)
              : '速率来自内核数据面的实时计数，只包含经过隧道转发的流量；'
                    '本应用自身的探测与测速不计入。',
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

/// One direction: a full-height curve plus its own averages.
class _CurveSection extends StatelessWidget {
  const _CurveSection({
    required this.title,
    required this.color,
    required this.stats,
    required this.values,
    required this.series,
    required this.scale,
    required this.unsupported,
  });

  final String title;
  final Color color;
  final _Stats stats;
  final List<double> values;
  final SpeedSeries series;
  final double scale;
  final bool unsupported;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return generateSection(
      title: title,
      footer: unsupported
          ? null
          : '峰值 ${dashboardBinarySpeed(stats.peak)} · '
                '平均 ${dashboardBinarySpeed(stats.average)}',
      items: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            height: (128 * scale).clamp(96, 200),
            child: unsupported || values.isEmpty
                ? Center(
                    child: Text(
                      unsupported ? '当前模式下没有速率数据' : '还没有采到样本',
                      style: AppTextStyle.caption1.of(
                        context,
                      ).copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : LineChart(
                    values: values,
                    revision: series.revision,
                    capacity: speedSampleCapacity,
                    // 8 KB/s floor, same as the card: idle noise stays a flat line.
                    minScale: 8 * 1024,
                    color: color,
                    baselineRatio: 1,
                  ),
          ),
        ),
      ],
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

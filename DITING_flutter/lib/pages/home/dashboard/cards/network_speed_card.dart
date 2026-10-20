import 'dart:math' as math;

import 'package:diting/data/mock_dashboard.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 网络速率卡（上游 `widgets/traffic.dart`，339 行）。
///
/// 移动端把上下行合成一张卡：两个数字并排 + 两条曲线叠在同一张图里。上游桌面端
/// 是上下行各一张卡（`SpeedCard`），Android 只有单列，合并更省竖向空间。
class NetworkSpeedCard extends ConsumerWidget {
  const NetworkSpeedCard({super.key});

  /// 图表零线贴在底部，空闲时曲线贴着卡片下沿，不留一条明显的直线。
  static const _baselineRatio = 1.0;

  /// 最小纵向刻度 8 KB/s：空闲噪声不会被放大成剧烈抖动。
  static const _minScale = 8 * 1024.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(speedSeriesProvider);
    final totals = ref.watch(trafficTotalsProvider);
    final last = series.last;
    final density = DashboardDensityScope.of(context);
    final cardPadding = dashboardCardPadding(density);
    final scale = DashboardDensityScope.scaleOf(context);
    final colors = DashboardColors.of(context);
    final colorScheme = context.colorScheme;
    final peak = series.samples.fold<double>(
      0,
      (peak, sample) => math.max(peak, math.max(sample.up, sample.down)),
    );
    return DashboardCard(
      semanticLabel: '网络速率',
      // 图表要贴着卡片下沿出血，因此这一张必须裁剪。
      clipBehavior: Clip.antiAlias,
      // `.horizontal` 是左右之和，直接 `/2` 得到的是整条边距（20），再叠一层
      // 内边距就把标题推到 40；这里按单边取半：图表 10，文字 20。
      padding: EdgeInsets.only(
        top: cardPadding.top,
        left: cardPadding.left / 2,
        right: cardPadding.right / 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: cardPadding.left / 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                DashboardCardHeader(
                  glyph: AppGlyphs.speed,
                  title: '网络速率',
                  trailing: [
                    DashboardChip(
                      label: peak > 0 ? '峰值 ${dashboardSpeed(peak)}' : '空闲',
                    ),
                  ],
                ),
                Row(
                  spacing: 20,
                  children: [
                    Expanded(
                      child: _SpeedFigure(
                        glyph: AppGlyphs.arrowUp,
                        label: '上行',
                        value: last.up,
                        color: colors.series2,
                      ),
                    ),
                    Expanded(
                      child: _SpeedFigure(
                        glyph: AppGlyphs.arrowDown,
                        label: '下行',
                        value: last.down,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                // 两条累计流量在 320 宽下放不进一行（「累计下行 1.2 GB」各约
                // 110dp + 间隙），所以用 `Expanded` 强制等分并让文字自己省略。
                Row(
                  children: [
                    Expanded(
                      child: _TotalLine(
                        label: '累计上行',
                        value: dashboardTraffic(totals.up),
                        color: colors.series2,
                      ),
                    ),
                    Expanded(
                      child: _TotalLine(
                        label: '累计下行',
                        value: dashboardTraffic(totals.down),
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 10 * scale),
          // 两张图叠在一起：下行画在主色，上行用 45% 主色；同一坐标系才能看出
          // 两者比例，分开画会各自撑满高度、失去可比性。
          SizedBox(
            height: 72 * scale,
            child: Stack(
              children: [
                Positioned.fill(
                  child: LineChart(
                    values: series.downValues(),
                    revision: series.revision,
                    capacity: speedSampleCapacity,
                    minScale: _minScale,
                    baselineRatio: _baselineRatio,
                    color: colorScheme.primary,
                  ),
                ),
                Positioned.fill(
                  child: LineChart(
                    values: series.upValues(),
                    revision: series.revision,
                    capacity: speedSampleCapacity,
                    minScale: _minScale,
                    baselineRatio: _baselineRatio,
                    color: colors.series2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedFigure extends StatelessWidget {
  const _SpeedFigure({
    required this.glyph,
    required this.label,
    required this.value,
    required this.color,
  });

  final Glyph glyph;
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Row(
          spacing: 4,
          children: [
            GlyphIcon(glyph, size: 12, color: color),
            Text(label, style: DashboardText.label(context)),
          ],
        ),
        Text(
          dashboardSpeed(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.figure(context, AppTextStyle.title3),
        ),
      ],
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 5,
      children: [
        Container(
          width: 8,
          height: 2,
          decoration: ShapeDecoration(
            color: color,
            shape: AppShape.all(1),
          ),
        ),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.label(context),
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.label(
              context,
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

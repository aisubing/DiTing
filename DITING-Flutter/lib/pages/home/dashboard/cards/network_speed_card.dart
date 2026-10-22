import 'package:diting/data/dashboard_models.dart';
import 'package:diting/pages/home/dashboard/cards/dashboard_block_parts.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 网络速度卡（FlClash `widgets/traffic.dart` 的 `NetworkSpeedCard`）。
///
/// 上游手机端是一张卡里左右两块 `_SpeedTile`：方向标签 + 大字速率 + 累计流量 +
/// 底部一条贴边的曲线。这里保留这个结构，数据换成 DITING 的真实来源——
/// 速率来自原生 `TrafficRateMonitor` 的每秒快照（`speedSeriesProvider`），
/// 累计来自旧库 `app_traffic_daily` 的当日行（`trafficTotalsProvider`）。
///
/// 与上游的两处差异都是「数据源缺失时说实话」：
/// - 极速模式 / 无原生通道时**不画曲线**：一条贴在基线上的 0 线会被读成
///   「确实没有流量」，而事实是这一模式不统计；
/// - 累计流量未就绪时显示 `—`，不是 `0 B`。
class NetworkSpeedCard extends ConsumerWidget {
  const NetworkSpeedCard({super.key, this.onDetail});

  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(speedSeriesProvider);
    final totals = ref.watch(trafficTotalsProvider).value;
    final scale = DashboardDensityScope.scaleOf(context);
    return DashboardCard(
      semanticLabel: '网络速度',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.speed,
            title: '网络速度',
            trailing: [
              if (onDetail != null)
                DashboardIconButton(
                  glyph: AppGlyphs.chevronForward,
                  tooltip: '详情',
                  onPressed: onDetail,
                ),
            ],
          ),
          SizedBox(height: 12 * scale),
          Row(
            spacing: 10,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SpeedTile(
                  label: '上传',
                  glyph: AppGlyphs.arrowUp,
                  color: DashboardColors.of(context).series2,
                  values: series.upValues(),
                  current: series.last.up,
                  total: totals?.up,
                  series: series,
                ),
              ),
              Expanded(
                child: _SpeedTile(
                  label: '下载',
                  glyph: AppGlyphs.arrowDown,
                  color: context.colorScheme.primary,
                  values: series.downValues(),
                  current: series.last.down,
                  total: totals?.down,
                  series: series,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedTile extends StatelessWidget {
  const _SpeedTile({
    required this.label,
    required this.glyph,
    required this.color,
    required this.values,
    required this.current,
    required this.total,
    required this.series,
  });

  final String label;
  final Glyph glyph;
  final Color color;
  final List<double> values;
  final double current;
  final double? total;
  final SpeedSeries series;

  /// 曲线高度。乘 `scale` 是为了放大字号时整块跟着长，而不是让文字压住曲线。
  static const _chartHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final scale = DashboardDensityScope.scaleOf(context);
    final unsupported = series.unsupported;
    final (value, unit) = unsupported
        ? ('—', '')
        : _split(dashboardBinaryBytes(current));
    return DashboardBlock(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            spacing: 4,
            children: [
              GlyphIcon(glyph, size: 14, color: colorScheme.onSurfaceVariant),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DashboardText.label(context),
                ),
              ),
            ],
          ),
          SizedBox(height: 2 * scale),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: DashboardText.figure(
                    context,
                    AppTextStyle.title3,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit/s',
                    style: DashboardText.unit(context, AppTextStyle.caption1),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            total == null ? '累计 —' : '累计 ${dashboardBinaryBytes(total!)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.label(context),
          ),
          SizedBox(height: 6 * scale),
          SizedBox(
            height: _chartHeight * scale,
            child: unsupported
                ? Center(
                    child: Text(
                      series.source == SpeedSource.expressMode
                          ? '极速模式不统计'
                          : '当前环境无速率通道',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardText.label(context),
                    ),
                  )
                : LineChart(
                    values: values,
                    revision: series.revision,
                    capacity: speedSampleCapacity,
                    // 与上游同值：空载抖动不会把曲线顶到满高。
                    minScale: 8 * 1024,
                    color: color,
                    baselineRatio: 1,
                  ),
          ),
        ],
      ),
    );
  }

  /// `1.2 MB` → `('1.2', 'MB')`；没有单位（`512 B`）时返回空串。
  static (String, String) _split(String text) {
    final at = text.lastIndexOf(' ');
    return at < 0
        ? (text, '')
        : (text.substring(0, at), text.substring(at + 1));
  }
}

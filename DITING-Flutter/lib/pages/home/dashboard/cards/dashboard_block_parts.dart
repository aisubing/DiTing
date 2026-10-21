import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 日志仪表盘的通用块原语。
///
/// 对应旧版 `ModernLogDashboardComponents.kt` 的 `ResultDonut` / `LegendRow` /
/// `RateRow` / `DashboardListRow` / `DashboardListCard`：三种日志模式与首页卡片
/// 用的是同一套件，所以这些形状只在这里定义一次——各卡片自己再画一遍圆环，圆环
/// 的线宽与留白迟早会分叉。

/// 环形图的一段：值 + 颜色。值为 0 的段由调用方先过滤掉。
typedef DonutSegment = ({int value, Color color});

/// 百分比：`12.3%`，末尾 `.0` 去掉（旧版 `formatPercent`：先四舍五入到
/// 一位小数，整数不带小数点）。
String dashboardPercent(double ratio) {
  final rounded = (ratio.clamp(0.0, 1.0) * 1000).round() / 10;
  return rounded % 1 == 0 ? '${rounded.toInt()}%' : '$rounded%';
}

/// 毫秒：`38 ms`（旧版 `formatMs` 直接四舍五入到整数）。
String dashboardLatency(double milliseconds) => '${milliseconds.round()} ms';

/// 剩余时长：`57 分钟` / `3 小时`（旧版 `formatDuration` 只到三级）。
///
/// 与 `formatDuration` 一样**不取余**：`3420` 秒显示「57 分钟」，够用且与旧版
/// 逐字一致；再细分秒数会让这一列在窄卡里换行。
String dashboardDuration(int seconds) {
  if (seconds >= 3600) return '${seconds ~/ 3600} 小时';
  if (seconds >= 60) return '${seconds ~/ 60} 分钟';
  return '$seconds 秒';
}

/// 字节数（1024 进制、两位小数），与旧版 `formatBytes` 逐字一致。
///
/// 与 `dashboard_style.dart` 的 [dashboardTraffic]（1000 进制）刻意不同：这两处
/// 数字分别出现在「流量监控卡」与「网络速率卡」里，前者对齐旧版 1.4.3，
/// 后者对齐流量页。改其中一处会立刻让两卡口径不一致——所以都只在调用点选，
/// 不做「统一」。
String dashboardBinaryBytes(num bytes) {
  const k = 1024.0;
  final value = bytes.toDouble();
  if (value >= k * k * k * k) {
    return '${(value / (k * k * k * k)).toStringAsFixed(2)} TB';
  }
  if (value >= k * k * k) {
    return '${(value / (k * k * k)).toStringAsFixed(2)} GB';
  }
  if (value >= k * k) {
    return '${(value / (k * k)).toStringAsFixed(2)} MB';
  }
  if (value >= k) {
    return '${(value / k).toStringAsFixed(1)} KB';
  }
  return '${value.round()} B';
}

/// 速率：`1.8 MB/s`（旧版 `formatSpeed`）。
String dashboardBinarySpeed(num bytesPerSecond) {
  const k = 1024.0;
  final value = bytesPerSecond.toDouble();
  if (value >= k * k) return '${(value / (k * k)).toStringAsFixed(2)} MB/s';
  if (value >= k) return '${(value / k).toStringAsFixed(0)} KB/s';
  return '${value.round()} B/s';
}

/// 结果环形图（旧版 `ResultDonut`）。
///
/// 自绘而不是引第三方图表库：形状只有一个圆环 + 一段中心文字，
/// `lib/ui/line_chart.dart` 同样是 `CustomPainter`，这里与它保持同一路数。
/// 环宽、留白比例照抄旧版：`stroke = 18dp`、内孔直径 = `0.72 * 直径`。
class DashboardResultDonut extends StatelessWidget {
  const DashboardResultDonut({
    super.key,
    required this.segments,
    required this.total,
    this.diameter = 128,
  });

  final List<DonutSegment> segments;

  /// 环中心显示的总数；为 0 时画一整圈描边色（「还没有数据」的视觉）。
  final int total;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final scale = DashboardDensityScope.scaleOf(context);
    final size = diameter * scale;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _DonutPainter(
                  segments: segments,
                  total: total,
                  track: colorScheme.outline.withValues(alpha: 0.35),
                  hole: DashboardColors.of(context).card,
                  scale: scale,
                ),
              ),
            ),
          ),
          Text(
            dashboardCount(total),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.figure(context, AppTextStyle.title3),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.total,
    required this.track,
    required this.hole,
    required this.scale,
  });

  final List<DonutSegment> segments;
  final int total;
  final Color track;
  final Color hole;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 18 * scale;
    final diameter = size.shortestSide;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: diameter / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    if (total <= 0 || segments.isEmpty) {
      canvas.drawArc(rect, -1.5708, 6.2832, false, paint..color = track);
      return;
    }
    var start = -1.5708;
    for (final segment in segments) {
      final sweep = 6.2832 * segment.value / total;
      canvas.drawArc(rect, start, sweep, false, paint..color = segment.color);
      start += sweep;
    }
    // 内孔用卡片底色盖住，形成真正的环而不是描边圆。
    canvas.drawCircle(
      size.center(Offset.zero),
      diameter * 0.72 / 2,
      Paint()..color = hole,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.total != total ||
      oldDelegate.track != track ||
      oldDelegate.hole != hole ||
      oldDelegate.segments != segments;
}

/// 图例一行：彩点 + 名称 + 右侧同色数值（旧版 `LegendRow`）。
class DashboardLegendRow extends StatelessWidget {
  const DashboardLegendRow({
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
    return Row(
      spacing: 8,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: ShapeDecoration(
            color: color,
            shape: const CircleBorder(),
          ),
        ),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.rowTitle(context)
                .copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.figure(
            context,
            AppTextStyle.footnote,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// 比率一行：标题 + 右侧数值 + 进度条（旧版 `RateRow` / `ProgressBar`）。
class DashboardRateRow extends StatelessWidget {
  const DashboardRateRow({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;

  /// 0..1；超出范围会被钳住，不抛断言。
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final color = DashboardColors.of(context);
    final scale = DashboardDensityScope.scaleOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DashboardText.rowTitle(context),
              ),
            ),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: DashboardText.label(
                  context,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 9 * scale,
            color: color.tone,
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              heightFactor: 1,
              child: ColoredBox(color: colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}

/// 列表卡里的一行：标题 / 副标题 / 右侧徽标（旧版 `DashboardListRow`）。
class DashboardLogRow extends StatelessWidget {
  const DashboardLogRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.tag,
    this.tagColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String? tag;
  final Color? tagColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final tagColor = this.tagColor ?? colorScheme.onSurfaceVariant;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 3,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DashboardText.rowTitle(context),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DashboardText.label(context),
                ),
              ],
            ),
          ),
          if (tag case final tag?)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              decoration: ShapeDecoration(
                color: tagColor.withValues(alpha: 0.12),
                shape: AppShape.all(DashboardCorner.badge - 4),
              ),
              child: Text(
                tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DashboardText.figure(
                  context,
                  AppTextStyle.caption1,
                  color: tagColor,
                ),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      customBorder: AppShape.all(AppCorner.sm),
      onTap: onTap,
      child: content,
    );
  }
}

/// 「标题 + 详情入口 + 空态或行列表」的列表卡（旧版 `DashboardListCard`）。
///
/// [rows] 为空时显示 [emptyText]，而不是一张只有标题的空卡——旧版三种模式在
/// 无数据时都是这句灰字。
class DashboardLogListCard extends StatelessWidget {
  const DashboardLogListCard({
    super.key,
    required this.glyph,
    required this.title,
    required this.emptyText,
    required this.rows,
    this.onDetail,
    this.detailTooltip = '详情',
  });

  final Glyph glyph;
  final String title;
  final String emptyText;
  final List<Widget> rows;
  final VoidCallback? onDetail;
  final String detailTooltip;

  @override
  Widget build(BuildContext context) {
    final separator = DashboardColors.of(context).tone;
    return DashboardCard(
      semanticLabel: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 2,
        children: [
          DashboardCardHeader(
            glyph: glyph,
            title: title,
            trailing: [
              if (onDetail != null)
                DashboardIconButton(
                  glyph: AppGlyphs.chevronForward,
                  tooltip: detailTooltip,
                  onPressed: onDetail,
                ),
            ],
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(emptyText, style: DashboardText.label(context)),
            )
          else
            for (final (index, row) in rows.indexed) ...[
              if (index > 0) Container(height: 1, color: separator),
              row,
            ],
          SizedBox(height: 2),
        ],
      ),
    );
  }
}

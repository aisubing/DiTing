/// 流量统计：总览 + 速率曲线 + 应用流量排行。
///
/// 结构对齐上游 `ui/traffic/`（`docs/refactor/05-traffic-log-system.md` §2.3）：
/// `TrafficGaugeCard`（总仪表盘）→ 速率曲线 → `AppTrafficRankItem` 排行 →
/// `AppTrafficDetailDialog`（点行看归因）。
///
/// 排行条是手写的 `FractionallySizedBox`，不是第三方图表：占比条只需要一个
/// 宽度比例，引入图表库会为了一个矩形带进整套坐标系与动画调度。
library;

import 'package:diting/data/mock_data.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

part 'traffic_rows.dart';

/// 时间范围。
enum _TrafficRange {
  realtime('实时'),
  today('今日'),
  week('本周');

  const _TrafficRange(this.label);

  final String label;
}

/// 流量页。
class TrafficPage extends StatefulWidget {
  const TrafficPage({super.key});

  @override
  State<TrafficPage> createState() => _TrafficPageState();
}

class _TrafficPageState extends State<TrafficPage> {
  var _range = _TrafficRange.realtime;

  /// 三个范围的采样是同一组曲线的缩放，而不是另写三份常量：同一组数据在三个
  /// 时间尺度上形状一致，才看得出「实时」只是「今日」的一小段。
  List<double> get _samples => switch (_range) {
    _TrafficRange.realtime => mockTrafficSamples,
    _TrafficRange.today => [
      for (final sample in mockTrafficSamples) sample * 1.6,
    ],
    _TrafficRange.week => [
      for (final sample in mockTrafficSamples) sample * 2.4,
    ],
  };

  /// 横轴密度随范围变：实时 30 点、今日 24 点、本周 7 点。
  int get _capacity => switch (_range) {
    _TrafficRange.realtime => mockTrafficSamples.length,
    _TrafficRange.today => 24,
    _TrafficRange.week => 7,
  };

  /// 排行按字节数降序。
  List<MockAppTraffic> get _ranking =>
      [...mockAppTraffic]..sort((a, b) => b.bytes.compareTo(a.bytes));

  int get _totalBytes => mockAppTraffic.fold(0, (sum, app) => sum + app.bytes);

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final ranking = _ranking;
    final samples = _samples;
    final total = _totalBytes;

    return CommonScaffold(
      title: '流量统计',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.info,
          tooltip: '归因说明',
          onPressed: () => showSheet<void>(
            context: context,
            builder: (_) => const _AttributionSheet(),
          ),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              child: StatStrip(
                stats: [
                  StatItem(
                    label: '今日下行',
                    value: _formatBytes(total),
                    color: colorScheme.primary,
                  ),
                  StatItem(
                    label: '今日上行',
                    value: _formatBytes((total * 0.18).round()),
                  ),
                  StatItem(
                    label: '应用数',
                    value: '${mockAppTraffic.length}',
                    unit: '个',
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedControl<_TrafficRange>(
              segments: [
                for (final range in _TrafficRange.values) (range, range.label),
              ],
              value: _range,
              onChanged: (range) => setState(() => _range = range),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  Row(
                    children: [
                      const GlyphIcon(AppGlyphs.dataUsage, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_range.label}速率',
                          style: context.listTitleStyle,
                        ),
                      ),
                      Text(
                        '${samples.last.round()} KB/s',
                        style: AppTextStyle.subheadline.of(context).copyWith(
                          color: colorScheme.primary,
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                    ],
                  ),
                  // 高度必须给死：LineChart 内部是 SizedBox.expand + CustomPaint，
                  // 放进 ListView 后没有固有高度，不约束就会抛无界高度断言。
                  SizedBox(
                    height: 132,
                    child: LineChart(
                      values: samples,
                      revision: samples.length,
                      capacity: _capacity,
                      minScale: 600,
                      color: colorScheme.primary,
                      baselineRatio: 0.78,
                    ),
                  ),
                  Text(
                    switch (_range) {
                      _TrafficRange.realtime => '最近 30 个采样点，每 2 秒一次。',
                      _TrafficRange.today => '按小时聚合的 24 个点。',
                      _TrafficRange.week => '按天聚合的 7 个点。',
                    },
                    style: AppTextStyle.caption2
                        .of(context)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          generateSection(
            title: '应用流量排行',
            footer: '占比按本日下行字节数计算；点按一行查看该应用的查询数与归因说明。',
            items: [
              for (final app in ranking)
                _AppTrafficRow(
                  app: app,
                  total: total,
                  onTap: () => showSheet<void>(
                    context: context,
                    builder: (_) => _AppTrafficSheet(app: app, total: total),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              '共 ${ranking.length} 个应用产生流量 · 合计 ${_formatBytes(total)}',
              style: context.listCaptionStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// 字节数格式化：B / KB / MB / GB。
///
/// 用 1000 进制而不是 1024：手机流量账单与运营商口径都是 1000，混用会让演示
/// 数据与用户看到的账单对不上。
String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final text = unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

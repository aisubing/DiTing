import 'package:diting/data/log_dashboard_models.dart';
import 'package:diting/pages/home/dashboard/cards/dashboard_block_parts.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/log_dashboard_overview_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 流量结构的一段，标题与顺序照抄旧版：
/// `AllModeDashboard` 是 通过/过滤/失败/旁路/缓存，`FilteredModeDashboard`
/// 是 过滤/失败/旁路。哪一种由 [TrafficStructureMode] 决定。
class TrafficStructureLegend {
  const TrafficStructureLegend({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

/// 比率行（竞速成功率 / Bootstrap 成功率 / 拦截率 / 缓存率）。
class TrafficStructureRate {
  const TrafficStructureRate({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;
}

/// 流量结构卡的两种形态。
enum TrafficStructureMode {
  /// 记录全部：五段图例 + 四条比率。
  all,

  /// 仅拦截与错误：三段图例（过滤/失败/旁路）+ 三条比率（末条是「拦截占比」）。
  filtered,
}

/// 今日流量结构卡（旧版 `今日流量结构` / `重点流量结构`）。
///
/// 环形图 + 右侧图例是一行（旧版 `Row(IntrinsicSize.Min)`），下面接若干比率行。
/// 本卡只负责排版，数字与文案由调用方（首页 / 日志页）按模式算好传进来——
/// 「今天」这个窗口的口径必须只有一个来源，卡片里再取一次就可能跨零点错位。
class TrafficStructureCard extends StatelessWidget {
  const TrafficStructureCard({
    super.key,
    required this.mode,
    required this.title,
    required this.total,
    required this.segments,
    required this.legends,
    required this.rates,
    this.badgeLabel = '实时汇总',
  });

  final TrafficStructureMode mode;
  final String title;
  final int total;

  /// 环形图的段，顺序与 [legends] 一致；值为 0 的段已在调用方过滤。
  final List<DonutSegment> segments;
  final List<TrafficStructureLegend> legends;
  final List<TrafficStructureRate> rates;

  /// 标题右侧的胶囊文案：记录全部是「实时汇总」，重点模式也是「实时汇总」。
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardDensityScope.scaleOf(context);
    final compact = legends.length <= 3;
    return DashboardCard(
      semanticLabel: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.dataUsage,
            title: title,
            trailing: [DashboardChip(label: badgeLabel)],
          ),
          SizedBox(height: 14 * scale),
          Row(
            spacing: 20,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DashboardResultDonut(
                segments: segments,
                total: total,
                // 三段图例时环形图略小，右侧三行文字才不会比环还高。
                diameter: compact ? 108 : 128,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: compact ? 12 * scale : 8 * scale,
                  children: [
                    for (final legend in legends)
                      DashboardLegendRow(
                        label: legend.label,
                        value: legend.value,
                        color: legend.color,
                      ),
                  ],
                ),
              ),
            ],
          ),
          for (final rate in rates) ...[
            SizedBox(height: 14 * scale),
            DashboardRateRow(
              label: rate.label,
              value: rate.value,
              progress: rate.progress,
            ),
          ],
          SizedBox(height: 2 * scale),
        ],
      ),
    );
  }
}

/// 从真实聚合快照取数的流量结构卡。
///
/// 图例顺序与比率行逐字照抄旧版：
/// - `all`：通过 / 过滤 / 失败 / 旁路 / 缓存，比率是 竞速成功率 / Bootstrap
///   成功率 / 拦截率 / 缓存率；
/// - `filtered`：过滤 / 失败 / 旁路，比率是 竞速成功率 / Bootstrap 成功率 /
///   **拦截占比**（旧版在过滤模式里把「拦截率」改名成「拦截占比」，不是笔误，
///   因为那一档的分母只剩重点记录）。
///
/// 数字来自 `logDashboardProvider`（今日窗口的真实表聚合）。快照未就绪时整卡
/// 显示空环与破折号，而不是先画一组 0：0% 的环形图会被读成「今天没有流量」。
class LogTrafficStructureCard extends ConsumerWidget {
  const LogTrafficStructureCard({super.key, required this.mode});

  final TrafficStructureMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(logDashboardProvider).value;
    final breakdown = snapshot?.breakdown ?? const LogTrafficBreakdown.empty();
    final colorScheme = context.colorScheme;
    final filtered = mode == TrafficStructureMode.filtered;
    final race = snapshot?.race ?? const LogRaceSummary.empty();
    final bootstrap = snapshot?.bootstrap ?? const LogBootstrapSummary.empty();
    final ready = snapshot != null;
    return TrafficStructureCard(
      mode: mode,
      title: filtered ? '重点流量结构' : '今日流量结构',
      total: filtered
          ? (snapshot?.highlightedTotal ?? 0)
          : breakdown.total,
      segments: filtered
          ? [
              if (breakdown.blocked > 0)
                (value: breakdown.blocked, color: colorScheme.error),
              if (breakdown.error > 0)
                (
                  value: breakdown.error,
                  color: colorScheme.error.withValues(alpha: 0.7),
                ),
              if (breakdown.bypassed > 0)
                (value: breakdown.bypassed, color: colorScheme.secondary),
            ]
          : [
              if (breakdown.passed > 0)
                (value: breakdown.passed, color: colorScheme.primary),
              if (breakdown.blocked > 0)
                (value: breakdown.blocked, color: colorScheme.error),
              if (breakdown.error > 0)
                (
                  value: breakdown.error,
                  color: colorScheme.error.withValues(alpha: 0.7),
                ),
              if (breakdown.bypassed > 0)
                (value: breakdown.bypassed, color: colorScheme.secondary),
              if (breakdown.cached > 0)
                (value: breakdown.cached, color: colorScheme.tertiary),
            ],
      legends: filtered
          ? [
              TrafficStructureLegend(
                label: '过滤',
                value: dashboardCount(breakdown.blocked),
                color: colorScheme.error,
              ),
              TrafficStructureLegend(
                label: '失败',
                value: dashboardCount(breakdown.error),
                color: colorScheme.error.withValues(alpha: 0.7),
              ),
              TrafficStructureLegend(
                label: '旁路',
                value: dashboardCount(breakdown.bypassed),
                color: colorScheme.secondary,
              ),
            ]
          : [
              TrafficStructureLegend(
                label: '通过',
                value: dashboardCount(breakdown.passed),
                color: colorScheme.primary,
              ),
              TrafficStructureLegend(
                label: '过滤',
                value: dashboardCount(breakdown.blocked),
                color: colorScheme.error,
              ),
              TrafficStructureLegend(
                label: '失败',
                value: dashboardCount(breakdown.error),
                color: colorScheme.error.withValues(alpha: 0.7),
              ),
              TrafficStructureLegend(
                label: '旁路',
                value: dashboardCount(breakdown.bypassed),
                color: colorScheme.secondary,
              ),
              TrafficStructureLegend(
                label: '缓存',
                value: dashboardCount(breakdown.cached),
                color: colorScheme.tertiary,
              ),
            ],
      rates: [
        TrafficStructureRate(
          label: '竞速成功率',
          value: ready
              ? '${dashboardPercent(race.successRate)} · '
                    '${dashboardCount(race.requests)} 次 · '
                    '${dashboardLatency(race.averageElapsedMs)}'
              : '—',
          progress: race.successRate,
        ),
        TrafficStructureRate(
          label: 'Bootstrap 成功率',
          value: ready
              ? '${dashboardPercent(bootstrap.successRate)} · '
                    '${dashboardCount(bootstrap.attempts)} 次 · '
                    '${dashboardLatency(bootstrap.averageElapsedMs)}'
              : '—',
          progress: bootstrap.successRate,
        ),
        TrafficStructureRate(
          label: filtered ? '拦截占比' : '拦截率',
          value: ready
              ? '${dashboardPercent(breakdown.blockRate)} · '
                    '${dashboardCount(breakdown.blocked)} 次'
              : '—',
          progress: breakdown.blockRate,
        ),
        if (!filtered)
          TrafficStructureRate(
            label: '缓存率',
            value: ready
                ? '${dashboardPercent(breakdown.cacheRate)} · '
                      '${dashboardCount(breakdown.cached)} 次'
                : '—',
            progress: breakdown.cacheRate,
          ),
      ],
    );
  }
}

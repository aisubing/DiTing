import 'package:diting/data/mock_log_dashboard.dart';
import 'package:diting/pages/home/dashboard/cards/dashboard_block_parts.dart';
import 'package:diting/pages/home/dashboard/cards/traffic_monitor_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/state/log_dashboard_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 日志仪表盘的列表类卡片。
///
/// 五张卡（最近请求 / 缓存热点 / 竞速胜出 / Bootstrap DNS / 规则拦截）在旧版
/// 三种模式下**文案与副标题逐字相同**，只有出现与否和入口不同，因此共用这里的
/// 实现：首页与 `/logs` 三套组合都直接引用，不各写一份（`ModernLogDashboardModeViews.kt`
/// 里那五段重复代码正是重构前的样子）。
///
/// 每张卡右下角都不放动作：入口统一在标题行右侧的「详情」，与旧版
/// `PillLink(text = "详情")` 的位置一致，`DashboardIconButton` 是设计系统里
/// 现成的对应物。

/// 「今日请求 / 通过 / 过滤 / 缓存命中」四格（旧版两行 `MetricCard`）。
class RequestOverviewCard extends ConsumerWidget {
  const RequestOverviewCard({super.key, this.title = '请求概览', this.onDetail});

  final String title;
  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(logDashboardProvider).breakdown;
    final colorScheme = context.colorScheme;
    return DashboardMetricQuadCard(
      glyph: AppGlyphs.requests,
      title: title,
      onDetail: onDetail,
      cells: [
        (
          label: '今日请求',
          value: dashboardCount(stats.total),
          color: colorScheme.primary,
        ),
        (
          label: '通过',
          value: dashboardCount(stats.passed),
          color: colorScheme.primary,
        ),
        (
          label: '过滤',
          value: dashboardCount(stats.blocked),
          color: colorScheme.error,
        ),
        (
          label: '缓存命中',
          value: dashboardCount(stats.cached),
          color: colorScheme.tertiary,
        ),
      ],
    );
  }
}

/// 重点记录四格（旧版 `FilteredModeDashboard` 的两行 `MetricCard`）。
class FilteredHighlightCard extends ConsumerWidget {
  const FilteredHighlightCard({super.key, this.title = '重点记录', this.onDetail});

  final String title;
  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(logDashboardProvider).breakdown;
    final colorScheme = context.colorScheme;
    return DashboardMetricQuadCard(
      glyph: AppGlyphs.rules,
      title: title,
      onDetail: onDetail,
      cells: [
        (
          label: '重点记录',
          value: dashboardCount(stats.blocked + stats.error),
          color: colorScheme.primary,
        ),
        (
          label: '过滤拦截',
          value: dashboardCount(stats.blocked),
          color: colorScheme.error,
        ),
        (
          label: '异常失败',
          value: dashboardCount(stats.error),
          color: colorScheme.error,
        ),
        (
          label: '旁路直连',
          value: dashboardCount(stats.bypassed),
          color: colorScheme.secondary,
        ),
      ],
    );
  }
}

/// 关闭日志模式下的四格（旧版 `OffModeDashboard`）。
class OffModeMetricCard extends ConsumerWidget {
  const OffModeMetricCard({super.key, this.onDetail});

  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(logDashboardProvider).offMode;
    final colorScheme = context.colorScheme;
    return DashboardMetricQuadCard(
      glyph: AppGlyphs.eyeOff,
      title: '解析服务概况',
      onDetail: onDetail,
      cells: [
        (
          label: '有效缓存',
          value: dashboardCount(stats.cacheEntries),
          color: colorScheme.primary,
        ),
        (
          label: '累计缓存命中',
          value: dashboardCount(stats.cacheHits),
          color: colorScheme.tertiary,
        ),
        (
          label: '并发竞速请求',
          value: dashboardCount(stats.raceRequests),
          color: colorScheme.secondary,
        ),
        (
          label: 'Bootstrap 尝试',
          value: dashboardCount(stats.bootstrapAttempts),
          color: colorScheme.primary,
        ),
      ],
    );
  }
}

/// 最近请求（旧版 `最近请求` 卡）。
class RecentRequestsLogCard extends ConsumerWidget {
  const RecentRequestsLogCard({super.key, this.onDetail});

  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(logDashboardProvider).recentRequests;
    final colorScheme = context.colorScheme;
    return DashboardLogListCard(
      glyph: AppGlyphs.requests,
      title: '最近请求',
      emptyText: '暂无请求日志',
      onDetail: onDetail,
      rows: [
        for (final row in rows)
          DashboardLogRow(
            title: row.name,
            subtitle: '${row.time} · ${row.source} · ${row.meta}',
            tag: row.resultLabel,
            tagColor: _statusColor(colorScheme, row.status),
          ),
      ],
    );
  }
}

/// 最近拦截与错误（旧版 `最近拦截与错误` 卡）。
///
/// 与 [RecentRequestsLogCard] 共用行的形状，只是空态文案与标题不同——旧版也是
/// 同一段 `RequestLogRow` 循环，换成另一句 `EmptyText`。
class FilteredRecentLogCard extends ConsumerWidget {
  const FilteredRecentLogCard({super.key, this.onDetail});

  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(logDashboardProvider).recentRequests;
    final colorScheme = context.colorScheme;
    // 只保留拦截 / 失败 / 旁路：这就是「仅拦截与错误」模式会落库的那几条。
    final rows = [
      for (final row in all)
        if (row.status != LogRowStatus.passed &&
            row.status != LogRowStatus.cached)
          row,
    ];
    return DashboardLogListCard(
      glyph: AppGlyphs.block,
      title: '最近拦截与错误',
      emptyText: '暂无拦截或错误记录',
      onDetail: onDetail,
      rows: [
        for (final row in rows)
          DashboardLogRow(
            title: row.name,
            subtitle: '${row.time} · ${row.source} · ${row.meta}',
            tag: row.resultLabel,
            tagColor: _statusColor(colorScheme, row.status),
          ),
      ],
    );
  }
}

/// 缓存热点（旧版 `缓存热点` 卡）。
class CacheHotspotsCard extends ConsumerWidget {
  const CacheHotspotsCard({super.key, this.onDetail});

  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(logDashboardProvider).cacheHotspots;
    final colorScheme = context.colorScheme;
    return DashboardLogListCard(
      glyph: AppGlyphs.layers,
      title: '缓存热点',
      emptyText: '暂无有效缓存',
      onDetail: onDetail,
      rows: [
        for (final row in rows)
          DashboardLogRow(
            title: row.queryName,
            subtitle:
                '${row.queryType} · '
                '${dashboardDuration(row.remainingSeconds)} 后过期 · '
                '${dashboardCount(row.responseSize)} B',
            tag: '${dashboardCount(row.hitCount)} 次',
            tagColor: colorScheme.tertiary,
          ),
      ],
    );
  }
}

/// 竞速胜出（旧版 `竞速胜出` 卡）。
class RaceWinnersCard extends ConsumerWidget {
  const RaceWinnersCard({super.key, this.onDetail});

  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(logDashboardProvider).raceWinners;
    final colorScheme = context.colorScheme;
    return DashboardLogListCard(
      glyph: AppGlyphs.shuffle,
      title: '竞速胜出',
      emptyText: '暂无竞速数据',
      onDetail: onDetail,
      rows: [
        for (final row in rows)
          DashboardLogRow(
            title: row.name,
            subtitle: '平均胜出耗时 ${dashboardLatency(row.averageElapsedMs)}',
            tag: '${dashboardCount(row.wins)} 次',
            tagColor: colorScheme.secondary,
          ),
      ],
    );
  }
}

/// Bootstrap DNS（旧版 `Bootstrap DNS` 卡）。
class BootstrapDnsCard extends ConsumerWidget {
  const BootstrapDnsCard({super.key, this.onDetail});

  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(logDashboardProvider).bootstrapIps;
    final colorScheme = context.colorScheme;
    return DashboardLogListCard(
      glyph: AppGlyphs.dns,
      title: 'Bootstrap DNS',
      emptyText: '暂无 Bootstrap 数据',
      onDetail: onDetail,
      rows: [
        for (final row in rows)
          DashboardLogRow(
            title: row.name,
            subtitle:
                '${row.ip} · 成功 ${dashboardPercent(row.successRate)} · '
                '${dashboardLatency(row.averageElapsedMs)}',
            tag: '${dashboardCount(row.attempts)} 次',
            tagColor: colorScheme.primary,
          ),
      ],
    );
  }
}

/// 规则拦截（旧版 `规则拦截` 卡）。
class RuleBlocksCard extends ConsumerWidget {
  const RuleBlocksCard({super.key, this.onDetail});

  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(logDashboardProvider).subscriptionBlocks;
    final colorScheme = context.colorScheme;
    return DashboardLogListCard(
      glyph: AppGlyphs.rules,
      title: '规则拦截',
      emptyText: '暂无规则拦截数据',
      onDetail: onDetail,
      rows: [
        for (final row in rows)
          DashboardLogRow(
            title: row.name,
            subtitle:
                '${row.statusLabel} · 占全部请求 '
                '${dashboardPercent(row.rate)}',
            tag: '${dashboardCount(row.hits)} 次',
            tagColor: colorScheme.error,
          ),
      ],
    );
  }
}

/// 关闭日志模式的说明卡（旧版 `隐私模式保护中`）。
class PrivacyModeCard extends StatelessWidget {
  const PrivacyModeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = DashboardDensityScope.scaleOf(context);
    final colorScheme = context.colorScheme;
    return DashboardCard(
      semanticLabel: '隐私模式保护中',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.lock,
            title: '隐私模式保护中',
            trailing: [const DashboardChip(label: '日志已关闭')],
          ),
          SizedBox(height: 12 * scale),
          Text(
            '重新开启日志后，仪表盘将从新产生的请求开始统计。'
            '当前各类解析服务与缓存热点均正常工作。',
            style: AppTextStyle.subheadline
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 解析效能概况（旧版 `解析效能概况` 卡：两条比率行）。
class ResolutionPerfCard extends ConsumerWidget {
  const ResolutionPerfCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(logDashboardProvider);
    final scale = DashboardDensityScope.scaleOf(context);
    return DashboardCard(
      semanticLabel: '解析效能概况',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.speed,
            title: '解析效能概况',
            trailing: [const DashboardChip(label: '实时统计')],
          ),
          SizedBox(height: 14 * scale),
          DashboardRateRow(
            label: '竞速成功率',
            value:
                '${dashboardPercent(snapshot.race.successRate)} · '
                '${dashboardCount(snapshot.race.requests)} 次 · '
                '${dashboardLatency(snapshot.race.averageElapsedMs)}',
            progress: snapshot.race.successRate,
          ),
          SizedBox(height: 14 * scale),
          DashboardRateRow(
            label: 'Bootstrap 成功率',
            value:
                '${dashboardPercent(snapshot.bootstrap.successRate)} · '
                '${dashboardCount(snapshot.bootstrap.attempts)} 次 · '
                '${dashboardLatency(snapshot.bootstrap.averageElapsedMs)}',
            progress: snapshot.bootstrap.successRate,
          ),
          SizedBox(height: 2 * scale),
        ],
      ),
    );
  }
}

Color _statusColor(ColorScheme colorScheme, LogRowStatus status) =>
    switch (status) {
      LogRowStatus.passed || LogRowStatus.cached => colorScheme.primary,
      LogRowStatus.filtered || LogRowStatus.failed => colorScheme.error,
      LogRowStatus.bypassed => colorScheme.secondary,
    };

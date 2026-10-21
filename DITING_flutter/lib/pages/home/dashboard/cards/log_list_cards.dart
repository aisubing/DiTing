import 'package:diting/data/log_dashboard_models.dart';
import 'package:diting/pages/home/dashboard/cards/dashboard_block_parts.dart';
import 'package:diting/pages/home/dashboard/cards/traffic_monitor_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/state/log_dashboard_overview_providers.dart';
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
///
/// ## 数字的来源与「还没读到」的表示
/// 所有数字来自 [logDashboardProvider] 对旧库真实表的聚合（见
/// `state/log_dashboard_overview_providers.dart`）。快照是 `FutureProvider`，
/// 首次加载与读取失败时 `value` 为 null：
/// - 四格数字显示 `—`，而不是 `0`——`0` 会被读成「今天没有请求」，而那是另一
///   种事实；
/// - 列表卡显示各自的空态文案（`DashboardLogListCard` 自带）。
LogDashboardSnapshot? _snapshotOf(WidgetRef ref) =>
    ref.watch(logDashboardProvider).value;

/// 四格里的一格：快照未就绪时给破折号。
String _figure(int? value) => value == null ? '—' : dashboardCount(value);

/// 「今日请求 / 通过 / 过滤 / 缓存命中」四格（旧版两行 `MetricCard`）。
class RequestOverviewCard extends ConsumerWidget {
  const RequestOverviewCard({super.key, this.title = '请求概览', this.onDetail});

  final String title;
  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = _snapshotOf(ref)?.breakdown;
    final colorScheme = context.colorScheme;
    return DashboardMetricQuadCard(
      glyph: AppGlyphs.requests,
      title: title,
      onDetail: onDetail,
      cells: [
        (
          label: '今日请求',
          value: _figure(stats?.total),
          color: colorScheme.primary,
        ),
        (
          label: '通过',
          value: _figure(stats?.passed),
          color: colorScheme.primary,
        ),
        (
          label: '过滤',
          value: _figure(stats?.blocked),
          color: colorScheme.error,
        ),
        (
          label: '缓存命中',
          value: _figure(stats?.cached),
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
    final stats = _snapshotOf(ref)?.breakdown;
    final colorScheme = context.colorScheme;
    return DashboardMetricQuadCard(
      glyph: AppGlyphs.rules,
      title: title,
      onDetail: onDetail,
      cells: [
        (
          label: '重点记录',
          value: _figure(
            stats == null ? null : stats.blocked + stats.error,
          ),
          color: colorScheme.primary,
        ),
        (
          label: '过滤拦截',
          value: _figure(stats?.blocked),
          color: colorScheme.error,
        ),
        (
          label: '异常失败',
          value: _figure(stats?.error),
          color: colorScheme.error,
        ),
        (
          label: '旁路直连',
          value: _figure(stats?.bypassed),
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
    final stats = _snapshotOf(ref)?.offMode;
    final colorScheme = context.colorScheme;
    return DashboardMetricQuadCard(
      glyph: AppGlyphs.eyeOff,
      title: '解析服务概况',
      onDetail: onDetail,
      cells: [
        (
          label: '有效缓存',
          value: _figure(stats?.cacheEntries),
          color: colorScheme.primary,
        ),
        (
          label: '累计缓存命中',
          value: _figure(stats?.cacheHits),
          color: colorScheme.tertiary,
        ),
        (
          label: '并发竞速请求',
          value: _figure(stats?.raceRequests),
          color: colorScheme.secondary,
        ),
        (
          label: 'Bootstrap 尝试',
          value: _figure(stats?.bootstrapAttempts),
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
    final rows = _snapshotOf(ref)?.recentRequests ?? const [];
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
    final all = _snapshotOf(ref)?.recentRequests ?? const [];
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
    final rows = _snapshotOf(ref)?.cacheHotspots ?? const [];
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
    final rows = _snapshotOf(ref)?.raceWinners ?? const [];
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
    final rows = _snapshotOf(ref)?.bootstrapIps ?? const [];
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
    final rows = _snapshotOf(ref)?.subscriptionBlocks ?? const [];
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

/// 解析效能概况（旧版 `解析效能概况` 卡：四条比率行）。
///
/// 旧版这一卡只有竞速与 Bootstrap 两行；本仓补了 DNS 侧两行（平均延迟 /
/// 缓存命中率），因为它们来自**同一批** `dns_log` 当日行、同一次扫描，而
/// 「关闭日志」模式下正需要它们说明「不记明细但解析仍在跑」。
///
/// 平均延迟没有计时样本时显示 `—`（不是 `0 ms`）：后者会被读成「解析飞快」。
class ResolutionPerfCard extends ConsumerWidget {
  const ResolutionPerfCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = _snapshotOf(ref);
    final scale = DashboardDensityScope.scaleOf(context);
    final quality = snapshot?.quality;
    final latency = quality?.averageLatencyMs;
    return DashboardCard(
      semanticLabel: '解析效能概况',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.speed,
            title: '解析效能概况',
            trailing: [const DashboardChip(label: '今日统计')],
          ),
          SizedBox(height: 14 * scale),
          DashboardRateRow(
            label: '平均解析耗时',
            value: quality == null
                ? '—'
                : latency == null
                ? '— · 今日暂无计时样本'
                : '${dashboardLatency(latency)} · '
                      '${dashboardCount(quality.latencySamples)} 个样本',
            // 延迟不是比率，进度条按「越小越好」无法归一，因此给 0 让这一行
            // 只显示文字（组件在 progress 为 0 时不画条）。
            progress: 0,
          ),
          SizedBox(height: 14 * scale),
          DashboardRateRow(
            label: '缓存命中率',
            value: quality == null
                ? '—'
                : '${dashboardPercent(quality.cacheHitRate)} · '
                      '分母为通过 + 失败',
            progress: quality?.cacheHitRate ?? 0,
          ),
          SizedBox(height: 14 * scale),
          DashboardRateRow(
            label: '竞速成功率',
            value: snapshot == null
                ? '—'
                : '${dashboardPercent(snapshot.race.successRate)} · '
                      '${dashboardCount(snapshot.race.requests)} 次 · '
                      '${dashboardLatency(snapshot.race.averageElapsedMs)}',
            progress: snapshot?.race.successRate ?? 0,
          ),
          SizedBox(height: 14 * scale),
          DashboardRateRow(
            label: 'Bootstrap 成功率',
            value: snapshot == null
                ? '—'
                : '${dashboardPercent(snapshot.bootstrap.successRate)} · '
                      '${dashboardCount(snapshot.bootstrap.attempts)} 次 · '
                      '${dashboardLatency(snapshot.bootstrap.averageElapsedMs)}',
            progress: snapshot?.bootstrap.successRate ?? 0,
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

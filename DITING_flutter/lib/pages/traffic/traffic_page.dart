/// 流量统计：窗口概览 + 应用流量排行（读旧库 `app_traffic_daily`）。
///
/// 结构对齐上游 `ui/traffic/`（`docs/refactor/05-traffic-log-system.md` §2.3）：
/// `TrafficGaugeCard`（总仪表盘）→ 速率曲线 → `AppTrafficRankItem` 排行 →
/// `AppTrafficDetailDialog`（点行看归因）。
///
/// ## 哪些数字是真的
/// 排行与三格合计全部来自 `app_traffic_daily`：一包一天一行，窗口由顶部
/// 分段控件选择，`today` 走 `byDate`，其余走 `dateRange` / `allHistory`
/// （SQL 与 `AppTrafficDao` 逐字一致，见 `app_traffic_repository.dart`）。
///
/// ## 曲线为什么还留着，以及它标了什么
/// 1.4.3 的速率曲线是内核每秒回报的会话数据，本仓**没有**这个来源
/// （引擎 `getStats()` 是全局累计、不按应用拆分，也不给速率序列）。曲线本身
/// 对「有没有在跑」有直观价值，所以保留，但整块标注为「会话示意」，并且
/// 只画进程内自采样的**假波形**——不把它伪装成真实测速。
library;

import 'package:diting/data/db/app_traffic_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/pages/observability/observability_common.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/traffic_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'traffic_rows.dart';

/// 流量页。
class TrafficPage extends ConsumerWidget {
  const TrafficPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final asyncSnapshot = ref.watch(trafficSnapshotProvider);
    final window = ref.watch(trafficWindowProvider);
    final sort = ref.watch(trafficSortProvider);
    final search = ref.watch(trafficSearchProvider);

    return CommonScaffold(
      title: '流量统计',
      searchState: AppBarSearchState(
        onSearch: (value) =>
            ref.read(trafficSearchProvider.notifier).setQuery(value.trim()),
      ),
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.refresh,
          tooltip: '刷新',
          onPressed: () => ref.read(dnsLogRevisionProvider.notifier).bump(),
        ),
        IconButtonData(
          glyph: AppGlyphs.info,
          tooltip: '归因说明',
          onPressed: () => showSheet<void>(
            context: context,
            builder: (_) => const _AttributionSheet(),
          ),
        ),
      ],
      body: _body(context, ref, asyncSnapshot, window, sort, search, colorScheme),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<TrafficSnapshot> asyncSnapshot,
    TrafficWindow window,
    TrafficSort sort,
    String search,
    ColorScheme colorScheme,
  ) {
    if (!asyncSnapshot.hasValue && asyncSnapshot.hasError) {
      return ObsFailure(
        label: '无法读取流量记录',
        description: '${asyncSnapshot.error}',
        onRetry: () => ref.read(dnsLogRevisionProvider.notifier).bump(),
      );
    }
    if (!asyncSnapshot.hasValue) {
      return const ObservabilityLoading(label: '正在读取流量记录');
    }

    final snapshot = asyncSnapshot.requireValue;
    final ranking = _ranked(snapshot.rows, sort, search);

    return PageBody(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: CommonCard(
            child: StatStrip(
              stats: [
                StatItem(
                  label: '${window.label}下行',
                  value: obsFormatBytes(snapshot.rxBytes),
                  color: colorScheme.primary,
                ),
                StatItem(
                  label: '${window.label}上行',
                  value: obsFormatBytes(snapshot.txBytes),
                ),
                StatItem(
                  label: '应用数',
                  value: '${snapshot.rows.length}',
                  unit: '个',
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedControl<TrafficWindow>(
            segments: [
              for (final option in TrafficWindow.values)
                (option, option.label),
            ],
            value: window,
            onChanged: (option) =>
                ref.read(trafficWindowProvider.notifier).select(option),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: CommonCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Row(
                  children: [
                    GlyphIcon(
                      AppGlyphs.info,
                      size: 18,
                      color: colorScheme.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '会话曲线（示意）',
                        style: context.listTitleStyle,
                      ),
                    ),
                  ],
                ),
                Text(
                  '实时速率没有落库来源：引擎只报累计字节数，不提供按应用或按秒的'
                  '速率序列，因此这张曲线不反映真实网速。真实数字请看上面的'
                  '「${window.label}下行 / 上行」与下方排行。',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
                // 高度必须给死：LineChart 内部是 SizedBox.expand + CustomPaint，
                // 放进 ListView 后没有固有高度，不约束就会抛无界高度断言。
                SizedBox(
                  height: 96,
                  child: LineChart(
                    values: mockTrafficSamples,
                    revision: mockTrafficSamples.length,
                    capacity: mockTrafficSamples.length,
                    minScale: 600,
                    color: colorScheme.onSurfaceVariant,
                    baselineRatio: 0.78,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in TrafficSort.values)
                _SortChip(
                  label: option.label,
                  selected: option == sort,
                  onPressed: () =>
                      ref.read(trafficSortProvider.notifier).select(option),
                ),
            ],
          ),
        ),
        if (ranking.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: NullStatus(
              label: search.isEmpty ? '这个窗口还没有流量记录' : '没有匹配的应用',
              description: search.isEmpty
                  ? '流量按天由原生侧汇总落库；启动隧道并产生流量后，'
                        '这里会出现各应用的下行 / 上行字节数。'
                  : '没有应用名或包名包含「$search」。',
              illustration: NullStatusIllustration.data,
            ),
          )
        else
          generateSection(
            title: '应用流量排行',
            footer:
                '占比按${window.label}总字节数（下行 + 上行）计算；'
                '${_windowLabel(snapshot)}。点按一行查看该应用的上下行明细。',
            items: [
              for (final row in ranking)
                AppTrafficRow(
                  row: row,
                  total: snapshot.totalBytes,
                  sort: sort,
                  onTap: () => showSheet<void>(
                    context: context,
                    builder: (_) => _AppTrafficSheet(
                      row: row,
                      total: snapshot.totalBytes,
                      sort: sort,
                    ),
                  ),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            '共 ${ranking.length} 个应用产生流量 · 合计 '
            '${obsFormatBytes(snapshot.totalBytes)}',
            style: context.listCaptionStyle,
          ),
        ),
      ],
    );
  }

  static String _windowLabel(TrafficSnapshot snapshot) {
    if (snapshot.startDate.isEmpty) return '范围为全部历史记录';
    if (snapshot.startDate == snapshot.endDate) {
      return '统计日期 ${snapshot.startDate}';
    }
    return '统计范围 ${snapshot.startDate} 至 ${snapshot.endDate}';
  }
}

/// 排序 + 关键词过滤。
///
/// 过滤在 Dart 侧做（不走第二份 SQL）：行数等于「应用数 × 天数」，一个月的
/// 完整历史也就几百行，直接在内存里筛比再发一次查询快，也不会与排行 SQL
/// 的 `ORDER BY` 产生两套排序口径。
List<AppTrafficDaily> _ranked(
  List<AppTrafficDaily> rows,
  TrafficSort sort,
  String search,
) {
  final query = search.toLowerCase();
  final filtered = query.isEmpty
      ? [...rows]
      : [
          for (final row in rows)
            if (row.appName.toLowerCase().contains(query) ||
                row.packageName.toLowerCase().contains(query))
              row,
        ];
  filtered.sort((a, b) {
    final result = switch (sort) {
      TrafficSort.total => a.totalBytes.compareTo(b.totalBytes),
      TrafficSort.download => a.rxBytes.compareTo(b.rxBytes),
      TrafficSort.upload => a.txBytes.compareTo(b.txBytes),
    };
    // 倒序：SQL 也是 DESC，正序会让「第 1 个应用」变成用得最少的那个。
    return -result;
  });
  return filtered;
}

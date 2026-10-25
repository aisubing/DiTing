/// Traffic stats: time window plus per-app ranking, read from `app_traffic_daily`.
library;

import 'package:diting/data/db/app_traffic_repository.dart';
import 'package:diting/pages/observability/observability_common.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/traffic_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/app_icon_avatar.dart';
import 'package:diting/widgets/app_list_view.dart';
import 'package:diting/widgets/chip_row.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'traffic_filters.dart';
part 'traffic_rows.dart';

class TrafficPage extends ConsumerStatefulWidget {
  const TrafficPage({super.key});

  @override
  ConsumerState<TrafficPage> createState() => _TrafficPageState();
}

class _TrafficPageState extends ConsumerState<TrafficPage> {
  final _search = TextEditingController();

  /// Grab the notifier on entry: dispose() cannot call ref.read.
  SpeedSeriesNotifier? _speed;

  @override
  void initState() {
    super.initState();
    // Shares the same rate series as the home page; the provider ref-counts it.
    _speed = ref.read(speedSeriesProvider.notifier);
    _speed!.attachPolling();
  }

  @override
  void dispose() {
    _speed?.detachPolling();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncSnapshot = ref.watch(trafficSnapshotProvider);
    final window = ref.watch(trafficWindowProvider);
    final sort = ref.watch(trafficSortProvider);
    final search = ref.watch(trafficSearchProvider);
    final hideSystemApps = ref.watch(trafficHideSystemAppsProvider);

    return CommonScaffold(
      title: '流量统计',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.broom,
          tooltip: '清除历史',
          onPressed: () => _confirmClear(context),
        ),
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
      body: _body(context, asyncSnapshot, window, sort, search, hideSystemApps),
    );
  }

  Widget _body(
    BuildContext context,
    AsyncValue<TrafficSnapshot> asyncSnapshot,
    TrafficWindow window,
    TrafficSort sort,
    String search,
    bool hideSystemApps,
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
    final visible = _ranked(
      snapshot.rows,
      sort,
      search,
      hideSystemApps: hideSystemApps,
    );
    final hiddenCount =
        snapshot.rows.length - _ranked(snapshot.rows, sort, search).length;

    return AppListScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: StatStrip(
                  stats: [
                    StatItem(
                      label: '${window.label}下行',
                      value: obsFormatBytes(snapshot.rxBytes),
                      color: context.colorScheme.primary,
                    ),
                    StatItem(
                      label: '${window.label}上行',
                      value: obsFormatBytes(snapshot.txBytes),
                    ),
                    StatItem(
                      label: '应用数',
                      value: '${visible.length}',
                      unit: '个',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                // Range chips go through ChipRow: a bare Wrap gives no cross-axis constraint
                // and wraps, pushing every card below it down.
                child: ChipRow(
                  children: [
                    for (final option in _rangeOptions)
                      FilterPill(
                        label: option.label,
                        selected: option.window == window,
                        disabled: option.unavailableReason != null,
                        onPressed: () {
                          final target = option.window;
                          if (target == null) {
                            _explainUnavailable(
                              option.label,
                              option.unavailableReason,
                            );
                          } else {
                            ref
                                .read(trafficWindowProvider.notifier)
                                .select(target);
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _LiveRateCard(windowLabel: window.label),
              const SizedBox(height: 10),
              _AttributionBanner(
                onTap: () => showSheet<void>(
                  context: context,
                  builder: (_) => const _AttributionSheet(),
                ),
              ),
              const SizedBox(height: 12),
              _TrafficFilterBar(
                searchController: _search,
                sort: sort,
                hideSystemApps: hideSystemApps,
                onSearchChanged: (value) => ref
                    .read(trafficSearchProvider.notifier)
                    .setQuery(value.trim()),
                onSortSelected: (option) {
                  final target = option.sort;
                  if (target == null) {
                    _explainUnavailable(option.label, option.unavailableReason);
                  } else {
                    ref.read(trafficSortProvider.notifier).select(target);
                  }
                },
                onHideSystemAppsChanged: (value) => ref
                    .read(trafficHideSystemAppsProvider.notifier)
                    .setValue(value),
              ),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: NullStatus(
                    label: search.isEmpty && !hideSystemApps
                        ? '暂无流量数据'
                        : '没有匹配的应用',
                    description: _emptyDescription(
                      search: search,
                      hideSystemApps: hideSystemApps,
                      hiddenCount: hiddenCount,
                      window: window,
                    ),
                    illustration: NullStatusIllustration.data,
                  ),
                ),
            ],
          ),
        ),
        if (visible.isNotEmpty)
          ...appListSlivers(
            title: '应用流量排行',
            itemCount: visible.length,
            footer:
                '占比按${window.label}总字节数（下行 + 上行）计算；'
                '${_windowLabel(snapshot)}。点按一行查看该应用的上下行明细。',
            itemBuilder: (context, index) {
              final row = visible[index];
              return AppTrafficRow(
                row: row,
                total: snapshot.totalBytes,
                sort: sort,
                onTap: () => showSheet<void>(
                  context: context,
                  builder: (_) => _AppTrafficDetailSheet(
                    row: row,
                    total: snapshot.totalBytes,
                    sort: sort,
                  ),
                ),
              );
            },
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              '共 ${visible.length} 个应用产生流量 · 合计 '
              '${obsFormatBytes(snapshot.totalBytes)}',
              style: context.listCaptionStyle,
            ),
          ),
        ),
      ],
    );
  }

  /// Empty-state text, distinguishing no data from filtered-out and hidden-system.
  static String _emptyDescription({
    required String search,
    required bool hideSystemApps,
    required int hiddenCount,
    required TrafficWindow window,
  }) {
    if (search.isNotEmpty) return '没有应用名或包名包含「$search」。';
    if (hideSystemApps && hiddenCount > 0) {
      return '本次共有 $hiddenCount 个应用被「隐藏系统应用」过滤掉，'
          '关闭该开关即可看到。';
    }
    if (window == TrafficWindow.all) {
      return '流量按天由原生侧汇总落库；启动隧道并产生流量后，这里会出现'
          '各应用的下行 / 上行字节数。';
    }
    return '「${window.label}」还没有流量记录。流量按天由原生侧汇总落库，'
        '换个时间窗口或启动隧道产生流量后再看。';
  }

  /// Disabled option explanation. A hint bar rather than silence: a tap must answer.
  void _explainUnavailable(String label, String? reason) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('「$label」不可用：${reason ?? '本仓没有对应的数据来源'}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Clear history: the confirmation wording is copied verbatim from upstream. The async
  /// guard uses the passed context.mounted, which pairs with the context the analyzer sees.
  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '清除全部流量记录？',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => popFloatingDialog(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => popFloatingDialog(context, true),
            child: const Text('确认清除'),
          ),
        ],
        child: const Text('此操作将清空所有已持久化的应用历史流量统计，清除后无法恢复。'),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final deleted = await ref
          .read(trafficClearHistoryProvider.notifier)
          .clear();
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('已清除 $deleted 条流量记录'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('清除失败：$error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static String _windowLabel(TrafficSnapshot snapshot) {
    if (snapshot.startDate.isEmpty) return '范围为全部历史记录';
    if (snapshot.startDate == snapshot.endDate) {
      return '统计日期 ${snapshot.startDate}';
    }
    return '统计范围 ${snapshot.startDate} 至 ${snapshot.endDate}';
  }
}

/// Sort, keyword filter and system-app hiding, all in Dart rather than a second SQL pass: a
/// month of history is a few hundred rows, and one sort definition avoids disagreeing with
/// the ranking query's ORDER BY.
List<AppTrafficDaily> _ranked(
  List<AppTrafficDaily> rows,
  TrafficSort sort,
  String search, {
  bool hideSystemApps = false,
}) {
  final query = search.toLowerCase();
  final filtered = <AppTrafficDaily>[
    for (final row in rows)
      if (!(hideSystemApps && isKnownSystemPackagePrefix(row.packageName)) &&
          (query.isEmpty ||
              row.appName.toLowerCase().contains(query) ||
              row.packageName.toLowerCase().contains(query)))
        row,
  ];
  filtered.sort((a, b) {
    final result = switch (sort) {
      TrafficSort.total => a.totalBytes.compareTo(b.totalBytes),
      TrafficSort.download => a.rxBytes.compareTo(b.rxBytes),
      TrafficSort.upload => a.txBytes.compareTo(b.txBytes),
    };
    // Descending, matching the SQL: ascending would put the least-used app first.
    return -result;
  });
  return filtered;
}
/// 流量统计：时间窗口 + 应用流量排行（读旧库 `app_traffic_daily`）。
///
/// 结构对齐 1.4.3 `normal/ui/AppTrafficStatsScreen.kt`：
/// 时间窗口切换 → 概览数字 → 实时速率位 → 归因说明入口 → 筛选条
/// （搜索 / 排序 / 隐藏系统应用）→ `AppTrafficRankItem` 排行 →
/// `AppTrafficDetailDialog`（点行看归因）→ 空态「暂无流量数据」。
///
/// ## 哪些数字是真的
/// 排行与三格合计全部来自 `app_traffic_daily`：一包一天一行，窗口由顶部
/// 档位选择，`today` 走 `byDate`，其余走 `dateRange` / `allHistory`
/// （SQL 与 `AppTrafficDao` 逐字一致，见 `app_traffic_repository.dart`）。
/// 搜索、排序、隐藏系统应用都在 Dart 侧过滤，见 `_ranked`。
///
/// ## 两档没有数据源，做成禁用项而不是删掉
/// 旧版 `TrafficTimeRange` 有「本次会话」档、`TrafficSortMode` 有「按实时速率」
/// 档，两者都需要内核按会话回报累计值 / 按秒回报速率序列；本仓的按天表只存
/// 「日期 + 包名 + 上下行累计字节」，没有这两列。旧版这里还有一张
/// `TrafficGaugeCard` 实时速率卡——本仓的原生侧**有** `TrafficRateMonitor`，
/// 因此那一格换成了真实读数（见 `_LiveRateCard`），只有极速模式如实说明缺失。
library;

import 'package:diting/data/db/app_traffic_repository.dart';
import 'package:diting/pages/observability/observability_common.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/traffic_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/chip_row.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'traffic_filters.dart';
part 'traffic_rows.dart';

/// 流量页。
class TrafficPage extends ConsumerStatefulWidget {
  const TrafficPage({super.key});

  @override
  ConsumerState<TrafficPage> createState() => _TrafficPageState();
}

class _TrafficPageState extends ConsumerState<TrafficPage> {
  final _search = TextEditingController();

  /// 进页面时抓住 notifier 引用：`dispose()` 里不能再 `ref.read`。
  SpeedSeriesNotifier? _speed;

  @override
  void initState() {
    super.initState();
    // 这一页也显示实时速率，与首页共用同一条序列（引用计数在 provider 里）。
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

    return PageBody(
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
              StatItem(label: '应用数', value: '${visible.length}', unit: '个'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          // 档位行统一走 [ChipRow]：`Wrap` 不给交叉轴约束，`TonalChip` 会停在
          // 18dp 的文本行高上；放不下时还会换行，把下面的卡片整列推低。
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
                      ref.read(trafficWindowProvider.notifier).select(target);
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
          onSearchChanged: (value) =>
              ref.read(trafficSearchProvider.notifier).setQuery(value.trim()),
          onSortSelected: (option) {
            final target = option.sort;
            if (target == null) {
              _explainUnavailable(option.label, option.unavailableReason);
            } else {
              ref.read(trafficSortProvider.notifier).select(target);
            }
          },
          onHideSystemAppsChanged: (value) =>
              ref.read(trafficHideSystemAppsProvider.notifier).setValue(value),
        ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: NullStatus(
              label: search.isEmpty && !hideSystemApps ? '暂无流量数据' : '没有匹配的应用',
              description: _emptyDescription(
                search: search,
                hideSystemApps: hideSystemApps,
                hiddenCount: hiddenCount,
                window: window,
              ),
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
              for (final row in visible)
                AppTrafficRow(
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
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            '共 ${visible.length} 个应用产生流量 · 合计 '
            '${obsFormatBytes(snapshot.totalBytes)}',
            style: context.listCaptionStyle,
          ),
        ),
      ],
    );
  }

  /// 空态说明：区分「真的没有流量」「被搜索过滤掉」「被隐藏系统应用过滤掉」。
  /// 三者混成一句会让用户以为统计坏了。
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

  /// 禁用档位的说明。用提示条而不是静默无反应：用户点了一定要得到答案。
  void _explainUnavailable(String label, String? reason) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('「$label」不可用：${reason ?? '本仓没有对应的数据来源'}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 清除历史：确认框文案逐字照抄旧版
  /// （`AppTrafficStatsScreen` 的 `showClearConfirmDialog`）。
  ///
  /// 用传入的 `context.mounted` 而不是 `State.mounted` 做异步守卫：两者在这里
  /// 恰好指向同一个 element，但 analyzer 需要与「用哪个 context」配对的那个判断。
  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '清除全部流量记录？',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
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

/// 排序 + 关键词过滤 + 隐藏系统应用。
///
/// 全部在 Dart 侧做（不走第二份 SQL）：行数等于「应用数 × 天数」，一个月的
/// 完整历史也就几百行，直接在内存里筛比再发一次查询快，也不会与排行 SQL
/// 的 `ORDER BY` 产生两套排序口径。
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
    // 倒序：SQL 也是 DESC，正序会让「第 1 个应用」变成用得最少的那个。
    return -result;
  });
  return filtered;
}

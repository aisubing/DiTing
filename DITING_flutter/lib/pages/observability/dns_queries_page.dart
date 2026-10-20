/// DNS 查询列表（上游 `views/dns_queries.dart`）。
///
/// 数据来自旧库 `dns_log`。筛选复刻 1.4.3 `RequestLogRepository` 的 DNS 分支
/// （六档状态 + 关键词），SQL 原文抄在 `dns_query_repository.dart`，不在这里
/// 二次过滤——否则「概览卡的数字」与「列表条数」会各算一套。
///
/// 上游是横向表格（时间 / 域名 / 类型 / 发起者 / 结果 / 来源 / 耗时），宽屏
/// 直接铺 7 列。本仓移动端优先：一行改为「域名 + 类型 / 时间 + 结果 + 耗时」，
/// 来源与 TTL 放进详情——表格列在 390 dp 上必然要截断域名，而域名是最需要
/// 完整读的信息。
///
/// 关键词 chip 由真实数据的 `packageName` 与状态档位现取，不写死一份会走样的
/// 清单；选中 chip 走同一份 SQL（`LIKE`），所以 chip 上的条数与列表一致。
library;

import 'dart:async';

import 'package:diting/data/db/dns_query_repository.dart';
import 'package:diting/data/db/http_request_repository.dart'
    show RequestStatus;
// 只用到 `mockObservedIpQuality`：IP 质量浮层仍是演示数据（没有移植第三方
// 检测接口），其余观测 mock 本页已全部停用。
import 'package:diting/data/mock_observability.dart' show mockObservedIpQuality;
import 'package:diting/pages/observability/observability_common.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/observability_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'dns_queries_rows.dart';
part 'dns_query_detail.dart';

/// DNS 查询页。
class DnsQueriesPage extends ConsumerStatefulWidget {
  const DnsQueriesPage({super.key});

  @override
  ConsumerState<DnsQueriesPage> createState() => _DnsQueriesPageState();
}

class _DnsQueriesPageState extends ConsumerState<DnsQueriesPage> {
  static const _searchDebounce = Duration(milliseconds: 250);

  Timer? _searchTimer;

  /// 只看失败查询。与状态档位是交集，在 Dart 侧过滤（不进 SQL）：这里过滤的
  /// 是「已按状态取回的行」，再拼一个 `result = 'ERROR'` 会与 `bypassed` 档位
  /// 的 `queryType = 0` 条件互斥，两个条件一起加就永远是空集。
  var _onlyFailures = false;

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      ref.read(dnsQueryTextProvider.notifier).setQuery(value.toLowerCase());
    });
  }

  void _refresh() => ref.read(dnsLogRevisionProvider.notifier).bump();

  void _resetFilters() {
    _searchTimer?.cancel();
    ref.read(dnsQueryTextProvider.notifier).clear();
    ref.read(dnsQueryStatusProvider.notifier).select(RequestStatus.all);
    setState(() => _onlyFailures = false);
  }

  void _toggleFailures() => setState(() => _onlyFailures = !_onlyFailures);

  void _openDetail(DnsLogRow query) {
    showSheet<void>(
      context: context,
      builder: (_) => DnsQueryDetailSheet(query: query),
    );
  }

  void _openIpQuality() {
    showFloatingDialog<void>(context: context, child: const IpQualityOverlay());
  }

  @override
  Widget build(BuildContext context) {
    final asyncRows = ref.watch(dnsQueriesProvider);
    final window = ref.watch(dnsQueryWindowProvider);
    final status = ref.watch(dnsQueryStatusProvider);

    final List<DnsLogRow> visible;
    if (asyncRows.hasValue) {
      visible = _onlyFailures
          ? [
              for (final row in asyncRows.requireValue)
                if (row.status == RequestStatus.error) row,
            ]
          : asyncRows.requireValue;
    } else {
      visible = const [];
    }

    return CommonScaffold(
      title: 'DNS 查询',
      searchState: AppBarSearchState(onSearch: _onSearch),
      menuItems: [
        CommonPopupMenuItem(
          label: '状态筛选',
          glyph: AppGlyphs.filter,
          subItems: [
            for (final option in RequestStatus.values)
              CommonPopupMenuItem(
                label: option.label,
                checked: option == status,
                onPressed: () =>
                    ref.read(dnsQueryStatusProvider.notifier).select(option),
              ),
          ],
        ),
        CommonPopupMenuItem(
          label: _onlyFailures ? '显示全部查询' : '只看失败查询',
          glyph: _onlyFailures ? AppGlyphs.listAdd : AppGlyphs.warning,
          onPressed: _toggleFailures,
        ),
        CommonPopupMenuItem(
          label: '刷新',
          glyph: AppGlyphs.refresh,
          onPressed: _refresh,
        ),
        CommonPopupMenuItem(
          label: 'IP 质量检测',
          glyph: AppGlyphs.locate,
          onPressed: _openIpQuality,
        ),
      ],
      body: _buildBody(asyncRows, window, visible, status),
    );
  }

  Widget _buildBody(
    AsyncValue<List<DnsLogRow>> asyncRows,
    AsyncValue<List<DnsLogRow>> window,
    List<DnsLogRow> visible,
    RequestStatus status,
  ) {
    if (!asyncRows.hasValue) {
      if (asyncRows.hasError) {
        return ObsFailure(
          label: '无法读取 DNS 记录',
          description: '${asyncRows.error}',
          onRetry: _refresh,
        );
      }
      return const ObservabilityLoading(label: '正在读取 DNS 记录');
    }

    // 概览与 chip 用「不受状态档位影响」的窗口取数：否则选了「过滤」档后，
    // 「查询总数」会缩成拦截数、关键词 chip 也会跟着消失，读起来像数据丢了。
    final windowRows = window.value ?? const <DnsLogRow>[];
    final failureCount = windowRows
        .where((row) => row.status == RequestStatus.error)
        .length;
    final cachedCount = windowRows.where((row) => row.cached).length;
    final searching = ref.read(dnsQueryTextProvider).isNotEmpty;
    final filtered =
        _onlyFailures || status != RequestStatus.all || searching;

    return NullStatusSwitcher(
      isEmpty: visible.isEmpty,
      isSearching: searching,
      nullStatus: obsEmpty(
        label: filtered ? '没有符合条件的查询' : '还没有 DNS 查询',
        description: filtered
            ? '当前筛选：${_filterSummary(status, searching)}。'
            : '应用解析域名后会在这里留下记录；需要先在日志设置里开启查询日志。',
        illustration: NullStatusIllustration.dns,
        action: FilledButton(
          onPressed: _resetFilters,
          child: const Text('重置筛选条件'),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.only(top: context.contentTopPadding, bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DnsSummaryCard(
              total: windowRows.length,
              failureCount: failureCount,
              cachedCount: cachedCount,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final packageName in _packageKeywords(windowRows))
                  DnsKeywordChip(
                    label: packageName,
                    selected: ref.read(dnsQueryTextProvider) == packageName,
                    onPressed: () => _togglePackageKeyword(packageName),
                  ),
                DnsKeywordChip(
                  label: '只看失败',
                  selected: _onlyFailures,
                  onPressed: _toggleFailures,
                ),
              ],
            ),
          ),
          generateSection(
            title: '查询记录',
            footer:
                '共 ${visible.length} 条'
                '${filtered ? '（已筛选：${_filterSummary(status, searching)}）' : ''}；'
                '点按一行查看查询链路与应答。概览卡按最近 '
                '${windowRows.length} 条统计，与当前筛选无关。',
            items: [
              for (final query in visible)
                DnsQueryRow(query: query, onTap: () => _openDetail(query)),
            ],
          ),
        ],
      ),
    );
  }

  /// 点一个包名 chip：再点一次取消，否则替换成该包名的关键词。
  ///
  /// 单选而不是多选，是因为关键词进的是同一条 `LIKE` SQL；多选就得拼
  /// `AND (...) OR (...)`，那已经超出「chip 过滤」的语义范围了。
  void _togglePackageKeyword(String packageName) {
    final current = ref.read(dnsQueryTextProvider);
    ref
        .read(dnsQueryTextProvider.notifier)
        .setQuery(current == packageName ? '' : packageName);
  }

  /// 筛选条件的可读摘要。顺序固定，避免同一组条件在不同分支里换顺序。
  static String _filterSummary(RequestStatus status, bool searching) => [
    status == RequestStatus.all ? '全部状态' : status.label,
    if (searching) '关键词',
  ].join(' · ');
}

/// DNS 查询列表（上游 `views/dns_queries.dart`）。
///
/// 上游是横向表格（时间 / 域名 / 类型 / 发起者 / 结果 / 来源 / 耗时），宽屏
/// 直接铺 7 列。本仓移动端优先：一行改为「域名 + 类型 / 时间 + 结果 + 耗时」，
/// 来源与 TTL 放进详情——表格列在 390 dp 上必然要截断域名，而域名是最需要
/// 完整读的信息。
///
/// 关键词 chip 过滤按上游的「发起者 / 结果」维度做，但用本仓的 `CommonChip`
/// 直接列出可选项，省掉一个「添加过滤词」的表单往返。
library;

import 'dart:async';

import 'package:diting/data/mock_observability.dart';
import 'package:diting/pages/observability/observability_common.dart';
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
  static const _loadDelay = Duration(milliseconds: 360);

  Timer? _loadTimer;
  var _loading = true;
  var _query = '';

  /// 选中关键词；空集表示不过滤。
  final _keywords = <String>{};

  /// 只看失败查询。与关键词取交集。
  var _onlyFailures = false;

  @override
  void initState() {
    super.initState();
    _loadTimer = Timer(_loadDelay, () {
      if (mounted) {
        setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  List<MockDnsQuery> _visible(List<MockDnsQuery> queries) {
    final query = _query.trim().toLowerCase();
    return [
      for (final item in queries)
        if ((!_onlyFailures || item.isFailure) &&
            (query.isEmpty ||
                item.domain.toLowerCase().contains(query) ||
                item.source.toLowerCase().contains(query) ||
                item.answers.any(
                  (answer) => answer.toLowerCase().contains(query),
                )) &&
            (_keywords.isEmpty ||
                _keywords.contains(item.source) ||
                (item.cached && _keywords.contains(DnsOutcome.cached.label))))
          item,
    ];
  }

  /// 可选的来源关键词，从数据里现取，避免写死一份会走样的列表。
  ///
  /// 「缓存」也是来源之一，但它不是上游：单独给它一个关键词，用户才能只看
  /// 命中缓存的查询。
  List<String> _sourceKeywords(List<MockDnsQuery> queries) {
    final sources = <String>{
      for (final query in queries)
        if (query.source != '缓存') query.source,
    };
    return sources.toList()..sort();
  }

  void _toggleKeyword(String keyword) {
    setState(() {
      if (!_keywords.remove(keyword)) {
        _keywords.add(keyword);
      }
    });
  }

  void _openDetail(MockDnsQuery query) {
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
    final queries = ref.watch(dnsQueriesProvider);
    final visible = _visible(queries);
    final failureCount = queries.where((query) => query.isFailure).length;

    return CommonScaffold(
      title: 'DNS 查询',
      searchState: AppBarSearchState(
        onSearch: (value) => setState(() => _query = value),
      ),
      menuItems: [
        CommonPopupMenuItem(
          label: _onlyFailures ? '显示全部查询' : '只看失败查询',
          glyph: _onlyFailures ? AppGlyphs.listAdd : AppGlyphs.warning,
          onPressed: () => setState(() => _onlyFailures = !_onlyFailures),
        ),
        CommonPopupMenuItem(
          label: 'IP 质量检测',
          glyph: AppGlyphs.locate,
          onPressed: _openIpQuality,
        ),
      ],
      body: _loading
          ? const ObservabilityLoading(label: '正在读取 DNS 记录')
          : NullStatusSwitcher(
              isEmpty: visible.isEmpty,
              // 同上：chip 筛选是页面行为，空态要说清是「筛掉了」而不是「搜不到」。
              isSearching: _query.trim().isNotEmpty,
              nullStatus: obsEmpty(
                label: _onlyFailures ? '没有失败查询' : '还没有 DNS 查询',
                description: _onlyFailures
                    ? '当前所有查询都成功返回了。'
                    : '应用解析域名后会在这里留下记录。',
                illustration: NullStatusIllustration.dns,
                action: FilledButton(
                  onPressed: () => setState(() {
                    _query = '';
                    _keywords.clear();
                    _onlyFailures = false;
                  }),
                  child: const Text('重置筛选条件'),
                ),
              ),
              child: ListView(
                padding: EdgeInsets.only(
                  top: context.contentTopPadding,
                  bottom: 16,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: DnsSummaryCard(
                      total: queries.length,
                      failureCount: failureCount,
                      cachedCount: queries
                          .where((query) => query.cached)
                          .length,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final keyword in _sourceKeywords(queries))
                          DnsKeywordChip(
                            label: keyword,
                            selected: _keywords.contains(keyword),
                            onPressed: () => _toggleKeyword(keyword),
                          ),
                        DnsKeywordChip(
                          label: '仅看缓存',
                          selected: _keywords.contains(DnsOutcome.cached.label),
                          onPressed: () =>
                              _toggleKeyword(DnsOutcome.cached.label),
                        ),
                        DnsKeywordChip(
                          label: '只看失败',
                          selected: _onlyFailures,
                          onPressed: () =>
                              setState(() => _onlyFailures = !_onlyFailures),
                        ),
                      ],
                    ),
                  ),
                  generateSection(
                    title: '查询记录',
                    footer:
                        '共 ${queries.length} 条，其中 $failureCount 条失败；'
                        '点按一行查看查询链路与应答。',
                    items: [
                      for (final query in visible)
                        DnsQueryRow(
                          query: query,
                          onTap: () => _openDetail(query),
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

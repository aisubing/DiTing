/// Request list (upstream `views/connection/requests.dart`): `http_request_log` + `dns_log`.
library;

import 'dart:async';

import 'package:diting/data/agent/agent_analysis_target.dart';
import 'package:diting/data/db/http_request_repository.dart';
import 'package:diting/pages/hub/agent_analysis_sheet.dart';
import 'package:diting/pages/observability/observability_common.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/observability_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'requests_rows.dart';

class RequestsPage extends ConsumerStatefulWidget {
  const RequestsPage({super.key});

  @override
  ConsumerState<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends ConsumerState<RequestsPage> {
  /// 250 ms search debounce, as upstream: every keystroke would otherwise issue a LIKE query.
  static const _searchDebounce = Duration(milliseconds: 250);

  Timer? _searchTimer;

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      ref.read(requestFeedQueryProvider.notifier).setQuery(value.trim());
    });
  }

  void _refresh() => ref.read(dnsLogRevisionProvider.notifier).bump();

  void _resetFilters() {
    ref.read(requestFeedQueryProvider.notifier).reset();
    _searchTimer?.cancel();
  }

  void _openDetail(ObservedRequest request) {
    showSheet<void>(
      context: context,
      builder: (_) => RequestDetailSheet(request: request),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncFeed = ref.watch(requestFeedProvider);
    final query = ref.watch(requestFeedQueryProvider);
    final filterLabel = [
      if (query.source != RequestSource.all) query.source.label,
      if (query.status != RequestStatus.all) query.status.label,
    ].join(' · ');

    return CommonScaffold(
      title: '请求',
      searchState: AppBarSearchState(onSearch: _onSearch),
      menuItems: [
        CommonPopupMenuItem(
          label: '来源',
          glyph: AppGlyphs.filter,
          subItems: [
            for (final source in RequestSource.values)
              CommonPopupMenuItem(
                label: source.label,
                checked: source == query.source,
                onPressed: () => ref
                    .read(requestFeedQueryProvider.notifier)
                    .setSource(source),
              ),
          ],
        ),
        CommonPopupMenuItem(
          label: '状态',
          glyph: AppGlyphs.status,
          subItems: [
            for (final status in RequestStatus.values)
              CommonPopupMenuItem(
                label: status.label,
                checked: status == query.status,
                onPressed: () => ref
                    .read(requestFeedQueryProvider.notifier)
                    .setStatus(status),
              ),
          ],
        ),
        CommonPopupMenuItem(
          label: '刷新',
          glyph: AppGlyphs.refresh,
          onPressed: _refresh,
        ),
        if (query.source != RequestSource.all ||
            query.status != RequestStatus.all)
          CommonPopupMenuItem(
            label: '清除筛选',
            glyph: AppGlyphs.reset,
            onPressed: _resetFilters,
          ),
      ],
      body: _buildBody(asyncFeed, filterLabel),
    );
  }

  Widget _buildBody(AsyncValue<RequestFeed> asyncFeed, String filterLabel) {
    // Check hasValue first: a refresh keeps the old value alongside isLoading, and
    // looking at isLoading alone would flash the loading state and lose scroll.
    if (asyncFeed.hasValue) return _body(asyncFeed.requireValue, filterLabel);
    if (asyncFeed.hasError) {
      return ObsFailure(
        label: '无法读取请求记录',
        description: '${asyncFeed.error}',
        onRetry: _refresh,
      );
    }
    return const ObservabilityLoading(label: '正在读取请求记录');
  }

  Widget _body(RequestFeed feed, String filterLabel) {
    final items = feed.items;
    final failed = items
        .where((request) => request.status == RequestStatus.error)
        .length;

    return NullStatusSwitcher(
      isEmpty: items.isEmpty,
      isSearching: ref.read(requestFeedQueryProvider).query.isNotEmpty,
      nullStatus: obsEmpty(
        label: filterLabel.isEmpty ? '还没有请求记录' : '没有符合条件的请求',
        description: filterLabel.isEmpty
            ? '应用发出请求后会在这里留下记录；HTTPS 记录需要开启流量检查。'
            : '当前筛选：$filterLabel。',
        illustration: NullStatusIllustration.requests,
        action: FilledButton(
          onPressed: _resetFilters,
          child: const Text('重置筛选条件'),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.only(top: context.contentTopPadding, bottom: 16),
        children: [
          generateSection(
            title: '请求记录',
            footer:
                '共 ${items.length} 条，其中 $failed 条处理失败'
                '${filterLabel.isEmpty ? '' : '（筛选：$filterLabel）'}'
                '${feed.hasMore ? '；已达单次读取上限，可细化筛选后查看' : ''}。'
                '点按一行查看规则命中与处理结果。',
            items: [
              for (final request in items)
                RequestRow(request: request, onTap: () => _openDetail(request)),
            ],
          ),
        ],
      ),
    );
  }
}
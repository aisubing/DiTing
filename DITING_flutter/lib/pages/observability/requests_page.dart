/// 请求列表（上游 `views/connection/requests.dart`）。
///
/// 上游是「时间正序 + 自动滚到底」的流水账；本仓没有核心轮询，列表不会自己
/// 长高，所以改成时间倒序（最新在上）——静态列表里倒序比正序更容易看到刚
/// 发生的事，也不用为了看见最新一条而先滚到底。
library;

import 'dart:async';

import 'package:diting/data/mock_observability.dart';
import 'package:diting/pages/observability/observability_common.dart';
import 'package:diting/state/observability_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'requests_rows.dart';

/// 请求页。
class RequestsPage extends ConsumerStatefulWidget {
  const RequestsPage({super.key});

  @override
  ConsumerState<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends ConsumerState<RequestsPage> {
  static const _loadDelay = Duration(milliseconds: 380);

  Timer? _loadTimer;
  var _loading = true;
  var _query = '';

  /// 只看失败与拦截：排查时通常先筛掉成功的那些。
  var _onlyProblems = false;

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

  List<MockRequest> _visible(List<MockRequest> requests) {
    final query = _query.trim().toLowerCase();
    return [
      for (final request in requests)
        if ((!_onlyProblems || request.outcome != RequestOutcome.success) &&
            (query.isEmpty ||
                request.host.toLowerCase().contains(query) ||
                request.client.toLowerCase().contains(query) ||
                request.rule.toLowerCase().contains(query) ||
                request.destinationIp.contains(query)))
          request,
    ];
  }

  void _openDetail(MockRequest request) {
    showSheet<void>(
      context: context,
      builder: (_) => RequestDetailSheet(request: request),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(requestsProvider);
    final visible = _visible(requests);
    final failed = requests
        .where((request) => request.outcome != RequestOutcome.success)
        .length;

    return CommonScaffold(
      title: '请求',
      searchState: AppBarSearchState(
        onSearch: (value) => setState(() => _query = value),
      ),
      menuItems: [
        CommonPopupMenuItem(
          label: _onlyProblems ? '显示全部请求' : '只看异常请求',
          glyph: _onlyProblems ? AppGlyphs.listAdd : AppGlyphs.filter,
          onPressed: () => setState(() => _onlyProblems = !_onlyProblems),
        ),
      ],
      body: _loading
          ? const ObservabilityLoading(label: '正在读取请求记录')
          : NullStatusSwitcher(
              isEmpty: visible.isEmpty,
              // 只把搜索框的关键词交给 `isSearching`（那会显示统一的「无搜索
              // 结果」）；「只看异常」是本页自己的筛选，空态文案要说出原因，
              // 所以走下面自定义的 `nullStatus`。
              isSearching: _query.trim().isNotEmpty,
              nullStatus: obsEmpty(
                label: _onlyProblems ? '没有异常请求' : '还没有请求记录',
                description: _onlyProblems ? '当前所有请求都成功了。' : '应用发出请求后会在这里留下记录。',
                illustration: NullStatusIllustration.requests,
                action: FilledButton(
                  onPressed: () => setState(() {
                    _query = '';
                    _onlyProblems = false;
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
                  generateSection(
                    title: '请求记录',
                    footer:
                        '共 ${requests.length} 条，其中 $failed 条异常；'
                        '点按一行查看规则命中与解析结果。',
                    items: [
                      for (final request in visible)
                        RequestRow(
                          request: request,
                          onTap: () => _openDetail(request),
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

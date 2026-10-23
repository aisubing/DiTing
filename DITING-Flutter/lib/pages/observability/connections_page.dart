/// Connection list (upstream `views/connection/connections.dart`).
library;

import 'dart:async';

import 'package:diting/data/mock_observability.dart';
import 'package:diting/pages/observability/observability_common.dart';
import 'package:diting/pages/system/demo_page_notice.dart';
import 'package:diting/state/observability_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'connections_rows.dart';

/// Sort field. Labels come from [label], never from the enum name.
enum ConnectionSort {
  duration('按持续时间'),
  download('按下载量'),
  upload('按上传量'),
  host('按域名');

  const ConnectionSort(this.label);

  final String label;
}

class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key});

  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage> {
  /// Simulated first-load delay, only so the skeleton-to-data transition is visible.
  static const _loadDelay = Duration(milliseconds: 420);

  Timer? _loadTimer;
  var _loading = true;
  var _query = '';
  var _sort = ConnectionSort.duration;
  var _descending = true;

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

  List<MockConnection> _visible(List<MockConnection> connections) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? [...connections]
        : [
            for (final connection in connections)
              if (connection.host.toLowerCase().contains(query) ||
                  connection.process.toLowerCase().contains(query) ||
                  connection.rulePayload.toLowerCase().contains(query) ||
                  connection.destinationIp.contains(query))
                connection,
          ];
    filtered.sort((a, b) {
      final result = switch (_sort) {
        ConnectionSort.duration => a.seconds.compareTo(b.seconds),
        ConnectionSort.download => a.download.compareTo(b.download),
        ConnectionSort.upload => a.upload.compareTo(b.upload),
        ConnectionSort.host => a.host.compareTo(b.host),
      };
      return _descending ? -result : result;
    });
    return filtered;
  }

  Future<void> _closeAll() async {
    final count = ref.read(connectionsProvider).length;
    if (count == 0) {
      showObsTip(context, '列表里还没有连接');
      return;
    }
    final confirmed = await showObsConfirm(
      context,
      title: '关闭全部连接',
      message: '将关闭当前 $count 条活动连接，正在传输的请求会被中断。',
      confirmLabel: '确认全部关闭',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final closed = ref.read(connectionsProvider.notifier).closeAll();
    showObsTip(context, '已关闭 $closed 条连接');
  }

  Future<void> _closeOne(MockConnection connection) async {
    final confirmed = await showObsConfirm(
      context,
      title: '确认关闭',
      message: '将关闭到「${connection.host}」的连接。',
      confirmLabel: '关闭',
      destructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    ref.read(connectionsProvider.notifier).close(connection.id);
    showObsTip(context, '已关闭 ${connection.host}');
  }

  void _openDetail(MockConnection connection) {
    showSheet<void>(
      context: context,
      builder: (_) => ConnectionDetailSheet(
        connectionId: connection.id,
        onClose: (id) => ref.read(connectionsProvider.notifier).close(id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connections = ref.watch(connectionsProvider);
    final visible = _visible(connections);
    final isSearching = _query.trim().isNotEmpty;
    final colorScheme = context.colorScheme;

    return CommonScaffold(
      title: '连接',
      searchState: AppBarSearchState(
        onSearch: (value) => setState(() => _query = value),
      ),
      menuItems: [
        CommonPopupMenuItem(
          label: '排序',
          glyph: AppGlyphs.sort,
          subItems: [
            for (final sort in ConnectionSort.values)
              CommonPopupMenuItem(
                label: sort.label,
                checked: sort == _sort,
                onPressed: () => setState(() => _sort = sort),
              ),
          ],
        ),
        CommonPopupMenuItem(
          label: _descending ? '改为升序' : '改为降序',
          glyph: _descending ? AppGlyphs.arrowDown : AppGlyphs.arrowUp,
          onPressed: () => setState(() => _descending = !_descending),
        ),
        CommonPopupMenuItem(
          label: '全部关闭',
          glyph: AppGlyphs.clearAll,
          danger: true,
          onPressed: connections.isEmpty ? null : _closeAll,
        ),
      ],
      body: _loading
          ? const ObservabilityLoading(label: '正在读取活动连接')
          : NullStatusSwitcher(
              isEmpty: visible.isEmpty,
              isSearching: isSearching,
              nullStatus: obsEmpty(
                label: '当前没有活动连接',
                description: '有流量经过时会在这里出现。',
                illustration: NullStatusIllustration.connections,
                action: FilledButton(
                  onPressed: () => setState(() {
                    _query = '';
                    _sort = ConnectionSort.duration;
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
                    child: CommonCard(
                      child: StatStrip(
                        stats: [
                          StatItem(
                            label: '活动连接',
                            value: '${connections.length}',
                            unit: '条',
                            color: colorScheme.primary,
                          ),
                          StatItem(
                            label: '下行合计',
                            value: obsFormatBytes(
                              connections.fold(
                                0,
                                (sum, item) => sum + item.download,
                              ),
                            ),
                          ),
                          StatItem(
                            label: '上行合计',
                            value: obsFormatBytes(
                              connections.fold(
                                0,
                                (sum, item) => sum + item.upload,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  generateSection(
                    title: '连接列表',
                    footer: '点按一行查看完整路由链路；右侧按钮直接关闭这一条连接。',
                    items: [
                      for (final connection in visible)
                        ConnectionRow(
                          connection: connection,
                          onTap: () => _openDetail(connection),
                          onClose: () => _closeOne(connection),
                        ),
                    ],
                  ),
                  const DemoPageNotice(),
                ],
              ),
            ),
    );
  }
}
import 'dart:async';

import 'package:diting/data/mock_profiles.dart';
import 'package:diting/pages/profiles/custom_proxy_form.dart';
import 'package:diting/pages/profiles/share_link_dialog.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'custom_proxies_rows.dart';

/// 搜索防抖：上游 `CustomProxiesView` 用 250ms，慢一点「边打边筛」就没意义，
/// 快一点每次按键都要重建整张列表。
const _searchDebounce = Duration(milliseconds: 250);

/// 自建节点列表（上游 `views/profiles/custom/custom_proxies.dart`，1581 行）。
///
/// 上游这一个文件里塞了：列表、卡片、分享链接对话框、编辑表单、表单里的
/// 30 多个字段、选项增删、批量编辑。这里按职责拆成四个文件：
/// - 本文件：列表、搜索、多选、批量编辑入口、排序；
/// - `custom_proxies_rows.dart`：卡片与延迟徽标；
/// - `custom_proxy_form.dart`：新增 / 编辑表单；
/// - `share_link_dialog.dart`：分享链接的解析与生成。
class CustomProxiesPage extends ConsumerStatefulWidget {
  const CustomProxiesPage({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<CustomProxiesPage> createState() => _CustomProxiesPageState();
}

class _CustomProxiesPageState extends ConsumerState<CustomProxiesPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) {
        return;
      }
      setState(() => _query = value.trim().toLowerCase());
    });
  }

  List<MockProxy> _visible(List<MockProxy> proxies) => [
    for (final proxy in proxies)
      if (_query.isEmpty ||
          proxy.name.toLowerCase().contains(_query) ||
          proxy.server.toLowerCase().contains(_query) ||
          proxy.protocol.label.toLowerCase().contains(_query) ||
          proxy.protocol.value.toLowerCase().contains(_query))
        proxy,
  ];

  Future<void> _delete(Set<String> ids) async {
    final localizations = UiLocalizations.of(context);
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除 ${ids.length} 个节点',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
        child: Text('引用这些节点的组会留下空成员，需要在组里重新选择。'),
      ),
    );
    if (confirmed ?? false) {
      ref.read(customProxiesProvider.notifier).remove(ids);
      ref.read(proxySelectionProvider.notifier).clear();
    }
  }

  Future<void> _batchEdit(Set<String> ids) async {
    final result = await showFormSheet<({int? port, ProxyProtocol? protocol})>(
      context: context,
      builder: (_) => _BatchEditSheet(count: ids.length),
    );
    if (result == null) {
      return;
    }
    final notifier = ref.read(customProxiesProvider.notifier);
    if (result.port case final port?) {
      notifier.setPort(ids, port);
    }
    if (result.protocol case final protocol?) {
      notifier.setProtocol(ids, protocol);
    }
    ref.read(proxySelectionProvider.notifier).clear();
  }

  Future<void> _shareLink(MockProxy proxy) async {
    await showShareLinkDialog(context: context, proxy: proxy);
  }

  void _openForm({MockProxy? proxy}) {
    showFormSheet<void>(
      context: context,
      builder: (_) =>
          CustomProxyFormSheet(profileId: widget.profileId, proxy: proxy),
    );
  }

  void _openParse() {
    showFormSheet<void>(
      context: context,
      builder: (_) => ShareLinkParseSheet(profileId: widget.profileId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proxies = ref.watch(customProxiesProvider);
    final selection = ref.watch(proxySelectionProvider);
    final visible = _visible(proxies);
    final colorScheme = context.colorScheme;
    final isSelecting = selection.isNotEmpty;
    final averageLatency = proxies.isEmpty
        ? 0
        : proxies.fold<int>(0, (sum, proxy) => sum + proxy.latencyMs) ~/
              proxies.length;
    return CommonScaffold(
      title: isSelecting ? '已选 ${selection.length} 项' : '节点',
      canSort: !isSelecting,
      searchState: AppBarSearchState(onSearch: _onSearchChanged),
      backAction: isSelecting
          ? ref.read(proxySelectionProvider.notifier).clear
          : null,
      selectionActions: [
        IconButtonData(
          glyph: AppGlyphs.selectAll,
          tooltip: '全选',
          onPressed: () => ref
              .read(proxySelectionProvider.notifier)
              .selectAll(visible.map((proxy) => proxy.id)),
        ),
        IconButtonData(
          glyph: AppGlyphs.edit,
          tooltip: '批量编辑',
          onPressed: () => _batchEdit(selection),
        ),
        IconButtonData(
          glyph: AppGlyphs.delete,
          tooltip: '删除所选',
          onPressed: () => _delete(selection),
        ),
      ],
      primaryAction: IconButtonData(
        glyph: AppGlyphs.addCircle,
        tooltip: '添加节点',
        onPressed: () => _openForm(),
      ),
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.link,
          tooltip: '从分享链接导入',
          onPressed: _openParse,
        ),
      ],
      body: Builder(
        builder: (context) {
          // 排序开关由 `CommonScaffold` 的 `canSort` 提供，它把 body 包在
          // `SortModeScope` 里；这里用 Builder 拿到该作用域下的 context。
          final sorting = SortModeScope.maybeOf(context)?.sorting ?? false;
          return NullStatusSwitcher(
            isEmpty: visible.isEmpty,
            isSearching: _query.isNotEmpty,
            nullStatus: NullStatus(
              label: _query.isEmpty ? '还没有自建节点' : '没有匹配的节点',
              description: _query.isEmpty ? '粘贴分享链接或手动填写一项' : null,
              illustration: _query.isEmpty
                  ? NullStatusIllustration.proxies
                  : NullStatusIllustration.search,
              action: _query.isEmpty
                  ? FilledButton(
                      onPressed: () => _openForm(),
                      child: const Text('添加节点'),
                    )
                  : null,
            ),
            child: PageBody(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: CommonCard(
                    child: StatStrip(
                      stats: [
                        StatItem(label: '节点', value: '${proxies.length}'),
                        StatItem(
                          label: '平均延迟',
                          value: '$averageLatency',
                          unit: 'ms',
                          color: _latencyColor(colorScheme, averageLatency),
                        ),
                        StatItem(
                          label: '启用 TLS',
                          value:
                              '${proxies.where((proxy) => proxy.tls).length}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (sorting)
                  _SortListView(
                    proxies: visible,
                    onReorder: ref.read(customProxiesProvider.notifier).reorder,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: [
                        for (final proxy in visible)
                          ProxyNodeCard(
                            proxy: proxy,
                            isSelected: selection.contains(proxy.id),
                            isSelecting: isSelecting,
                            onTap: () {
                              if (isSelecting) {
                                ref
                                    .read(proxySelectionProvider.notifier)
                                    .toggle(proxy.id);
                              } else {
                                _openForm(proxy: proxy);
                              }
                            },
                            onLongPress: () => ref
                                .read(proxySelectionProvider.notifier)
                                .toggle(proxy.id),
                            onShare: () => _shareLink(proxy),
                            onDelete: () => _delete({proxy.id}),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 排序模式下的节点行：只留名字与把手，拖拽手势就没有歧义。
class _SortListView extends StatelessWidget {
  const _SortListView({required this.proxies, required this.onReorder});

  final List<MockProxy> proxies;
  final void Function(int, int) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      onReorderItem: onReorder,
      itemCount: proxies.length,
      itemBuilder: (context, index) {
        final proxy = proxies[index];
        return Padding(
          key: ValueKey(proxy.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: ItemPositionProvider(
            position: ItemPosition.get(index, proxies.length),
            child: DecorationListItem(
              contentPadding: const EdgeInsets.only(left: 16),
              title: Text(
                proxy.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                proxy.endpoint,
                style: context.listCaptionStyle.copyWith(
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              trailing: SortHandle(index: index),
            ),
          ),
        );
      },
    );
  }
}

/// 批量编辑面板：只提供「端口」与「协议」两项。
///
/// 上游批量编辑能改所有字段，但演示里这两项最常用，且多选之后改别的字段
/// （密码、SNI）几乎总是错的——不同节点的凭据不该被一起盖掉。
class _BatchEditSheet extends StatefulWidget {
  const _BatchEditSheet({required this.count});

  final int count;

  @override
  State<_BatchEditSheet> createState() => _BatchEditSheetState();
}

class _BatchEditSheetState extends State<_BatchEditSheet> {
  final _port = TextEditingController();
  ProxyProtocol? _protocol;

  @override
  void dispose() {
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '批量编辑 ${widget.count} 个节点',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '应用',
        onPressed: () {
          final port = int.tryParse(_port.text.trim());
          if (port == null && _protocol == null) {
            Navigator.of(context).pop();
            return;
          }
          Navigator.of(context).pop((port: port, protocol: _protocol));
        },
      ),
      body: ListView(
        controller: sheetScrollController(context),
        padding: EdgeInsets.only(top: 8 + context.contentTopPadding),
        children: [
          generateSection(
            title: '要改的字段',
            items: [
              _BatchFieldRow(
                label: '端口',
                child: TextField(
                  controller: _port,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '留空则不修改，如 443'),
                ),
              ),
              ListItem<ProxyProtocol?>.options(
                title: const Text('协议'),
                options: [null, ...ProxyProtocol.values],
                value: _protocol,
                textBuilder: (protocol) => protocol?.label ?? '不修改',
                onChanged: (protocol) => setState(() => _protocol = protocol),
              ),
            ],
            footer: '留空的字段不会被改动。密码、SNI 这类每节点不同的字段不提供批量修改。',
          ),
          SizedBox(height: NavigationDock.insetOf(context)),
        ],
      ),
    );
  }
}

class _BatchFieldRow extends StatelessWidget {
  const _BatchFieldRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        spacing: 12,
        children: [
          SizedBox(
            width: 76,
            child: Text(label, style: context.listTitleStyle),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 延迟分档颜色：<100ms 主色、<200ms 三级色、其余错误色。
Color _latencyColor(ColorScheme colorScheme, int latencyMs) {
  if (latencyMs < 100) {
    return colorScheme.primary;
  }
  if (latencyMs < 200) {
    return colorScheme.tertiary;
  }
  return colorScheme.error;
}

/// 延迟徽标的公共入口，供卡片使用。
Color latencyColorOf(ColorScheme colorScheme, int latencyMs) =>
    _latencyColor(colorScheme, latencyMs);

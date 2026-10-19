import 'package:diting/data/mock_profiles.dart';
import 'package:diting/routes/profiles_routes.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

part 'proxy_groups_rows.dart';

/// 代理组列表（上游 `views/profiles/custom/groups.dart`，1404 行）。
///
/// 上游一个文件里有：组的列表、组卡片、编辑页、成员选择、筛选检查、复制、
/// 图标选择入口。这里拆成三个页面文件 + 一个 part：
/// - 本文件：列表、搜索、多选、复制、排序；
/// - `proxy_groups_rows.dart`：组卡片；
/// - `group_edit_page.dart`：组的编辑表单；
/// - `group_members_page.dart`：成员选择（候选列表 + 已选可拖拽区）。
class ProxyGroupsPage extends ConsumerStatefulWidget {
  const ProxyGroupsPage({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<ProxyGroupsPage> createState() => _ProxyGroupsPageState();
}

class _ProxyGroupsPageState extends ConsumerState<ProxyGroupsPage> {
  final _search = TextEditingController();
  var _query = '';
  final _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MockProxyGroup> _visible(List<MockProxyGroup> groups) => [
    for (final group in groups)
      if (_query.isEmpty ||
          group.name.toLowerCase().contains(_query) ||
          group.kind.label.contains(_query) ||
          group.members.any((member) => member.toLowerCase().contains(_query)))
        group,
  ];

  Future<void> _delete(Set<String> ids) async {
    final localizations = UiLocalizations.of(context);
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除 ${ids.length} 个代理组',
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
        child: const Text('把流量指向这些组的规则会失效，需要重新指定目标。'),
      ),
    );
    if (confirmed ?? false) {
      ref.read(proxyGroupsProvider.notifier).remove(ids);
      setState(_selected.clear);
    }
  }

  void _addGroup() {
    showFormSheet<void>(
      context: context,
      builder: (_) => _AddGroupSheet(
        onCreated: (group) =>
            context.push(ProfilesPaths.groupEditOf(widget.profileId, group.id)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(proxyGroupsProvider);
    final proxies = ref.watch(customProxiesProvider);
    final visible = _visible(groups);
    final selecting = _selected.isNotEmpty;
    final colorScheme = context.colorScheme;
    final emptyGroups = groups.where((group) => group.members.isEmpty).length;
    return CommonScaffold(
      title: selecting ? '已选 ${_selected.length} 项' : '代理组',
      searchState: AppBarSearchState(
        onSearch: (value) => setState(() => _query = value.trim()),
      ),
      backAction: selecting ? () => setState(_selected.clear) : null,
      selectionActions: [
        IconButtonData(
          glyph: AppGlyphs.addCircle,
          tooltip: '复制所选',
          onPressed: () {
            ref.read(proxyGroupsProvider.notifier).duplicate(_selected);
            setState(_selected.clear);
          },
        ),
        IconButtonData(
          glyph: AppGlyphs.delete,
          tooltip: '删除所选',
          onPressed: () => _delete(_selected),
        ),
      ],
      primaryAction: IconButtonData(
        glyph: AppGlyphs.addCircle,
        tooltip: '添加代理组',
        onPressed: _addGroup,
      ),
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.sort,
          tooltip: '按类型重排',
          onPressed: () {
            final sorted = [...groups]
              ..sort((a, b) => a.kind.index.compareTo(b.kind.index));
            ref.read(proxyGroupsProvider.notifier).replaceAll(sorted);
          },
        ),
      ],
      body: NullStatusSwitcher(
        isEmpty: visible.isEmpty,
        isSearching: _query.isNotEmpty,
        nullStatus: NullStatus(
          label: _query.isEmpty ? '还没有代理组' : '没有匹配的组',
          description: _query.isEmpty ? '组决定流量按什么策略选出口' : null,
          illustration: _query.isEmpty
              ? NullStatusIllustration.proxies
              : NullStatusIllustration.search,
          action: _query.isEmpty
              ? FilledButton(onPressed: _addGroup, child: const Text('添加代理组'))
              : null,
        ),
        child: PageBody(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: CommonCard(
                child: StatStrip(
                  stats: [
                    StatItem(label: '代理组', value: '${groups.length}'),
                    StatItem(
                      label: '可用节点',
                      value: '${proxies.length}',
                      color: colorScheme.primary,
                    ),
                    if (emptyGroups > 0)
                      StatItem(
                        label: '空组',
                        value: '$emptyGroups',
                        color: colorScheme.error,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  for (final group in visible)
                    ProxyGroupCard(
                      group: group,
                      isSelected: _selected.contains(group.id),
                      onTap: () {
                        if (selecting) {
                          setState(() {
                            if (!_selected.remove(group.id)) {
                              _selected.add(group.id);
                            }
                          });
                          return;
                        }
                        context.push(
                          ProfilesPaths.groupEditOf(widget.profileId, group.id),
                        );
                      },
                      onLongPress: () => setState(() {
                        if (!_selected.remove(group.id)) {
                          _selected.add(group.id);
                        }
                      }),
                      onMembers: () => context.push(
                        ProfilesPaths.groupMembersOf(
                          widget.profileId,
                          group.id,
                        ),
                      ),
                      onIcon: () => _pickIcon(group),
                      onDuplicate: () {
                        ref.read(proxyGroupsProvider.notifier).duplicate({
                          group.id,
                        });
                      },
                      onDelete: () => _delete({group.id}),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickIcon(MockProxyGroup group) async {
    final icon = await context.push<String>(
      ProfilesPaths.iconOf(widget.profileId, current: group.icon),
    );
    if (icon == null || icon.isEmpty || !mounted) {
      return;
    }
    ref.read(proxyGroupsProvider.notifier).setIcon(group.id, icon);
  }
}

/// 添加组面板：只问名字与类型，其余字段去编辑页填。
///
/// 先建后编而不是一次填完：组类型决定了编辑页要显示哪些字段（测速组要地址与
/// 间隔、负载均衡要策略），一次性表单会长出三四行当前类型用不上的东西。
class _AddGroupSheet extends ConsumerStatefulWidget {
  const _AddGroupSheet({required this.onCreated});

  final ValueChanged<MockProxyGroup> onCreated;

  @override
  ConsumerState<_AddGroupSheet> createState() => _AddGroupSheetState();
}

class _AddGroupSheetState extends ConsumerState<_AddGroupSheet> {
  final _name = TextEditingController();
  var _kind = GroupKind.selector;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    final notifier = ref.read(proxyGroupsProvider.notifier);
    final group = notifier.create(name: name, kind: _kind);
    if (!notifier.put(group)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('已有同名代理组'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1600),
        ),
      );
      return;
    }
    Navigator.of(context).pop();
    widget.onCreated(group);
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '添加代理组',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '创建',
        onPressed: _submit,
      ),
      body: ListView(
        controller: sheetScrollController(context),
        padding: const EdgeInsets.only(top: 8),
        children: [
          generateSection(
            title: '基本信息',
            items: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Row(
                  spacing: 12,
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text('名称', style: context.listTitleStyle),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _name,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: '如：🚀 节点选择',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListItem<GroupKind>.options(
                title: const Text('类型'),
                subtitle: Text(_kind.description),
                options: GroupKind.values,
                value: _kind,
                textBuilder: (kind) => kind.label,
                onChanged: (kind) => setState(() => _kind = kind),
              ),
            ],
            footer: '创建后进入编辑页，再按类型补上成员与参数。',
          ),
          SizedBox(height: NavigationDock.insetOf(context)),
        ],
      ),
    );
  }
}

/// 组的可用图标名（供编辑页调色板与图标选择器共用）。
List<String> groupIconNames() => const [
  'bolt',
  'speed',
  'star',
  'shuffle',
  'split',
  'swap',
  'layers',
  'puzzle',
  'target',
  'pin',
  'vpn',
  'block',
];

/// 组的图标字形（空则回落到按类型取）。
Glyph groupGlyphOf(MockProxyGroup group) {
  if (group.icon.isNotEmpty) {
    return glyphByName(group.icon);
  }
  return switch (group.kind) {
    GroupKind.selector => AppGlyphs.target,
    GroupKind.urlTest => AppGlyphs.speed,
    GroupKind.fallback => AppGlyphs.split,
    GroupKind.loadBalance => AppGlyphs.shuffle,
    GroupKind.relay => AppGlyphs.layers,
  };
}

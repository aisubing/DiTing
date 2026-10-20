import 'package:diting/data/mock_profiles.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'group_members_rows.dart';

/// 组成员选择页（上游 `views/profiles/custom/members.dart`，854 行）。
///
/// 布局是上下两段：
/// - 上段「已选」：可长按拖拽排序，顺序即优先级（fallback / relay 依赖它）；
/// - 下段「候选」：搜索 + 勾选，勾上就追加到已选末尾。
///
/// 两段都在同一个滚动视图里，而不是左右分栏：手机屏幕放不下两栏，而且
/// 「已选」通常只有几个，占不了多少高度。
class GroupMembersPage extends ConsumerStatefulWidget {
  const GroupMembersPage({
    super.key,
    required this.profileId,
    required this.groupId,
  });

  final String profileId;
  final String groupId;

  @override
  ConsumerState<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends ConsumerState<GroupMembersPage> {
  final _search = TextEditingController();
  var _query = '';
  late List<String> _selected;
  var _loaded = false;

  MockProxyGroup? get _group {
    for (final group in ref.read(proxyGroupsProvider)) {
      if (group.id == widget.groupId) {
        return group;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selected = [...?_group?.members];
    _loaded = true;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 候选：所有节点 + 所有其它组 + 内置策略，减去已选的。
  ///
  /// 组可以包含别的组（嵌套），但不能包含自己——否则内核会报循环引用。
  List<({String name, String subtitle, bool isGroup})> get _candidates {
    final proxies = ref.read(customProxiesProvider);
    final groups = ref.read(proxyGroupsProvider);
    final all = <({String name, String subtitle, bool isGroup})>[
      for (final proxy in proxies)
        (
          name: proxy.name,
          subtitle: '${proxy.protocol.label} · ${proxy.server}:${proxy.port}',
          isGroup: false,
        ),
      for (final group in groups)
        if (group.id != widget.groupId)
          (
            name: group.name,
            subtitle: '${group.kind.label} · ${group.members.length} 成员',
            isGroup: true,
          ),
      for (final target in MockRuleTarget.values)
        (name: target.value, subtitle: target.description, isGroup: false),
    ];
    return [
      for (final item in all)
        if (!_selected.contains(item.name) &&
            (_query.isEmpty ||
                item.name.toLowerCase().contains(_query) ||
                item.subtitle.toLowerCase().contains(_query)))
          item,
    ];
  }

  void _add(String name) {
    if (_selected.contains(name)) {
      return;
    }
    setState(() => _selected = [..._selected, name]);
  }

  void _remove(String name) {
    setState(
      () => _selected = [
        for (final item in _selected)
          if (item != name) item,
      ],
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) {
      return;
    }
    setState(() {
      final next = [..._selected];
      next.insert(newIndex.clamp(0, next.length), next.removeAt(oldIndex));
      _selected = next;
    });
  }

  void _save() {
    ref
        .read(proxyGroupsProvider.notifier)
        .setMembers(widget.groupId, _selected);
    context.safeNestedPop();
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    if (!_loaded || group == null) {
      return CommonScaffold(
        title: '选择成员',
        body: const AppBarClearance(
          child: SizedBox(
            height: 320,
            child: NullStatus(
              label: '代理组不存在',
              illustration: NullStatusIllustration.proxies,
            ),
          ),
        ),
      );
    }
    final colorScheme = context.colorScheme;
    final candidates = _candidates;
    return CommonScaffold(
      title: '选择成员',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存成员',
        onPressed: _save,
      ),
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.clearAll,
          tooltip: '清空已选',
          onPressed: _selected.isEmpty
              ? null
              : () => setState(() => _selected = const []),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    group.kind == GroupKind.relay
                        ? '已选成员按顺序串成链路，拖动右侧把手调整'
                        : '已选成员按顺序排列，拖动右侧把手调整优先级',
                    style: context.listCaptionStyle,
                  ),
                ),
                MetaChip(label: '已选 ${_selected.length}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_selected.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: context.raisedSurfaceLevel.colorOf(colorScheme),
                  shape: AppShape.lg,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Text(
                    '还没有成员，从下面的候选里勾选',
                    textAlign: TextAlign.center,
                    style: context.listCaptionStyle,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorderItem: _onReorder,
                itemCount: _selected.length,
                itemBuilder: (context, index) {
                  final name = _selected[index];
                  return Padding(
                    key: ValueKey('selected-$name'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: MemberSelectedRow(
                      name: name,
                      index: index,
                      total: _selected.length,
                      onRemove: () => _remove(name),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: '搜索节点、组或内置策略',
                prefixIcon: const GlyphIcon(AppGlyphs.search, size: 18),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: UiLocalizations.of(context).clearSearch,
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const GlyphIcon(AppGlyphs.close, size: 18),
                      ),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          const SizedBox(height: 12),
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Text(
                _query.isEmpty ? '没有更多可选的成员' : '没有匹配的候选',
                textAlign: TextAlign.center,
                style: context.listCaptionStyle,
              ),
            )
          else
            generateSection(
              title: '候选',
              items: [
                for (final candidate in candidates)
                  MemberCandidateRow(
                    name: candidate.name,
                    subtitle: candidate.subtitle,
                    isGroup: candidate.isGroup,
                    onAdd: () => _add(candidate.name),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

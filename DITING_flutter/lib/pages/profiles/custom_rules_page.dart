import 'package:diting/data/mock_profiles.dart';
import 'package:diting/pages/profiles/rule_form_sheet.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 自定义规则列表（上游 `views/profiles/custom/rules.dart`，620 行）。
///
/// 规则是**有序**的：内核按顺序匹配，第一条命中就停。因此列表提供排序模式
/// （拖拽重排），而不是像别的列表那样只给排序菜单——顺序本身就是语义。
///
/// 每行显示「类型 内容 → 目标」，并在禁用时整行压暗；顶部的统计给出启用数，
/// 因为禁用一条规则后它仍然在列表里，只靠逐行看徽标很难数清还剩几条生效。
class CustomRulesPage extends ConsumerStatefulWidget {
  const CustomRulesPage({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<CustomRulesPage> createState() => _CustomRulesPageState();
}

class _CustomRulesPageState extends ConsumerState<CustomRulesPage> {
  final _search = TextEditingController();
  var _query = '';
  final _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MockCustomRule> _visible(List<MockCustomRule> rules) => [
    for (final rule in rules)
      if (_query.isEmpty ||
          rule.content.toLowerCase().contains(_query) ||
          rule.target.toLowerCase().contains(_query) ||
          rule.type.value.toLowerCase().contains(_query) ||
          rule.type.label.contains(_query))
        rule,
  ];

  Future<void> _delete(Set<String> ids) async {
    final localizations = UiLocalizations.of(context);
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除 ${ids.length} 条规则',
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
        child: const Text('删除后这些域名/IP 会落到后面的规则或 MATCH 上。'),
      ),
    );
    if (confirmed ?? false) {
      ref.read(customRulesProvider.notifier).remove(ids);
      setState(_selected.clear);
    }
  }

  void _addRule({MockCustomRule? rule}) {
    showFormSheet<void>(
      context: context,
      builder: (_) => RuleFormSheet(rule: rule),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(customRulesProvider);
    final visible = _visible(rules);
    final selecting = _selected.isNotEmpty;
    final colorScheme = context.colorScheme;
    final enabled = rules.where((rule) => !rule.disabled).length;
    return CommonScaffold(
      title: selecting ? '已选 ${_selected.length} 项' : '规则',
      canSort: !selecting,
      searchState: AppBarSearchState(
        onSearch: (value) =>
            setState(() => _query = value.trim().toLowerCase()),
      ),
      backAction: selecting ? () => setState(_selected.clear) : null,
      selectionActions: [
        IconButtonData(
          glyph: AppGlyphs.selectAll,
          tooltip: '全选',
          onPressed: () {
            setState(() {
              final ids = visible.map((rule) => rule.id).toSet();
              if (_selected.containsAll(ids)) {
                _selected.clear();
              } else {
                _selected
                  ..clear()
                  ..addAll(ids);
              }
            });
          },
        ),
        IconButtonData(
          glyph: AppGlyphs.copy,
          tooltip: '复制所选',
          onPressed: () {
            ref.read(customRulesProvider.notifier).duplicate(_selected);
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
        tooltip: '添加规则',
        onPressed: () => _addRule(),
      ),
      body: Builder(
        builder: (context) {
          // 排序开关由 `CommonScaffold.canSort` 提供，它把 body 包进
          // `SortModeScope`；用 Builder 才能在 body 里读到该作用域。
          final sorting = SortModeScope.maybeOf(context)?.sorting ?? false;
          return NullStatusSwitcher(
            isEmpty: visible.isEmpty,
            isSearching: _query.isNotEmpty,
            nullStatus: NullStatus(
              label: _query.isEmpty ? '还没有规则' : '没有匹配的规则',
              description: _query.isEmpty ? '规则按顺序匹配，第一条命中即停止' : null,
              illustration: _query.isEmpty
                  ? NullStatusIllustration.rules
                  : NullStatusIllustration.search,
              action: _query.isEmpty
                  ? FilledButton(
                      onPressed: () => _addRule(),
                      child: const Text('添加规则'),
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
                        StatItem(
                          label: '启用',
                          value: '$enabled',
                          color: colorScheme.primary,
                        ),
                        StatItem(
                          label: '禁用',
                          value: '${rules.length - enabled}',
                        ),
                        StatItem(
                          label: '自定义',
                          value: '${rules.where((r) => r.src).length}',
                          unit: 'src',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (sorting)
                  _SortableRuleList(
                    rules: visible,
                    onReorder: ref.read(customRulesProvider.notifier).reorder,
                    onTap: (rule) => _addRule(rule: rule),
                  )
                else
                  generateSection(
                    title: '规则列表',
                    items: [
                      for (final rule in visible)
                        RuleRow(
                          rule: rule,
                          isSelected: _selected.contains(rule.id),
                          isSelecting: selecting,
                          onTap: () {
                            if (selecting) {
                              setState(() {
                                if (!_selected.remove(rule.id)) {
                                  _selected.add(rule.id);
                                }
                              });
                              return;
                            }
                            _addRule(rule: rule);
                          },
                          onLongPress: () => setState(() {
                            if (!_selected.remove(rule.id)) {
                              _selected.add(rule.id);
                            }
                          }),
                          onToggle: (value) => ref
                              .read(customRulesProvider.notifier)
                              .toggle(rule.id, value),
                        ),
                    ],
                    footer: '打开排序模式拖动把手可调整匹配顺序。',
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 排序模式下的规则行：一行只留核心文本与把手。
class _SortableRuleList extends StatelessWidget {
  const _SortableRuleList({
    required this.rules,
    required this.onReorder,
    required this.onTap,
  });

  final List<MockCustomRule> rules;
  final void Function(int, int) onReorder;
  final ValueChanged<MockCustomRule> onTap;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      onReorderItem: onReorder,
      itemCount: rules.length,
      itemBuilder: (context, index) {
        final rule = rules[index];
        return Padding(
          key: ValueKey(rule.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: ItemPositionProvider(
            position: ItemPosition.get(index, rules.length),
            child: DecorationListItem(
              contentPadding: const EdgeInsets.only(left: 16),
              title: Text(
                rule.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'JetBrainsMono'),
              ),
              trailing: SortHandle(index: index),
              onPressed: () => onTap(rule),
            ),
          ),
        );
      },
    );
  }
}

/// 一条规则行（上游 `RuleItem`）。
class RuleRow extends StatelessWidget {
  const RuleRow({
    super.key,
    required this.rule,
    required this.isSelected,
    required this.isSelecting,
    required this.onTap,
    required this.onLongPress,
    required this.onToggle,
  });

  final MockCustomRule rule;
  final bool isSelected;
  final bool isSelecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return GestureDetector(
      onLongPress: onLongPress,
      child: DecorationListItem(
        isSelected: isSelected,
        onPressed: onTap,
        leading: isSelecting
            ? (isSelected
                  ? const SelectionCheck()
                  : GlyphIcon(
                      AppGlyphs.rules,
                      color: colorScheme.onSurfaceVariant,
                    ))
            : GlyphIcon(
                rule.disabled ? AppGlyphs.block : AppGlyphs.rules,
                color: rule.disabled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.primary,
              ),
        title: Text(
          rule.content,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.subheadline
              .of(context)
              .copyWith(
                fontFamily: 'JetBrainsMono',
                color: rule.disabled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
              ),
        ),
        subtitle: Row(
          spacing: 6,
          children: [
            MetaChip(label: rule.type.label),
            Expanded(
              child: Text(
                '→ ${rule.target}'
                '${rule.noResolve ? ' · no-resolve' : ''}'
                '${rule.src ? ' · src' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.listCaptionStyle,
              ),
            ),
          ],
        ),
        trailing: isSelecting
            ? null
            : Switch(value: !rule.disabled, onChanged: onToggle),
      ),
    );
  }
}

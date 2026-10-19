/// 追加规则（上游 `views/config/rules.dart`，207 行）。
///
/// 与 `/rules` 的黑白名单页不同，这里是「用户直接写规则的原文」：一条规则由
/// 类型、内容、策略与 `no-resolve` 四部分组成，顺序决定命中优先级，所以这一页
/// 必须有排序能力；黑白名单页没有。
///
/// 上游用 `ReorderableList`（长按拖拽），演示层用上下箭头：追加规则通常只有
/// 十来条，箭头比拖拽更快也更准，且不需要一套拖拽代理装饰。
library;

import 'dart:async';

import 'package:diting/data/mock_config.dart';
import 'package:diting/pages/config/config_common.dart';
import 'package:diting/state/config_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'added_rules_form.dart';

/// 搜索防抖：与规则页的 250ms 保持一致，慢一点「边打边筛」就没意义了。
const _searchDebounce = Duration(milliseconds: 250);

/// 追加规则页。
class AddedRulesConfigPage extends ConsumerStatefulWidget {
  const AddedRulesConfigPage({super.key});

  @override
  ConsumerState<AddedRulesConfigPage> createState() =>
      _AddedRulesConfigPageState();
}

class _AddedRulesConfigPageState extends ConsumerState<AddedRulesConfigPage> {
  final _search = TextEditingController();
  final _selected = <String>{};
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

  List<MockAddedRule> _visible(List<MockAddedRule> rules) => [
    for (final rule in rules)
      if (_query.isEmpty ||
          rule.searchFields.any(
            (field) => field.toLowerCase().contains(_query),
          ))
        rule,
  ];

  void _toggleSelect(String id) => setState(() {
    if (!_selected.remove(id)) {
      _selected.add(id);
    }
  });

  Future<void> _deleteSelected(List<MockAddedRule> visible) async {
    final ids = {
      for (final rule in visible)
        if (_selected.contains(rule.id)) rule.id,
    };
    final confirmed = await confirmConfigAction(
      context,
      title: '删除选中的规则',
      message: '将删除 ${ids.length} 条追加规则，该操作不可撤销。',
    );
    if (!confirmed || !mounted) {
      return;
    }
    ref.read(configResourcesProvider.notifier).removeRules(ids);
    setState(_selected.clear);
  }

  Future<void> _clearAll() async {
    final confirmed = await confirmConfigAction(
      context,
      title: '清空追加规则',
      message:
          '将删除全部 ${ref.read(configResourcesProvider).rules.length} 条规则，'
          '订阅自带的规则不受影响。',
      confirmLabel: '清空',
    );
    if (!confirmed || !mounted) {
      return;
    }
    ref.read(configResourcesProvider.notifier).removeRules({
      for (final rule in ref.read(configResourcesProvider).rules) rule.id,
    });
    setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(configResourcesProvider).rules;
    final visible = _visible(rules);
    final selecting = _selected.isNotEmpty;
    return CommonScaffold(
      title: '追加规则',
      searchState: AppBarSearchState(onSearch: _onSearchChanged),
      iconActions: [
        if (!selecting)
          IconButtonData(
            glyph: AppGlyphs.add,
            tooltip: '添加规则',
            onPressed: () => showAddedRuleForm(context, ref),
          ),
        if (!selecting)
          IconButtonData(
            glyph: AppGlyphs.rulePresets,
            tooltip: '快速预设',
            onPressed: () => showRulePresetSheet(context, ref),
          ),
      ],
      selectionActions: selecting
          ? [
              IconButtonData(
                glyph: AppGlyphs.delete,
                tooltip: '删除选中',
                onPressed: () => _deleteSelected(visible),
              ),
              IconButtonData(
                glyph: AppGlyphs.selectAll,
                tooltip: '全选当前结果',
                onPressed: () => setState(() {
                  if (_selected.length == visible.length) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(visible.map((rule) => rule.id));
                  }
                }),
              ),
            ]
          : const [],
      menuItems: [
        CommonPopupMenuItem(
          label: '清空追加规则',
          glyph: AppGlyphs.broom,
          danger: true,
          onPressed: rules.isEmpty ? null : _clearAll,
        ),
      ],
      body: PageBody(
        children: [
          ConfigNoteCard(
            text:
                '追加规则排在订阅规则之后，只在这份配置里生效；'
                '顺序决定命中优先级，越靠上越先匹配。',
            glyph: AppGlyphs.rules,
          ),
          if (visible.isEmpty)
            SizedBox(
              height: 300,
              child: NullStatus(
                label: _query.isEmpty ? '还没有追加规则' : '没有匹配的规则',
                description: _query.isEmpty
                    ? '点右上角的加号手动写一条，或用预设一次加一组'
                    : '换个关键词再试',
                illustration: NullStatusIllustration.rules,
                action: _query.isEmpty
                    ? FilledButton(
                        onPressed: () => showAddedRuleForm(context, ref),
                        child: const Text('添加规则'),
                      )
                    : null,
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                '共 ${visible.length} 条'
                '${selecting ? ' · 已选 ${_selected.length}' : ''}',
                style: context.listCaptionStyle,
              ),
            ),
            generateSection(
              items: [
                for (final (index, rule) in visible.indexed)
                  _AddedRuleRow(
                    rule: rule,
                    selecting: selecting,
                    selected: _selected.contains(rule.id),
                    // 搜索时禁用排序：可见列表是筛过的子集，而 `moveRule` 在
                    // 全表上换位，落点会跳到看不见的行上。
                    canMoveUp: _query.isEmpty && index > 0,
                    canMoveDown: _query.isEmpty && index < visible.length - 1,
                    onToggleSelect: () => _toggleSelect(rule.id),
                    onEdit: () =>
                        showAddedRuleForm(context, ref, existing: rule),
                    onMoveUp: () => ref
                        .read(configResourcesProvider.notifier)
                        .moveRule(rule.id, -1),
                    onMoveDown: () => ref
                        .read(configResourcesProvider.notifier)
                        .moveRule(rule.id, 1),
                  ),
              ],
              footer: '搜索时不能排序：筛过的列表上移下移，落点会落在看不见的行上。',
            ),
          ],
        ],
      ),
    );
  }
}

/// 一条追加规则行。
class _AddedRuleRow extends StatelessWidget {
  const _AddedRuleRow({
    required this.rule,
    required this.selecting,
    required this.selected,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onToggleSelect,
    required this.onEdit,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final MockAddedRule rule;
  final bool selecting;
  final bool selected;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      isSelected: selected,
      onPressed: selecting ? onToggleSelect : onEdit,
      leading: selecting
          ? CommonCheckBox(
              value: selected,
              isCircle: true,
              onChanged: (_) => onToggleSelect(),
            )
          : const GlyphIcon(AppGlyphs.rules, size: 20),
      title: Text(rule.line, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${rule.kind.label} · 命中后走 ${rule.policy}'),
      trailing: selecting
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                CommonMinIconButtonTheme(
                  child: IconButton(
                    tooltip: '上移',
                    onPressed: canMoveUp ? onMoveUp : null,
                    icon: const GlyphIcon(AppGlyphs.arrowUp, size: 18),
                  ),
                ),
                CommonMinIconButtonTheme(
                  child: IconButton(
                    tooltip: '下移',
                    onPressed: canMoveDown ? onMoveDown : null,
                    icon: const GlyphIcon(AppGlyphs.arrowDown, size: 18),
                  ),
                ),
                ConfigRemoveButton(
                  tooltip: '编辑',
                  glyph: AppGlyphs.edit,
                  onPressed: onEdit,
                ),
              ],
            ),
    );
  }
}

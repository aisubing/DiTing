part of 'extend_page.dart';

/// 标准模式内容（上游 `extend/standard.dart`，403 行）。
///
/// 三块：已追加规则（可重排、可多选删除）、匹配目标、全局追加规则入口。
/// 追加规则**有序**且排在档案自带规则之后，所以顺序在这里同样有语义。
class _StandardContent extends ConsumerStatefulWidget {
  const _StandardContent({required this.profileId});

  final String profileId;

  @override
  ConsumerState<_StandardContent> createState() => _StandardContentState();
}

class _StandardContentState extends ConsumerState<_StandardContent> {
  final _selected = <String>{};

  Future<void> _addOrUpdate([MockCustomRule? rule]) async {
    await showFormSheet<void>(
      context: context,
      builder: (_) => RuleFormSheet(
        rule: rule,
        onSave: (draft) {
          final notifier = ref.read(addedRulesProvider.notifier);
          return notifier.put(
            notifier.create(
              type: draft.type,
              content: draft.content,
              target: draft.target,
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete() async {
    final localizations = UiLocalizations.of(context);
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除 ${_selected.length} 条追加规则',
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
        child: const Text('这些规则会从所有档案的追加列表里移除。'),
      ),
    );
    if (confirmed ?? false) {
      ref.read(addedRulesProvider.notifier).removeAll(_selected);
      setState(_selected.clear);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(addedRulesProvider);
    final colorScheme = context.colorScheme;
    final selecting = _selected.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListHeader(
          title: '已追加规则',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actions: [
            if (selecting) ...[
              IconButtonData(
                glyph: AppGlyphs.selectAll,
                tooltip: '全选',
                onPressed: () => setState(() {
                  final ids = rules.map((rule) => rule.id).toSet();
                  if (_selected.containsAll(ids)) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(ids);
                  }
                }),
              ),
              IconButtonData(
                glyph: AppGlyphs.delete,
                tooltip: '删除',
                onPressed: _delete,
              ),
            ] else ...[
              IconButtonData(
                glyph: AppGlyphs.selectAll,
                tooltip: '多选',
                onPressed: () => setState(() {
                  if (rules.isNotEmpty) {
                    _selected.add(rules.first.id);
                  }
                }),
              ),
              IconButtonData(
                glyph: AppGlyphs.addCircle,
                tooltip: '添加规则',
                onPressed: () => _addOrUpdate(),
              ),
            ],
          ],
        ),
        if (rules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              '还没有追加规则。追加的规则会排在这份档案自带的规则之后。',
              style: context.listCaptionStyle,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorderItem: ref.read(addedRulesProvider.notifier).reorder,
              itemCount: rules.length,
              itemBuilder: (context, index) {
                final rule = rules[index];
                return Padding(
                  key: ValueKey(rule.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ItemPositionProvider(
                    position: ItemPosition.get(index, rules.length),
                    child: _AddedRuleRow(
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
                        _addOrUpdate(rule);
                      },
                      onLongPress: () => setState(() {
                        if (!_selected.remove(rule.id)) {
                          _selected.add(rule.id);
                        }
                      }),
                      dragIndex: index,
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 20),
        _MatchTargetItem(profileId: widget.profileId),
        const SizedBox(height: 8),
        MoreActionButton(
          label: '控制全局追加规则',
          onPressed: () =>
              showGlobalRulesPage(context, profileId: widget.profileId),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            '全局追加规则对所有档案生效，这里只控制它们的启停。',
            style: context.listCaptionStyle.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// 追加规则行：规则文本 + 目标 + 拖拽把手。
class _AddedRuleRow extends StatelessWidget {
  const _AddedRuleRow({
    required this.rule,
    required this.isSelected,
    required this.isSelecting,
    required this.onTap,
    required this.onLongPress,
    required this.dragIndex,
  });

  final MockCustomRule rule;
  final bool isSelected;
  final bool isSelecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int dragIndex;

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
            : GlyphIcon(AppGlyphs.rules, color: colorScheme.primary),
        title: Text(
          rule.content,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.subheadline
              .of(context)
              .copyWith(fontFamily: 'JetBrainsMono'),
        ),
        subtitle: Text(
          '${rule.type.label} → ${rule.target}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.listCaptionStyle,
        ),
        trailing: isSelecting ? null : SortHandle(index: dragIndex),
      ),
    );
  }
}

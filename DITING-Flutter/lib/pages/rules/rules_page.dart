import 'dart:async';

import 'package:diting/data/mock_data.dart';
import 'package:diting/router.dart';
import 'package:diting/state/rules_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/app_list_view.dart';
import 'package:diting/widgets/chip_row.dart';
import 'package:diting/widgets/empty_state.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

part 'rules_dialogs.dart';
part 'rules_rows.dart';

/// Search debounce, 250 ms like all three upstream rule tables: slower makes live
/// filtering pointless, faster rebuilds the whole list on every keystroke.
const _searchDebounce = Duration(milliseconds: 250);

/// Rule page: block, allow and rewrite share one skeleton, differing only in title, stats
/// and row content, matching the single upstream RuleListScreen with a dataset parameter.
class RulesPage extends ConsumerStatefulWidget {
  const RulesPage({super.key, required this.kind});

  final String kind;

  @override
  ConsumerState<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends ConsumerState<RulesPage> {
  late final _search = TextEditingController();
  Timer? _debounce;

  /// Debounced keyword. The text field itself is not debounced, or typing would lag.
  var _query = '';
  RuleSourceFilter _sourceFilter;

  RuleKind get _kind => switch (widget.kind) {
    'allow' => RuleKind.allow,
    'rewrite' => RuleKind.rewrite,
    _ => RuleKind.block,
  };

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

  /// Prompt once for pattern plus optional target; rewrite needs two fields, which is what
  /// _RuleDialog exists for.
  Future<({String pattern, String? target})?> _promptRule({
    required String title,
    required String initialPattern,
    String? initialTarget,
    Set<String> existingPatterns = const {},
  }) async {
    final kind = _kind;
    if (kind != RuleKind.rewrite) {
      final pattern = await showFloatingDialog<String>(
        context: context,
        child: InputDialog(
          title: title,
          value: initialPattern,
          hintText: '规则内容，如 ||ads.example.com^',
          selectAll: initialPattern.isNotEmpty,
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.isEmpty) {
              return '规则内容不能为空';
            }
            if (kind != RuleKind.allow && text.contains('#@#')) {
              return '该规则为放行规则，请在白名单中添加';
            }
            if (existingPatterns.contains(text)) {
              return '该规则已存在';
            }
            return null;
          },
        ),
      );
      return pattern == null ? null : (pattern: pattern.trim(), target: null);
    }
    return showFloatingDialog<({String pattern, String? target})>(
      context: context,
      child: _RuleDialog(
        title: title,
        initialPattern: initialPattern,
        initialTarget: initialTarget,
        existingPatterns: existingPatterns,
      ),
    );
  }

  Future<void> _addRule() async {
    final kind = _kind;
    final result = await _promptRule(
      title: '添加${kind.title}规则',
      initialPattern: '',
      existingPatterns: {
        for (final rule in ref.read(rulesOfKindProvider(kind))) rule.pattern,
      },
    );
    if (result == null || !mounted) {
      return;
    }
    await ref
        .read(rulesProvider.notifier)
        .add(kind, result.pattern, target: result.target);
  }

  Future<void> _editRule(MockRule rule) async {
    final kind = _kind;
    final result = await _promptRule(
      title: rule.source == RuleSource.preset
          ? '编辑默认预设规则'
          : '编辑${kind.title}规则',
      initialPattern: rule.pattern,
      initialTarget: rule.target,
      existingPatterns: {
        for (final other in ref.read(rulesOfKindProvider(kind)))
          if (other.id != rule.id) other.pattern,
      },
    );
    if (result == null || !mounted) {
      return;
    }
    await ref
        .read(rulesProvider.notifier)
        .edit(kind, rule.id, result.pattern, target: result.target);
  }

  Future<void> _deleteRule(MockRule rule) async {
    final kind = _kind;
    final confirmed = await _confirm(
      context,
      title: '删除规则',
      message: switch (rule.source) {
        RuleSource.preset => '「${rule.pattern}」是内置预设规则，删除后可通过重置默认恢复。',
        RuleSource.subscription =>
          '「${rule.pattern}」来自订阅「${rule.subscriptionName ?? '规则订阅'}」，'
              '删除后下次更新订阅可能重新出现。',
        RuleSource.user => '确定删除「${rule.pattern}」吗？此操作不可撤销。',
      },
      confirmLabel: '删除',
    );
    if (!confirmed || !mounted) {
      return;
    }
    await ref.read(rulesProvider.notifier).remove(kind, rule.id);
  }

  Future<void> _clearCustom() async {
    final kind = _kind;
    final confirmed = await _confirm(
      context,
      title: '清空自定义规则',
      message: '将删除全部用户自定义的${kind.title}规则，订阅与预设规则不受影响。',
      confirmLabel: '清空',
    );
    if (!confirmed || !mounted) {
      return;
    }
    await ref.read(rulesProvider.notifier).clearCustom(kind);
  }

  Future<void> _resetPreset() async {
    final kind = _kind;
    final confirmed = await _confirm(
      context,
      title: '重置默认白名单',
      message: '将内置预设规则恢复为初始内容，你自己添加与订阅带来的规则保留。',
      confirmLabel: '重置',
    );
    if (!confirmed || !mounted) {
      return;
    }
    await ref.read(rulesProvider.notifier).resetPreset(kind);
  }

  /// Hint when a read-only row is tapped. A dialog rather than a snackbar: the
  /// message tells the user where to enable editing and must not scroll away.
  Future<void> _showProtectedHint() => showFloatingDialog<void>(
    context: context,
    child: CommonDialog(
      title: '预设规则受保护',
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(UiLocalizations.of(context).close),
        ),
      ],
      child: const Text(
        '默认白名单规则处于只读状态。请先开启页面顶部的'
        '「允许编辑默认白名单」开关，再修改或删除这些规则。',
      ),
    ),
  );

  Future<void> _togglePresetEditing(bool value) async {
    if (!value) {
      ref.read(allowPresetEditableProvider.notifier).set(false);
      return;
    }
    final confirmed = await _confirm(
      context,
      title: '允许编辑默认白名单？',
      message:
          '白名单是放行名单，改动它可能让本应被拦截的流量通过。'
          '确认你清楚这条风险后再开启。',
      confirmLabel: '仍然开启',
    );
    if (!confirmed || !mounted) {
      return;
    }
    ref.read(allowPresetEditableProvider.notifier).set(true);
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    final allowPresetEditable = ref.watch(allowPresetEditableProvider);
    final filter = RuleListFilter(
      kind: kind,
      source: _sourceFilter,
      query: _query,
    );
    // Both come from providers, so the counter and the rows always describe the same snapshot.
    final tally = ref.watch(ruleListTallyProvider(filter));
    final visible = ref.watch(filteredRulesProvider(filter));
    final searching = _query.isNotEmpty || _sourceFilter != null;

    return CommonScaffold(
      title: kind.title,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加${kind.title}规则',
          onPressed: _addRule,
        ),
        IconButtonData(
          glyph: AppGlyphs.listAdd,
          tooltip: '批量添加规则',
          onPressed: () => context.push(Routes.batchEditor),
        ),
      ],
      menuItems: [
        CommonPopupMenuItem(
          label: '清空自定义${kind.title}',
          glyph: AppGlyphs.broom,
          danger: true,
          onPressed: tally.custom == 0 ? null : _clearCustom,
        ),
        if (kind == RuleKind.allow)
          CommonPopupMenuItem(
            label: '重置默认白名单',
            glyph: AppGlyphs.reset,
            onPressed: _resetPreset,
          ),
      ],
      body: AppListScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: CommonCard(
                    child: StatStrip(
                      stats: [
                        StatItem(label: '规则总数', value: '${tally.total}'),
                        StatItem(
                          label: '已启用',
                          value: '${tally.enabled}',
                          color: context.colorScheme.success,
                        ),
                        StatItem(
                          label: kind == RuleKind.rewrite ? '覆写条目' : '自定义',
                          value: '${tally.custom}',
                        ),
                      ],
                    ),
                  ),
                ),
                if (kind == RuleKind.allow)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: CommonCard(
                      child: ListItem.toggle(
                        title: const Text('允许编辑默认白名单'),
                        subtitle: const Text('关闭时预设规则只读，避免误放宽放行范围'),
                        value: allowPresetEditable,
                        onChanged: _togglePresetEditing,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SearchField(
                    controller: _search,
                    onChanged: _onSearchChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: _SourceChips(
                    value: _sourceFilter,
                    onChanged: (value) => setState(() => _sourceFilter = value),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Text(
                    // The counter always reports a number, even zero: the empty state already
                    // says there are no matching rules, and repeating it reads as double render.
                    '共 ${tally.matched} 条 · 启用 ${tally.matchedEnabled}',
                    style: context.listCaptionStyle,
                  ),
                ),
              ],
            ),
          ),
          if (visible.isEmpty)
            SliverToBoxAdapter(
              child: EmptyStateBox(
                minHeight: 320,
                child: NullStatus(
                  label: searching ? '没有匹配的规则' : '还没有${kind.title}规则',
                  description: searching ? '换个关键词或筛选条件再试' : kind.summary,
                  illustration: NullStatusIllustration.rules,
                  action: searching
                      ? null
                      : FilledButton(
                          onPressed: _addRule,
                          child: Text('添加${kind.title}规则'),
                        ),
                ),
              ),
            )
          else
            // One sliver per source section, each a lazy SliverList: a subscription with a
            // hundred thousand rows used to be inflated in one frame and froze the UI.
            for (final section in ruleSections(visible))
              ...ruleSectionSlivers(
                source: section.source,
                rules: section.rules,
                kind: kind,
                allowPresetEditable: allowPresetEditable,
                onToggle: (rule, enabled) => ref
                    .read(rulesProvider.notifier)
                    .toggle(kind, rule.id, enabled),
                onEdit: _editRule,
                onDelete: _deleteRule,
                onProtected: _showProtectedHint,
              ),
        ],
      ),
    );
  }
}

/// Source filter chips: all, user, subscription, built-in preset. This row is the reference
/// chip-row shape for the whole app, now extracted into ChipRow plus FilterPill.
class _SourceChips extends StatelessWidget {
  const _SourceChips({required this.value, required this.onChanged});

  final RuleSourceFilter value;
  final ValueChanged<RuleSourceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <(RuleSourceFilter, String)>[
      (null, '全部'),
      for (final source in RuleSource.values) (source, source.label),
    ];
    return ChipRow(
      children: [
        for (final (source, label) in options)
          FilterPill(
            label: label,
            selected: source == value,
            onPressed: () => onChanged(source),
          ),
      ],
    );
  }
}

/// Rule rows grouped by source, in enum order. Presets may be read-only and subscriptions get
/// overwritten, so grouping carries meaning and each group is its own sliver.
class RuleSection {
  const RuleSection(this.source, this.rules);

  final RuleSource source;
  final List<MockRule> rules;
}

List<RuleSection> ruleSections(List<MockRule> rules) {
  final bySource = <RuleSource, List<MockRule>>{};
  for (final rule in rules) {
    (bySource[rule.source] ??= []).add(rule);
  }
  return [
    for (final source in RuleSource.values)
      if (bySource[source] case final group?) RuleSection(source, group),
  ];
}

/// Header plus a lazy row sliver for one source group. Rows are built on demand: a subscription
/// can carry six figures of rules, and inflating them all in the first frame is what froze the
/// page (see the 2026-10-27 ANR with 191,090 rules).
List<Widget> ruleSectionSlivers({
  required RuleSource source,
  required List<MockRule> rules,
  required RuleKind kind,
  required bool allowPresetEditable,
  required void Function(MockRule rule, bool enabled) onToggle,
  required ValueChanged<MockRule> onEdit,
  required ValueChanged<MockRule> onDelete,
  required VoidCallback onProtected,
}) {
  return [
    SliverToBoxAdapter(child: ListHeader(title: source.label)),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: rules.length,
        // Rows are cheap to rebuild; keeping thousands alive is what made the old list stutter.
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) {
          final rule = rules[index];
          return ItemPositionProvider(
            position: ItemPosition.get(index, rules.length),
            child: _RuleRow(
              rule: rule,
              kind: kind,
              protected: isRuleProtected(
                rule,
                kind: kind,
                allowPresetEditable: allowPresetEditable,
              ),
              onToggle: (enabled) => onToggle(rule, enabled),
              onEdit: () => onEdit(rule),
              onDelete: () => onDelete(rule),
              onProtected: onProtected,
            ),
          );
        },
      ),
    ),
  ];
}

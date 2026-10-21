import 'dart:async';

import 'package:diting/data/mock_data.dart';
import 'package:diting/router.dart';
import 'package:diting/state/rules_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/chip_row.dart';
import 'package:diting/widgets/empty_state.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

part 'rules_dialogs.dart';
part 'rules_rows.dart';

/// 搜索防抖。上游三张规则表都是 250ms，这里保持一致，慢一点会让「边打边筛」
/// 失去意义，快一点则每次按键都要重建整张列表。
const _searchDebounce = Duration(milliseconds: 250);

/// 规则页：黑名单 / 白名单 / 覆写共用一套骨架，只有标题、统计项与行内容不同。
///
/// 三页结构一致是刻意的——上游也是同一个 `RuleListScreen` 加 dataset 参数，
/// 拆成三个页面会让「搜索框在哪、计数头在哪」在三种规则间漂移。
class RulesPage extends ConsumerStatefulWidget {
  const RulesPage({super.key, required this.kind});

  /// 路由参数：block / allow / rewrite。
  final String kind;

  @override
  ConsumerState<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends ConsumerState<RulesPage> {
  late final _search = TextEditingController();
  Timer? _debounce;

  /// 防抖后的关键词。输入框本身不受防抖影响，否则打字会卡。
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

  /// 过滤后的规则：来源 chip 与关键词是「与」关系。
  List<MockRule> _visibleRules(List<MockRule> rules) => [
    for (final rule in rules)
      if ((_sourceFilter == null || rule.source == _sourceFilter) &&
          (_query.isEmpty ||
              rule.pattern.toLowerCase().contains(_query) ||
              (rule.target?.toLowerCase().contains(_query) ?? false)))
        rule,
  ];

  /// 弹一次输入框，返回「规则内容 + 目标」。
  ///
  /// 黑名单与白名单只有一个字段，直接复用 [InputDialog]；覆写规则要同时收
  /// 域名与目标值，[InputDialog] 收不下，才走 [_RuleDialog]。让两种规则共用
  /// 一个自建对话框，等于给普通规则也加上一个用不到的输入框。
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

  /// 只读行被点时的提示。用确认框而不是提示条：提示条会随页面滚动消失，而
  /// 用户需要知道的是「去哪开开关」，这段信息不该一闪而过。
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
    final rules = ref.watch(rulesOfKindProvider(kind));
    final allowPresetEditable = ref.watch(allowPresetEditableProvider);
    final visible = _visibleRules(rules);
    final enabledCount = rules.where((rule) => rule.enabled).length;
    final customCount = rules
        .where((rule) => rule.source == RuleSource.user)
        .length;

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
          onPressed: customCount == 0 ? null : _clearCustom,
        ),
        if (kind == RuleKind.allow)
          CommonPopupMenuItem(
            label: '重置默认白名单',
            glyph: AppGlyphs.reset,
            onPressed: _resetPreset,
          ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              child: StatStrip(
                stats: [
                  StatItem(label: '规则总数', value: '${rules.length}'),
                  StatItem(
                    label: '已启用',
                    value: '$enabledCount',
                    color: context.colorScheme.success,
                  ),
                  StatItem(
                    label: kind == RuleKind.rewrite ? '覆写条目' : '自定义',
                    value: kind == RuleKind.rewrite
                        ? '${rules.where((rule) => rule.target != null).length}'
                        : '$customCount',
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
              // 计数头始终报数，即使为 0：空状态里已经有一句「没有匹配的规则」，
              // 两处说同一句话会让这块区域读起来像重复渲染。
              '共 ${visible.length} 条 · 启用 '
              '${visible.where((rule) => rule.enabled).length}',
              style: context.listCaptionStyle,
            ),
          ),
          if (visible.isEmpty)
            EmptyStateBox(
              minHeight: 320,
              child: NullStatus(
                label: _query.isEmpty && _sourceFilter == null
                    ? '还没有${kind.title}规则'
                    : '没有匹配的规则',
                description: _query.isEmpty && _sourceFilter == null
                    ? kind.summary
                    : '换个关键词或筛选条件再试',
                illustration: NullStatusIllustration.rules,
                action: _query.isEmpty && _sourceFilter == null
                    ? FilledButton(
                        onPressed: _addRule,
                        child: Text('添加${kind.title}规则'),
                      )
                    : null,
              ),
            )
          else
            _RuleList(
              rules: visible,
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

/// 来源筛选 chip 行：全部 / 用户自定义 / 规则订阅 / 内置预设。
///
/// 这一行的形态（定高 32、横向滚动、间距 8、内边距由调用方给 16）就是全站
/// chip 行的参照实现，现已抽成 [ChipRow] + [FilterPill]，其余页面共用同一份。
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

/// 规则列表：按来源分组，组内行用 `generateSection` 生成，分隔线才对得上。
///
/// 分组而不是平铺：三种来源的处置语义不同（预设可能只读、订阅会被下次更新
/// 覆盖），混排时用户看不出某一行属于哪一类。
class _RuleList extends StatelessWidget {
  const _RuleList({
    required this.rules,
    required this.kind,
    required this.allowPresetEditable,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onProtected,
  });

  final List<MockRule> rules;
  final RuleKind kind;
  final bool allowPresetEditable;
  final void Function(MockRule rule, bool enabled) onToggle;
  final ValueChanged<MockRule> onEdit;
  final ValueChanged<MockRule> onDelete;
  final VoidCallback onProtected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final source in RuleSource.values)
          if (rules.where((rule) => rule.source == source).toList()
              case final group when group.isNotEmpty)
            generateSection(
              title: source.label,
              items: [
                for (final rule in group)
                  _RuleRow(
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
              ],
            ),
      ],
    );
  }
}

/// 规则预设多选浮层（上游 `features/form/rule_preset.dart`，145 行）。
///
/// 七个常用规则预设，勾选后一次插入。上游的 `RulePreset` 枚举里带字形与原始
/// 规则文本；这里把规则文本放数据层（`mock_forms.dart`），枚举只承担「分类 +
/// 显示名」，因为规则文本是内容而不是 UI 常量。
library;

import 'package:diting/data/mock_forms.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 规则预设多选浮层。返回选中的预设标题列表。
class RulePresetSheet extends StatefulWidget {
  const RulePresetSheet({super.key, this.initial = const {}});

  final Set<String> initial;

  @override
  State<RulePresetSheet> createState() => _RulePresetSheetState();
}

class _RulePresetSheetState extends State<RulePresetSheet> {
  late final _selected = {...widget.initial};

  /// 选中的预设展开后能看到原始规则；未选中的收起。
  final _expanded = <String>{};
  int get _ruleCount => _selected.fold(
    0,
    (sum, title) =>
        sum +
        (mockRulePresets
            .firstWhere((preset) => preset.title == title)
            .rules
            .length),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '规则预设',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '插入选中规则',
        onPressed: () => Navigator.of(context).pop(_selected),
      ),
      body: PageBody(
        dockSpacer: false,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                spacing: 12,
                children: [
                  GlyphIcon(
                    AppGlyphs.rulePresets,
                    size: 22,
                    color: colorScheme.primary,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          '已选 ${_selected.length} 个预设',
                          style: context.listTitleStyle,
                        ),
                        Text(
                          '将插入 $_ruleCount 条规则',
                          style: context.listCaptionStyle,
                        ),
                      ],
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(_selected.clear),
                      child: Text(
                        '清空',
                        style: AppTextStyle.subheadline
                            .of(context)
                            .copyWith(color: colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
          generateSection(
            title: '可用预设',
            items: [
              for (final preset in mockRulePresets)
                _PresetRow(
                  preset: preset,
                  selected: _selected.contains(preset.title),
                  expanded: _expanded.contains(preset.title),
                  onToggle: () => setState(() {
                    if (!_selected.remove(preset.title)) {
                      _selected.add(preset.title);
                      _expanded.add(preset.title);
                    }
                  }),
                  onExpand: () => setState(() {
                    if (!_expanded.remove(preset.title)) {
                      _expanded.add(preset.title);
                    }
                  }),
                ),
            ],
            footer:
                '预设只是把常用规则拼成一段文本插入，插入后仍可逐条编辑。'
                '阻塞类规则默认用 REJECT，需要静默丢弃时改成 REJECT-DROP。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 一个预设行：勾选框 + 标题 + 规则条数 + 展开箭头。
class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.preset,
    required this.selected,
    required this.expanded,
    required this.onToggle,
    required this.onExpand,
  });

  final MockRulePreset preset;
  final bool selected;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecorationListItem(
          isSelected: selected,
          onPressed: onToggle,
          leading: CommonCheckBox(
            value: selected,
            isCircle: true,
            onChanged: (_) => onToggle(),
          ),
          title: Row(
            spacing: 8,
            children: [
              GlyphIcon(
                glyphByName(preset.glyphName),
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              Expanded(
                child: Text(
                  preset.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Text(preset.description),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Text(
                '${preset.rules.length} 条',
                style: context.listCaptionStyle.copyWith(
                  fontFamily: 'JetBrainsMono',
                ),
              ),
              CommonMinIconButtonTheme(
                child: IconButton(
                  tooltip: expanded ? '收起规则' : '展开规则',
                  onPressed: onExpand,
                  icon: GlyphIcon(
                    expanded ? AppGlyphs.chevronUp : AppGlyphs.chevronDown,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (expanded)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(10),
            decoration: ShapeDecoration(
              shape: AppShape.md,
              color: context.raisedSurfaceLevel.colorOf(colorScheme),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 4,
              children: [
                for (final rule in preset.rules)
                  Text(
                    rule,
                    style: AppTextStyle.footnote
                        .of(context)
                        .copyWith(
                          fontFamily: 'JetBrainsMono',
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

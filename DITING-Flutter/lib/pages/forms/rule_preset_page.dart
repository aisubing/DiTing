/// Rule preset demo page (`/form/rule-preset`): the sheet content laid out as a page.
library;

import 'package:diting/data/mock_forms.dart';
import 'package:diting/pages/forms/rule_preset_sheet.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

class RulePresetPage extends StatefulWidget {
  const RulePresetPage({super.key});

  @override
  State<RulePresetPage> createState() => _RulePresetPageState();
}

class _RulePresetPageState extends State<RulePresetPage> {
  final _output = TextEditingController();
  final _selected = <String>{};
  final _expanded = <String>{};

  @override
  void dispose() {
    _output.dispose();
    super.dispose();
  }

  void _insert() {
    final rules = [
      for (final preset in mockRulePresets)
        if (_selected.contains(preset.title)) ...preset.rules,
    ];
    if (rules.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('先勾选至少一个预设'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1400),
        ),
      );
      return;
    }
    if (_output.text.isNotEmpty && !_output.text.endsWith('\n')) {
      _output.text = '${_output.text}\n';
    }
    _output.text = '${_output.text}${rules.join('\n')}\n';
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('已插入 ${rules.length} 条规则'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  Future<void> _openSheet() async {
    final result = await showFormSheet<Set<String>>(
      context: context,
      props: const SheetProps(detents: [0.85]),
      builder: (_) => RulePresetSheet(initial: _selected),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _selected
        ..clear()
        ..addAll(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '规则预设',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.rulePresets,
          tooltip: '以浮层形式打开',
          onPressed: _openSheet,
        ),
      ],
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '插入选中规则',
        onPressed: _insert,
      ),
      body: PageBody(
        dockSpacer: false,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      GlyphIcon(
                        AppGlyphs.rulePresets,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      Expanded(
                        child: Text(
                          '已选 ${_selected.length} 个预设',
                          style: AppTextStyle.title3.of(
                            context,
                            emphasized: true,
                          ),
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
                  Text(
                    '预设只是把常用规则拼成一段文本插入；插入后仍可逐条编辑。',
                    style: context.listSubtitleStyle.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          generateSection(
            title: '可用预设',
            items: [
              for (final preset in mockRulePresets)
                _PresetTile(
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TonalButton(
              label: '插入到下方',
              glyph: AppGlyphs.importFile,
              size: TonalButtonSize.section,
              onPressed: _insert,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _output,
                minLines: 5,
                maxLines: 12,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(fontFamily: 'JetBrainsMono'),
                decoration: InputDecoration.collapsed(
                  hintText: '插入的规则会出现在这里',
                  hintStyle: context.listCaptionStyle,
                ),
              ),
            ),
          ),
          const ListFooter(
            text:
                '阻塞类规则默认用 REJECT；需要「静默丢弃」时改成 REJECT-DROP，'
                '两者的区别是前者会立刻回一个空响应，后者直接丢包。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
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
                  tooltip: expanded ? '收起' : '展开',
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
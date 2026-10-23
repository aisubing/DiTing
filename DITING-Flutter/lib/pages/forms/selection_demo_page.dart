/// Selection sheet demo (`/form/selection`): single select returns on tap, multi confirms.
library;

import 'package:diting/pages/forms/selection_sheet.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

class _DemoOption {
  const _DemoOption(this.label, this.description);

  final String label;
  final String description;
}

const _demoOptions = <_DemoOption>[
  _DemoOption('自动选择', '按延迟在全部节点里自动挑选'),
  _DemoOption('手动切换', '由用户手动指定当前节点'),
  _DemoOption('故障转移', '当前节点不可用时依次尝试后续节点'),
  _DemoOption('负载均衡', '按权重把流量分摊到多个节点'),
  _DemoOption('香港 01', 'ss · hk01.example.com:8388'),
  _DemoOption('东京 02', 'trojan · jp02.example.com:443'),
  _DemoOption('新加坡 03', 'vmess · sg03.example.com:443'),
  _DemoOption('洛杉矶 04', 'ss · us04.example.com:8388'),
];

class SelectionDemoPage extends StatefulWidget {
  const SelectionDemoPage({super.key});

  @override
  State<SelectionDemoPage> createState() => _SelectionDemoPageState();
}

class _SelectionDemoPageState extends State<SelectionDemoPage> {
  String? _single;
  final _multi = <String>{};

  Future<void> _pickSingle() async {
    final result = await showSelectionSheet<String>(
      context: context,
      title: '选择代理组',
      items: [for (final option in _demoOptions) option.label],
      labelBuilder: (label) => label,
      subtitleBuilder: (label) => _demoOptions
          .firstWhere((option) => option.label == label)
          .description,
      selected: _single,
    );
    if (result != null && mounted) {
      setState(() => _single = result);
    }
  }

  Future<void> _pickMulti() async {
    final result = await showFormSheet<Set<String>>(
      context: context,
      props: const SheetProps(detents: [0.9]),
      builder: (_) => SelectionSheet<String>(
        title: '多选节点',
        sections: [
          SelectionSection<String>(
            label: '策略组',
            items: [for (final option in _demoOptions.take(4)) option.label],
            subtitleBuilder: (label) => _demoOptions
                .firstWhere((option) => option.label == label)
                .description,
          ),
          SelectionSection<String>(
            label: '节点',
            items: [for (final option in _demoOptions.skip(4)) option.label],
            subtitleBuilder: (label) => _demoOptions
                .firstWhere((option) => option.label == label)
                .description,
          ),
        ],
        labelBuilder: (label) => label,
        selectedMany: _multi,
        onSelectedMany: (selected) => Navigator.of(context).pop(selected),
        footer: '分段之间可以有不同来源；多选模式下点右下角对勾才提交。',
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _multi
          ..clear()
          ..addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final single = _single;
    return CommonScaffold(
      title: '选择浮层',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      GlyphIcon(
                        AppGlyphs.picker,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      Text(
                        'SelectionSheet',
                        style: AppTextStyle.title3.of(
                          context,
                          emphasized: true,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '带搜索的分段选择器。单选用「选中即返回」，多选用「勾完确认」——'
                    '两种回调分开，调用方不用自己判断模式。',
                    style: context.listSubtitleStyle.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          generateSection(
            title: '两种模式',
            items: [
              ListItem(
                title: const Text('单选'),
                subtitle: Text(single ?? '尚未选择'),
                leading: const GlyphIcon(AppGlyphs.checkCircle),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: _pickSingle,
              ),
              ListItem(
                title: const Text('多选'),
                subtitle: Text(
                  _multi.isEmpty ? '尚未选择' : '已选 ${_multi.length} 项',
                ),
                leading: const GlyphIcon(AppGlyphs.checkDouble),
                trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 20),
                onTap: _pickMulti,
              ),
            ],
            footer: '搜索框在段数或条目较多时自动出现；这里固定显示，便于试验。',
          ),
          if (_multi.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final label in _multi) CommonChip(label: label),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
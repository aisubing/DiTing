/// 键值编辑器演示页（`/form/map-edit`）。
///
/// 把 `MapEditView` 装进页面：顶部是当前键值对的实时摘要，下面是编辑器本体。
/// 页脚的「保存」会先做一次重复键检查——这正是 `MapEditView` 把去重留给调用
/// 方的原因：不同页面去重策略不同（覆盖 / 保留第一个 / 报错）。
library;

import 'package:diting/data/mock_forms.dart';
import 'package:diting/pages/forms/custom_issue.dart';
import 'package:diting/pages/forms/map_edit_view.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 键值编辑器演示页。
class MapEditDemoPage extends StatefulWidget {
  const MapEditDemoPage({super.key});

  @override
  State<MapEditDemoPage> createState() => _MapEditDemoPageState();
}

class _MapEditDemoPageState extends State<MapEditDemoPage> {
  late final _entries = [
    for (final entry in mockMapEntries.entries)
      MapEntryDraft(key: entry.key, value: entry.value),
  ];

  var _issues = <String>[];

  List<String> _findIssues() {
    final issues = <String>[];
    final seen = <String>{};
    for (final entry in _entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        issues.add(
          '有 ${_entries.where((e) => e.key.trim().isEmpty).length} 个空键',
        );
        break;
      }
      if (!seen.add(key)) {
        issues.add('键「$key」重复');
      }
    }
    final badValues = _entries.where((e) => e.value.trim().isEmpty).length;
    if (badValues > 0) {
      issues.add('有 $badValues 个键没有值');
    }
    return issues;
  }

  void _save() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final issues = _findIssues();
    setState(() => _issues = issues);
    if (issues.isNotEmpty) {
      return;
    }
    messenger?.showSnackBar(
      SnackBar(
        content: Text('已保存 ${_entries.length} 个键值对（演示：不落盘）'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '键值编辑器',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存',
        onPressed: _save,
      ),
      body: PageBody(
        dockSpacer: false,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      GlyphIcon(
                        AppGlyphs.key,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      Expanded(
                        child: Text(
                          '键值编辑器',
                          style: AppTextStyle.title3.of(
                            context,
                            emphasized: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '用于 DNS 覆写、自定义参数这类「一串键配一串值」的配置。'
                    '每行可单独编辑，也可以从下面粘贴一整段。',
                    style: context.listSubtitleStyle.copyWith(height: 1.6),
                  ),
                  Text(
                    '当前 ${_entries.length} 项',
                    style: context.listCaptionStyle.copyWith(
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_issues.isNotEmpty) CustomIssuesBanner(issues: _issues),
          MapEditView(
            entries: _entries,
            title: '参数',
            keyHint: '键',
            valueHint: '值',
            footer: '键名区分大小写',
            onChanged: (_) => setState(() => _issues = const []),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TonalButton(
              label: '保存',
              glyph: AppGlyphs.check,
              size: TonalButtonSize.section,
              onPressed: _save,
            ),
          ),
          ListFooter(
            text:
                '保存前会检查空键、重复键与空值；这三类问题在真实配置里都会让'
                '内核拒绝启动，所以放在 UI 层先拦。',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

import 'package:diting/data/mock_data.dart';
import 'package:diting/state/rules_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Batch import: one large text field, live parse counts, one submit button. No file
/// picker: the demo has no filesystem permission and real usage mostly pastes copied rules.
class BatchEditorPage extends ConsumerStatefulWidget {
  const BatchEditorPage({super.key});

  @override
  ConsumerState<BatchEditorPage> createState() => _BatchEditorPageState();
}

class _BatchEditorPageState extends ConsumerState<BatchEditorPage> {
  final _controller = TextEditingController();

  /// Target table. Defaults to block, since most bulk imports are block rules.
  var _kind = RuleKind.block;

  @override
  void initState() {
    super.initState();
    // Listen to the controller rather than using onChanged: paste, undo and the clear
    // button all bypass onChanged but still notify the controller.
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  RuleLineParseResult get _parsed => parseRuleLines(
    _controller.text,
    existing: {
      for (final rule in ref.read(rulesOfKindProvider(_kind))) rule.pattern,
    },
  );

  Future<void> _submit() async {
    final parsed = _parsed;
    if (parsed.accepted.isEmpty) {
      return;
    }
    final count = await ref
        .read(rulesProvider.notifier)
        .importRules(_kind, parsed.accepted);
    _controller.clear();
    if (!mounted) {
      return;
    }
    await showFloatingDialog<void>(
      context: context,
      child: CommonDialog(
        title: '导入完成',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(UiLocalizations.of(context).submit),
          ),
        ],
        child: Text(_reportText(count: count, parsed: parsed)),
      ),
    );
    if (!mounted) {
      return;
    }
    // Leave once imported: the user came only to paste a block of rules.
    context.pop();
  }

  String _reportText({
    required int count,
    required RuleLineParseResult parsed,
  }) {
    final lines = <String>['已向${_kind.title}导入 $count 条规则。'];
    if (parsed.duplicated.isNotEmpty) {
      lines.add('跳过 ${parsed.duplicated.length} 条重复规则。');
    }
    if (parsed.rejected.isNotEmpty) {
      lines.add(
        '${parsed.rejected.length} 条放行规则（含 #@#）未导入：'
        '该规则为放行规则，请在白名单中添加。',
      );
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final colorScheme = context.colorScheme;
    final canSubmit = parsed.accepted.isNotEmpty;

    return CommonScaffold(
      title: '批量添加规则',
      resizeToAvoidBottomInset: true,
      // The app bar floats over the body, so the body reserves status bar plus toolbar
      // height or the section header would be drawn underneath it.
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8 + context.appBarInset, 16, 16),
        children: [
          // Target table above the text field: pick where first, then paste.
          // padding is zero because this ListView already pads 16 horizontally.
          generateSection(
            padding: EdgeInsets.zero,
            title: '导入到',
            items: [
              ListItem<RuleKind>.options(
                title: const Text('目标规则表'),
                subtitle: const Text('导入的规则将写入所选规则表'),
                options: RuleKind.values,
                value: _kind,
                textBuilder: (kind) => kind.title,
                onChanged: (kind) => setState(() => _kind = kind),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fixed height 360 shows a screenful without pushing the button off-screen.
          // borderRadius must be explicit: FilledInputTheme defaults to AppRadius.full.
          SizedBox(
            height: 360,
            child: FilledInputTheme(
              borderRadius: AppRadius.lg,
              child: TextField(
                controller: _controller,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontFamily: appMonospaceFontFamily,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText:
                      '每行一条规则，例如：\n||ads.example.com^\n'
                      '||tracker.example.net^\n\n'
                      '空行会被忽略，重复规则自动跳过。',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Parse counts sit right under the text field: they explain the pasted content,
          // and the further away they are the less they look related to it.
          CommonCard(
            child: StatStrip(
              stats: [
                StatItem(
                  label: '可导入',
                  value: '${parsed.accepted.length}',
                  color: colorScheme.success,
                ),
                StatItem(
                  label: '重复',
                  value: '${parsed.duplicated.length}',
                  color: colorScheme.warning,
                ),
                StatItem(
                  label: '无效',
                  value: '${parsed.rejected.length}',
                  color: parsed.rejected.isEmpty
                      ? null
                      : colorScheme.destructive,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Submit sits at the end of the body, not the app bar: the item count is the last
          // confirmation point before the user commits, and an icon cannot show it.
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: canSubmit ? _submit : null,
              child: Text('导入 ${parsed.accepted.length} 条'),
            ),
          ),
          if (parsed.rejected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CommonCard(
                isError: true,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          GlyphIcon(
                            AppGlyphs.warning,
                            size: 16,
                            color: colorScheme.error,
                          ),
                          Text('以下规则未通过校验', style: context.listTitleStyle),
                        ],
                      ),
                      for (final line in parsed.rejected.take(5))
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.listCaptionStyle.copyWith(
                            fontFamily: appMonospaceFontFamily,
                          ),
                        ),
                      Text(
                        '该规则为放行规则，请在白名单中添加',
                        style: context.listCaptionStyle.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (parsed.duplicated.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: CommonCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text('已存在，将跳过', style: context.listTitleStyle),
                      for (final line in parsed.duplicated.take(3))
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.listCaptionStyle.copyWith(
                            fontFamily: appMonospaceFontFamily,
                          ),
                        ),
                      if (parsed.duplicated.length > 3)
                        Text(
                          '等 ${parsed.duplicated.length} 条',
                          style: context.listCaptionStyle,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          const DockSpacer(),
        ],
      ),
    );
  }
}
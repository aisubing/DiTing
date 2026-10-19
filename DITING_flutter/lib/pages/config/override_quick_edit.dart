part of 'override_spec_page.dart';

/// 快速编辑：把已选中的键导出成一段 YAML，改完再写回。
///
/// 上游打开的是完整的 YAML 编辑器（`pages/editor.dart`，1,260 行，含补全与
/// 高亮）；演示层用一段等宽多行文本代替，只解析 `key: value` 一种形式。这样
/// 保留「一次改多项」的能力，又不把编辑器整个搬进来。
Future<void> showOverrideQuickEdit(
  BuildContext context,
  MockOverrideSpec spec,
) => showFormSheet<void>(
  context: context,
  builder: (_) => _OverrideQuickEditSheet(spec: spec),
);

class _OverrideQuickEditSheet extends ConsumerStatefulWidget {
  const _OverrideQuickEditSheet({required this.spec});

  final MockOverrideSpec spec;

  @override
  ConsumerState<_OverrideQuickEditSheet> createState() =>
      _OverrideQuickEditSheetState();
}

class _OverrideQuickEditSheetState
    extends ConsumerState<_OverrideQuickEditSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: _dump(),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 把选中的键按 `key: value` 导出；列表值写成 YAML 行内数组。
  String _dump() {
    final state = ref.read(overrideProvider)[widget.spec.id];
    if (state == null) {
      return '';
    }
    final lines = <String>[];
    for (final entry in widget.spec.allKeys) {
      if (!state.picked.contains(entry.key)) {
        continue;
      }
      final value = state.values[entry.key] ?? entry.value;
      if (entry.kind == OverrideFieldKind.list) {
        final items = splitOverrideList(value);
        lines.add('${entry.key}: [${items.join(', ')}]');
      } else {
        lines.add('${entry.key}: $value');
      }
    }
    return lines.join('\n');
  }

  /// 解析并写回。
  ///
  /// 认不出的键跳过而不是报错：这些键来自用户自己的编辑，写错一个不该让整段
  /// 改动作废；认出来的照样生效，并在提示条里报出跳过的行数。
  void _apply() {
    final notifier = ref.read(overrideProvider.notifier);
    final known = {for (final entry in widget.spec.allKeys) entry.key: entry};
    var applied = 0;
    var skipped = 0;
    for (final line in _controller.text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }
      final colon = trimmed.indexOf(':');
      if (colon <= 0) {
        skipped++;
        continue;
      }
      final key = trimmed.substring(0, colon).trim();
      var value = trimmed.substring(colon + 1).trim();
      final entry = known[key];
      if (entry == null) {
        skipped++;
        continue;
      }
      if (entry.kind == OverrideFieldKind.list) {
        final open = value.indexOf('[');
        final close = value.lastIndexOf(']');
        if (open == 0 && close > open) {
          value = value
              .substring(open + 1, close)
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .join('\n');
        }
      }
      notifier.setValue(widget.spec.id, key, value);
      applied++;
    }
    if (!mounted) {
      return;
    }
    showConfigHint(
      context,
      skipped == 0 ? '已更新 $applied 项' : '已更新 $applied 项，跳过 $skipped 行',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '快速编辑',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '应用改动',
        onPressed: _apply,
      ),
      body: ListView(
        controller: sheetScrollController(context),
        padding: const EdgeInsets.only(top: 8),
        children: [
          ConfigNoteCard(
            text:
                '只列出当前已选的键。每行一条 `${'key'}: ${'value'}`，'
                '列表用方括号包裹；改完点右上角的应用。',
            glyph: AppGlyphs.code,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: FilledInputTheme(
              child: TextField(
                controller: _controller,
                maxLines: null,
                minLines: 12,
                keyboardType: TextInputType.multiline,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(fontFamily: 'JetBrainsMono'),
                decoration: const InputDecoration(
                  hintText: 'mtu: 1500',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '认不出的键会被跳过，不会影响已识别的条目。',
              style: context.listCaptionStyle,
            ),
          ),
          SizedBox(height: NavigationDock.insetOf(context)),
        ],
      ),
    );
  }
}

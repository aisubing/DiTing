part of 'scripts_page.dart';

/// 打开脚本编辑面板；[existing] 为空表示新增。
Future<void> showScriptEditor(
  BuildContext context,
  WidgetRef ref, {
  MockScript? existing,
}) => showFormSheet<void>(
  context: context,
  builder: (_) => _ScriptEditorSheet(existing: existing),
);

class _ScriptEditorSheet extends ConsumerStatefulWidget {
  const _ScriptEditorSheet({this.existing});

  final MockScript? existing;

  @override
  ConsumerState<_ScriptEditorSheet> createState() => _ScriptEditorSheetState();
}

class _ScriptEditorSheetState extends ConsumerState<_ScriptEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _code = TextEditingController(
    text:
        widget.existing?.code ?? 'function main(config) {\n  return config;\n}',
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final script = MockScript(
      name: _name.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      code: _code.text,
      fromUrl: widget.existing?.fromUrl ?? false,
    );
    final ok = ref
        .read(configResourcesProvider.notifier)
        .putScript(widget.existing?.name, script);
    if (!ok) {
      showConfigHint(context, '已有同名脚本「${script.name}」');
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: widget.existing == null ? '添加脚本' : '编辑脚本',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存脚本',
        onPressed: _submit,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: sheetScrollController(context),
          padding: EdgeInsets.only(top: 8 + context.contentTopPadding),
          children: [
            generateSection(
              items: [
                ConfigFieldRow(
                  label: '名称',
                  child: TextFormField(
                    controller: _name,
                    autofocus: widget.existing == null,
                    inputFormatters: TextInputLimits.limit(
                      TextInputLimits.name,
                    ),
                    decoration: const InputDecoration(hintText: '如：广告域名清理'),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) {
                        return '名称不能为空';
                      }
                      if (text.contains(' ')) {
                        return '名称不能包含空格';
                      }
                      return null;
                    },
                  ),
                ),
                ConfigFieldRow(
                  label: '说明',
                  child: TextFormField(
                    controller: _description,
                    inputFormatters: TextInputLimits.limit(
                      TextInputLimits.name,
                    ),
                    decoration: const InputDecoration(
                      hintText: '一句话说明这个脚本做什么（可留空）',
                    ),
                  ),
                ),
              ],
              footer: widget.existing?.fromUrl ?? false
                  ? '这个脚本来自远程地址：本地改动会在下次同步时被覆盖。'
                  : '名称在列表里唯一；改名不会影响脚本内容。',
            ),
            generateSection(
              title: '代码',
              items: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: FilledInputTheme(
                    child: TextFormField(
                      controller: _code,
                      maxLines: null,
                      minLines: 14,
                      keyboardType: TextInputType.multiline,
                      autocorrect: false,
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(fontFamily: 'JetBrainsMono'),
                      decoration: const InputDecoration(
                        hintText: 'function main(config) { ... }',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = value ?? '';
                        if (text.trim().isEmpty) {
                          return '代码不能为空';
                        }
                        if (!text.contains('main')) {
                          return '脚本必须定义 main(config) 函数';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ],
              footer:
                  '必须定义 main(config) 并返回配置对象；'
                  '抛错时内核会退回未修改的配置。',
            ),
            SizedBox(height: NavigationDock.insetOf(context)),
          ],
        ),
      ),
    );
  }
}

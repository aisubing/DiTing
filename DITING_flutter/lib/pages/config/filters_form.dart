part of 'filters_page.dart';

/// 打开过滤器表单；[existing] 为空表示新增。
Future<void> showFilterForm(
  BuildContext context,
  WidgetRef ref, {
  MockFilter? existing,
}) => showFormSheet<void>(
  context: context,
  builder: (_) => _FilterFormSheet(existing: existing),
);

class _FilterFormSheet extends ConsumerStatefulWidget {
  const _FilterFormSheet({this.existing});

  final MockFilter? existing;

  @override
  ConsumerState<_FilterFormSheet> createState() => _FilterFormSheetState();
}

class _FilterFormSheetState extends ConsumerState<_FilterFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.existing?.label ?? '');
  late final _regex = TextEditingController(text: widget.existing?.regex ?? '');

  @override
  void dispose() {
    _label.dispose();
    _regex.dispose();
    super.dispose();
  }

  /// 正则本身不试跑（演示层没有真实的日志流），但用 Dart 的 `RegExp` 做一次
  /// 语法校验：写错一个括号在这里就该被拦下，而不是等日志页静默不匹配。
  String? _validateRegex(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return '正则不能为空';
    }
    try {
      RegExp(text);
    } on FormatException catch (error) {
      return '正则无法解析：${error.message}';
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final filter = MockFilter(
      label: _label.text.trim(),
      regex: _regex.text.trim(),
    );
    final notifier = ref.read(configResourcesProvider.notifier);
    final ok = widget.existing == null
        ? notifier.addFilter(filter)
        : notifier.updateFilter(widget.existing!.label, filter);
    if (!ok) {
      // 重名不关面板：用户刚打的字要留在框里改。
      showConfigHint(context, '名称「${filter.label}」已存在');
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: widget.existing == null ? '添加过滤器' : '编辑过滤器',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存过滤器',
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
                    controller: _label,
                    autofocus: widget.existing == null,
                    inputFormatters: TextInputLimits.limit(
                      TextInputLimits.name,
                    ),
                    decoration: const InputDecoration(hintText: '如：遥测上报'),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? '名称不能为空' : null,
                  ),
                ),
                ConfigFieldRow(
                  label: '正则',
                  hint: '示例：(?i)hk|hong\\s*kong',
                  child: TextFormField(
                    controller: _regex,
                    autocorrect: false,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontFamily: 'JetBrainsMono'),
                    inputFormatters: TextInputLimits.limit(
                      TextInputLimits.filter,
                    ),
                    decoration: const InputDecoration(
                      hintText: r'/v\d+/(analytics|telemetry)',
                    ),
                    validator: _validateRegex,
                  ),
                ),
              ],
              footer: '过滤器只影响展示，不会改变任何连接的走向。',
            ),
            SizedBox(height: NavigationDock.insetOf(context)),
          ],
        ),
      ),
    );
  }
}

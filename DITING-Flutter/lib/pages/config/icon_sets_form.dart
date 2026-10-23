part of 'icon_sets_page.dart';

/// Open the icon set form; an empty [existing] means a new set.
Future<void> showIconSetForm(
  BuildContext context,
  WidgetRef ref, {
  MockIconSet? existing,
}) => showFormSheet<void>(
  context: context,
  builder: (_) => _IconSetFormSheet(existing: existing),
);

class _IconSetFormSheet extends ConsumerStatefulWidget {
  const _IconSetFormSheet({this.existing});

  final MockIconSet? existing;

  @override
  ConsumerState<_IconSetFormSheet> createState() => _IconSetFormSheetState();
}

class _IconSetFormSheetState extends ConsumerState<_IconSetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _url = TextEditingController(text: widget.existing?.url ?? '');
  late final _icons = TextEditingController(
    text: (widget.existing?.icons ?? const <String>[]).join('\n'),
  );

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _icons.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final icons = [
      for (final line in _icons.text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    final iconSet = MockIconSet(
      name: _name.text.trim(),
      url: _url.text.trim(),
      icons: icons,
      fromUrl: widget.existing?.fromUrl ?? true,
    );
    ref
        .read(configResourcesProvider.notifier)
        .putIconSet(widget.existing?.name, iconSet);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: widget.existing == null ? '添加图标集' : '编辑图标集',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存图标集',
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
                    decoration: const InputDecoration(hintText: '如：地区旗帜'),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? '名称不能为空' : null,
                  ),
                ),
                ConfigFieldRow(
                  label: '地址',
                  child: TextFormField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontFamily: 'JetBrainsMono'),
                    decoration: const InputDecoration(
                      hintText: 'https://icons.example.com/flags.json',
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) {
                        return '地址不能为空';
                      }
                      if (!text.startsWith('http')) {
                        return '需以 http 开头';
                      }
                      return null;
                    },
                  ),
                ),
              ],
              footer: '地址指向一份 `{ "图标名": "图片地址" }` 形式的 JSON。',
            ),
            generateSection(
              title: '图标名',
              items: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: FilledInputTheme(
                    child: TextFormField(
                      controller: _icons,
                      maxLines: null,
                      minLines: 6,
                      autocorrect: false,
                      keyboardType: TextInputType.multiline,
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(fontFamily: 'JetBrainsMono'),
                      decoration: const InputDecoration(
                        hintText: 'flag-cn\nflag-hk\nflag-jp',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          [
                            for (final line in (value ?? '').split('\n'))
                              if (line.trim().isNotEmpty) line.trim(),
                          ].isEmpty
                          ? '至少填一个图标名'
                          : null,
                    ),
                  ),
                ),
              ],
              footer: '一行一个图标名；预览页按这里的顺序铺成网格。',
            ),
            SizedBox(height: NavigationDock.insetOf(context)),
          ],
        ),
      ),
    );
  }
}
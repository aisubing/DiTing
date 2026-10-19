part of 'add_profile_page.dart';

/// 添加档案的表单面板。
///
/// 用 `showFormSheet` + `CommonScaffold` 而不是对话框：字段有三四个，其中
/// 「自动更新周期」是一个选项行，对话框在键盘弹起后会被压到只剩一行，而面板
/// 自带滚动与「取消 / 保存」工具栏。
class _ProfileFormSheet extends ConsumerStatefulWidget {
  const _ProfileFormSheet({required this.source, required this.title});

  final AddProfileSource source;
  final String title;

  @override
  ConsumerState<_ProfileFormSheet> createState() => _ProfileFormSheetState();
}

class _ProfileFormSheetState extends ConsumerState<_ProfileFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  var _autoUpdate = AutoUpdateInterval.hours12;
  var _userAgent = mockUserAgents.first;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final notifier = ref.read(profilesProvider.notifier);
    final source = widget.source;
    final isFile = source == AddProfileSource.file;
    final id = notifier.add(
      name: _name.text.isEmpty ? _defaultName() : _name.text,
      kind: source.kind,
      url: isFile ? '' : _address.text,
      fileName: isFile ? _fileNameOf(_address.text) : '',
      fileSize: isFile ? '—' : '',
      autoUpdate: source.kind.isRemote ? _autoUpdate : AutoUpdateInterval.off,
      userAgent: _userAgent,
    );
    // 先取好 router 再关面板：面板一关，它的 context 就失效了。
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    if (source == AddProfileSource.manual) {
      // 手动创建出来的档案下一步必然是去加节点，直接把自定义配置页推出去，
      // 否则用户会停在网格里找不到入口。
      router.push(ProfilesPaths.customOf(id));
    }
  }

  String _defaultName() => switch (widget.source) {
    AddProfileSource.link => '远程订阅',
    AddProfileSource.file => _fileNameOf(_address.text),
    AddProfileSource.manual => '未命名档案',
  };

  String _fileNameOf(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return '未命名文件';
    }
    final segments = trimmed.split(RegExp(r'[/\\]'));
    return segments.isEmpty ? trimmed : segments.last;
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    return CommonScaffold(
      title: widget.title,
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存档案',
        onPressed: _submit,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: sheetScrollController(context),
          padding: const EdgeInsets.only(top: 8),
          children: [
            generateSection(
              title: '档案信息',
              items: [
                _FieldRow(
                  label: '名称',
                  child: TextFormField(
                    controller: _name,
                    autofocus: true,
                    decoration: InputDecoration(hintText: _defaultName()),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.length > 24) {
                        return '名称最多 24 个字符';
                      }
                      return null;
                    },
                  ),
                ),
                if (source.needsAddress)
                  _FieldRow(
                    label: source.fieldLabel,
                    child: TextFormField(
                      controller: _address,
                      keyboardType: source == AddProfileSource.link
                          ? TextInputType.url
                          : TextInputType.text,
                      style: const TextStyle(fontFamily: 'JetBrainsMono'),
                      decoration: InputDecoration(hintText: source.hint),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) {
                          return '${source.fieldLabel}不能为空';
                        }
                        if (source == AddProfileSource.link &&
                            !text.startsWith('http')) {
                          return '订阅地址需以 http 开头';
                        }
                        return null;
                      },
                    ),
                  ),
              ],
            ),
            if (source.kind.isRemote)
              generateSection(
                title: '更新',
                items: [
                  ListItem<AutoUpdateInterval>.options(
                    title: const Text('自动更新'),
                    subtitle: const Text('拉取新版本后节点与规则一起替换'),
                    options: AutoUpdateInterval.values
                        .where((item) => item != AutoUpdateInterval.off)
                        .toList(),
                    value: _autoUpdate,
                    textBuilder: (interval) => interval.label,
                    onChanged: (interval) =>
                        setState(() => _autoUpdate = interval),
                  ),
                  ListItem<String>.options(
                    title: const Text('User-Agent'),
                    subtitle: const Text('少数服务商会按 UA 返回不同配置'),
                    options: mockUserAgents,
                    value: _userAgent,
                    textBuilder: (agent) => agent,
                    onChanged: (agent) => setState(() => _userAgent = agent),
                  ),
                ],
              ),
            if (source == AddProfileSource.manual)
              generateSection(
                title: '接下来',
                items: const [
                  ListItem(
                    leading: GlyphIcon(AppGlyphs.layers),
                    title: Text('节点与组'),
                    subtitle: Text('保存后进入自定义配置，按需添加'),
                  ),
                  ListItem(
                    leading: GlyphIcon(AppGlyphs.rules),
                    title: Text('规则'),
                    subtitle: Text('也可以先从一份规则模板开始'),
                  ),
                ],
              ),
            ListFooter(
              text: switch (source) {
                AddProfileSource.link => '保存后会立刻尝试拉取一次，失败时档案仍然保留。',
                AddProfileSource.file => '演示版不读取真实文件，只记录文件名与大小。',
                AddProfileSource.manual => '空白档案没有任何节点，需要自己去添加。',
              },
            ),
            SizedBox(height: NavigationDock.insetOf(context)),
          ],
        ),
      ),
    );
  }
}

/// 表单行：左标签 + 右输入框。
///
/// 不复用 `ListItem.input` 是因为那个自带一个点击弹出的对话框，而这里是面板内
/// 联编辑，行为完全不同。
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        spacing: 12,
        children: [
          SizedBox(
            width: 76,
            child: Text(label, style: context.listTitleStyle),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

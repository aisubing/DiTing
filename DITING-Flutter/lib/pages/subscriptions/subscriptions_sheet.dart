part of 'subscriptions_page.dart';

/// Add-subscription sheet. Grouped cards rather than a label column: the two fields need the full
/// width, and the mirror templates the legacy app offered were missing here. Saving inserts with
/// `importState = importing`, then a real download settles it.
class _AddSubscriptionSheet extends ConsumerStatefulWidget {
  const _AddSubscriptionSheet();

  @override
  ConsumerState<_AddSubscriptionSheet> createState() =>
      _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends ConsumerState<_AddSubscriptionSheet> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  var _kind = SubscriptionKind.domain;

  /// Remote subscriptions download a URL; local ones import a picked `.txt` through a
  /// persisted SAF grant, so the address field is replaced by a file row.
  var _sourceType = SubscriptionSourceType.remote;
  var _picking = false;
  String? _localUri;
  String? _localName;

  /// Blocks submission; `_localWarning` only warns about a grant that will not survive.
  String? _formError;
  String? _localWarning;
  int? _groupId;

  /// Mirror acceleration, as the legacy form: a switch, one saved template and fallback.
  var _useMirror = false;
  String? _mirrorTemplate;
  var _mirrorFallback = true;
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    // The mirror preview follows the address while it is typed.
    _url.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _url.removeListener(_rebuild);
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_picking) {
      return;
    }
    setState(() {
      _picking = true;
      _formError = null;
      _localWarning = null;
    });
    final picked = await ref
        .read(subscriptionFileReaderProvider)
        .pickPersistableTextFile();
    if (!mounted) {
      return;
    }
    setState(() {
      _picking = false;
      if (picked.cancelled) {
        return;
      }
      if (picked.error != null) {
        _formError = picked.error;
        return;
      }
      final name = picked.displayName;
      if (!name.toLowerCase().endsWith('.txt')) {
        _formError = '请选择扩展名为 .txt 的规则文件';
        return;
      }
      _localUri = picked.uri;
      _localName = name;
      // Prefill the name so the row is identifiable without typing.
      if (_name.text.trim().isEmpty) {
        _name.text = name.substring(0, name.length - 4);
      }
      if (!picked.persisted) {
        _localWarning = '系统未授予长期读取权限，更新时需要重新选择文件';
      }
    });
  }

  Future<void> _createGroup() async {
    final name = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: '新建分组',
        value: '',
        validator: (value) => (value ?? '').trim().isEmpty ? '分组名称不能为空' : null,
      ),
    );
    if (name == null || !mounted) {
      return;
    }
    final id = await ref.read(subscriptionActionsProvider).createGroup(name);
    if (id == null || !mounted) {
      return;
    }
    setState(() => _groupId = id);
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final isLocal = _sourceType == SubscriptionSourceType.local;
    final error = isLocal
        ? (_localUri == null ? '请选择一个规则文件' : null)
        : validateSubscriptionUrl(_url.text);
    if (error != null) {
      setState(() => _formError = error);
      return;
    }
    setState(() {
      _submitting = true;
      _formError = null;
    });
    final result = await ref
        .read(subscriptionActionsProvider)
        .add(
          name: _name.text,
          url: isLocal ? (_localUri ?? '') : _url.text,
          kind: _kind,
          groupId: _groupId,
          mirrorTemplate: isLocal || !_useMirror ? null : _mirrorTemplate,
          mirrorFallback: _mirrorFallback,
          sourceType: _sourceType,
        );
    if (!mounted) {
      return;
    }
    switch (result) {
      case AddSubscriptionFailure(:final message):
        setState(() => _submitting = false);
        // A duplicate address keeps the sheet open so the pasted text stays editable.
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 2600),
          ),
        );
      case AddSubscriptionOk(:final id):
        // Start the download before closing so the list spins as the sheet disappears.
        final updated = ref.read(subscriptionUpdateProvider.notifier);
        Navigator.of(context).pop();
        await updated.updateOne(id);
    }
  }

  /// The saved template [record] points at, if it is still in the list.
  MirrorTemplateRecord? _selectedTemplate(
    List<MirrorTemplateRecord> templates,
  ) => templates.where((row) => row.template == _mirrorTemplate).firstOrNull;

  /// What the mirror would request, or null while the address is empty or malformed.
  String? _mirrorPreview(MirrorTemplateRecord? template) {
    final address = _url.text.trim();
    if (template == null || address.isEmpty) {
      return null;
    }
    try {
      return buildMirrorUrl(template.template, address);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(subscriptionGroupsProvider).value ?? const [];
    final templates =
        ref.watch(mirrorTemplatesProvider).value ??
        const <MirrorTemplateRecord>[];
    final selectedGroup = groups.any((group) => group.id == _groupId)
        ? _groupId
        : null;
    final isLocal = _sourceType == SubscriptionSourceType.local;
    final template = _selectedTemplate(templates);

    return CommonScaffold(
      title: '添加订阅',
      isLoading: _submitting,
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存订阅',
        onPressed: _submitting ? null : _submit,
      ),
      body: ListView(
        controller: sheetScrollController(context),
        padding: EdgeInsets.only(
          top: 8 + context.contentTopPadding,
          bottom: 24,
        ),
        children: [
          _SheetCard(
            title: '订阅信息',
            footer: isLocal
                ? '本地文件通过系统文件选择器读取，应用只保留读取权限；'
                      '同名的黑白名单与 hosts 订阅互不影响。'
                : '同一条链接可以为黑白名单和 hosts 各建一条订阅（唯一性按「链接 + 类型」判定），'
                      '保存后会立即下载一次正文并写入规则库。',
            children: [
              ListItem<SubscriptionSourceType>.options(
                padding: EdgeInsets.zero,
                title: const Text('订阅方式'),
                subtitle: Text(isLocal ? '从存储中选择一个 .txt 文件' : '从网络地址下载规则正文'),
                options: SubscriptionSourceType.values,
                value: _sourceType,
                textBuilder: (type) => type.label,
                onChanged: (type) => setState(() {
                  _sourceType = type;
                  _formError = null;
                  _localWarning = null;
                }),
              ),
              if (isLocal) ...[
                ListItem(
                  padding: EdgeInsets.zero,
                  leading: const GlyphIcon(AppGlyphs.importFile, size: 20),
                  title: Text(_localName ?? '选择规则文件'),
                  subtitle: Text(
                    _localName == null ? '仅支持 .txt，点击从存储中选择' : '点击可重新选择文件',
                  ),
                  trailing: TonalButton(
                    size: TonalButtonSize.compact,
                    label: _localName == null ? '选择' : '更换',
                    onPressed: _picking ? null : _pickFile,
                  ),
                  onTap: _picking ? null : _pickFile,
                ),
                _SheetField(label: '名称（可选）', child: _nameField('留空则取文件名')),
              ] else ...[
                _SheetField(
                  label: '订阅地址',
                  child: FilledInputTheme(
                    borderRadius: AppRadius.md,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: TextFormField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        fontFamily: appMonospaceFontFamily,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'https://example.com/rules.txt',
                      ),
                    ),
                  ),
                ),
                _SheetField(label: '名称（可选）', child: _nameField('留空则取链接末段')),
              ],
              if (_formError case final message?)
                InlineNotice(
                  message: message,
                  glyph: AppGlyphs.error,
                  color: context.colorScheme.errorContainer,
                  foregroundColor: context.colorScheme.onErrorContainer,
                ),
              if (_localWarning case final warning?)
                InlineNotice(message: warning),
            ],
          ),
          if (!isLocal)
            _mirrorCard(
              templates: templates,
              selected: template,
              preview: _mirrorPreview(template),
            ),
          _SheetCard(
            title: '规则类型',
            children: [
              ListItem<SubscriptionKind>.options(
                padding: EdgeInsets.zero,
                title: const Text('收录类型'),
                subtitle: Text(
                  _kind == SubscriptionKind.hosts
                      ? '仅导入 hosts 地址与 CNAME 覆写规则'
                      : '导入域名规则与黑白名单',
                ),
                options: SubscriptionKind.values,
                value: _kind,
                textBuilder: (kind) => kind.displayName,
                onChanged: (kind) => setState(() => _kind = kind),
              ),
              _SheetField(
                label: '所属分组',
                hint: '分组只影响订阅页的筛选与批量更新，可稍后调整。',
                child: ChipRow(
                  children: [
                    FilterPill(
                      label: SubscriptionEntry.ungroupedLabel,
                      selected: selectedGroup == null,
                      onPressed: () => setState(() => _groupId = null),
                    ),
                    for (final group in groups)
                      FilterPill(
                        label: group.name,
                        selected: group.id == selectedGroup,
                        onPressed: () => setState(() => _groupId = group.id),
                      ),
                    TonalChip(
                      label: '+ 新建',
                      color: context.raisedSurfaceLevel.colorOf(
                        context.colorScheme,
                      ),
                      foregroundColor: context.colorScheme.onSurfaceVariant,
                      onPressed: _createGroup,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nameField(String hintText) {
    return FilledInputTheme(
      borderRadius: AppRadius.md,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: TextFormField(
        controller: _name,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: hintText),
      ),
    );
  }

  Widget _mirrorCard({
    required List<MirrorTemplateRecord> templates,
    required MirrorTemplateRecord? selected,
    required String? preview,
  }) {
    // Without a saved template there is nothing to switch on, so the card points at the
    // management page instead of offering a dead toggle.
    if (templates.isEmpty) {
      return _SheetCard(
        title: '镜像加速',
        footer: '镜像地址会把原始订阅地址改写成镜像前缀，常用于加速 GitHub 等慢速源。',
        children: [
          ListItem(
            padding: EdgeInsets.zero,
            leading: const GlyphIcon(AppGlyphs.layers, size: 20),
            title: const Text('添加镜像站模板'),
            subtitle: const Text('还没有模板，先去保存一个常用的镜像前缀'),
            trailing: const GlyphIcon(AppGlyphs.chevronForward, size: 18),
            onTap: () => context.push(HubPaths.mirrorTemplates),
          ),
        ],
      );
    }
    return _SheetCard(
      title: '镜像加速',
      footer: '下载时先请求镜像地址；镜像失败且开启回退时，再试原始地址。',
      children: [
        ListItem.toggle(
          padding: EdgeInsets.zero,
          leading: const GlyphIcon(AppGlyphs.bolt, size: 20),
          title: const Text('使用镜像站模板'),
          subtitle: const Text('订阅源较慢或被限速时，改写下载地址'),
          value: _useMirror,
          onChanged: (value) => setState(() {
            _useMirror = value;
            // Enabling with nothing chosen picks the newest template, so saving does not
            // silently drop the mirror the user just turned on.
            if (value && _mirrorTemplate == null) {
              _mirrorTemplate = templates.firstOrNull?.template;
            }
          }),
        ),
        if (_useMirror) ...[
          ListItem<MirrorTemplateRecord>.options(
            padding: EdgeInsets.zero,
            title: const Text('镜像模板'),
            subtitle: selected == null
                ? null
                : Text(
                    selected.template,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.listCaptionStyle.copyWith(
                      fontFamily: appMonospaceFontFamily,
                    ),
                  ),
            options: templates,
            value: selected ?? templates.first,
            textBuilder: (row) => row.name,
            onChanged: (row) => setState(() => _mirrorTemplate = row.template),
          ),
          if (preview != null) _PreviewBox(url: preview),
          ListItem.toggle(
            padding: EdgeInsets.zero,
            leading: const GlyphIcon(AppGlyphs.swap, size: 20),
            title: const Text('失败后回退直连'),
            subtitle: const Text('镜像请求失败时，改用原始订阅地址'),
            value: _mirrorFallback,
            onChanged: (value) => setState(() => _mirrorFallback = value),
          ),
        ],
      ],
    );
  }
}

/// A titled card in the add sheet: header, one grouped card, then an optional footer note.
class _SheetCard extends StatelessWidget {
  const _SheetCard({required this.title, required this.children, this.footer});

  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListHeader(title: title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CommonCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: children,
            ),
          ),
        ),
        if (footer != null) ListFooter(text: footer),
      ],
    );
  }
}

/// Label above a field; `FilledInputTheme` turns floating labels off, so this label lives outside.
class _SheetField extends StatelessWidget {
  const _SheetField({required this.label, required this.child, this.hint});

  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(label, style: context.listCaptionStyle),
        child,
        if (hint != null) Text(hint, style: context.listCaptionStyle),
      ],
    );
  }
}

/// The address a mirror template would request, in the field's own inset fill.
class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(context.colorScheme),
        shape: AppShape.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 2,
        children: [
          Text('实际请求地址', style: context.listCaptionStyle),
          Text(
            url,
            style: context.listCaptionStyle.copyWith(
              color: context.colorScheme.onSurface,
              fontFamily: appMonospaceFontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

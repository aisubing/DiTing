part of 'subscriptions_page.dart';

/// Add-subscription sheet: a sheet rather than a dialog because the four-field form would
/// be crushed once the keyboard opens. Saving inserts with `importState = importing`, then
/// a real download settles it.
class _AddSubscriptionSheet extends ConsumerStatefulWidget {
  const _AddSubscriptionSheet();

  @override
  ConsumerState<_AddSubscriptionSheet> createState() =>
      _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends ConsumerState<_AddSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _url = TextEditingController();
  var _kind = SubscriptionKind.domain;

  /// Remote subscriptions download a URL; local ones import a picked `.txt` through a
  /// persisted SAF grant, so the address field is replaced by a file row.
  var _sourceType = SubscriptionSourceType.remote;
  var _picking = false;
  String? _localUri;
  String? _localName;
  String? _localError;
  int? _groupId;
  var _submitting = false;

  @override
  void dispose() {
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
      _localError = null;
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
        _localError = picked.error;
        return;
      }
      final name = picked.displayName;
      if (!name.toLowerCase().endsWith('.txt')) {
        _localError = '请选择扩展名为 .txt 的规则文件';
        return;
      }
      _localUri = picked.uri;
      _localName = name;
      // Prefill the name so the row is identifiable without typing.
      if (_name.text.trim().isEmpty) {
        _name.text = name.substring(0, name.length - 4);
      }
      if (!picked.persisted) {
        _localError = '系统未授予长期读取权限，更新时需要重新选择文件';
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    if (_sourceType == SubscriptionSourceType.local) {
      if (_localUri == null) {
        setState(() => _localError ??= '请选择一个规则文件');
        return;
      }
    } else if (_formKey.currentState?.validate() != true) {
      return;
    }
    setState(() => _submitting = true);
    final result = await ref
        .read(subscriptionActionsProvider)
        .add(
          name: _name.text,
          url: _sourceType == SubscriptionSourceType.local
              ? (_localUri ?? '')
              : _url.text,
          kind: _kind,
          groupId: _groupId,
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

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(subscriptionGroupsProvider).value ?? const [];
    final selected = groups.any((group) => group.id == _groupId)
        ? _groupId
        : null;
    return CommonScaffold(
      title: '添加订阅',
      isLoading: _submitting,
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存订阅',
        onPressed: _submitting ? null : _submit,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: sheetScrollController(context),
          padding: EdgeInsets.only(top: 8 + context.contentTopPadding),
          children: [
            generateSection(
              title: '订阅来源',
              items: [
                ListItem<SubscriptionSourceType>.options(
                  title: const Text('来源类型'),
                  options: SubscriptionSourceType.values,
                  value: _sourceType,
                  textBuilder: (type) => type.label,
                  onChanged: (type) => setState(() {
                    _sourceType = type;
                    _localError = null;
                  }),
                ),
              ],
            ),
            generateSection(
              title: '订阅信息',
              items: [
                _FieldRow(
                  label: '名称',
                  child: TextFormField(
                    controller: _name,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: _sourceType == SubscriptionSourceType.local
                          ? '留空则取文件名'
                          : '留空则取链接末段',
                    ),
                  ),
                ),
                if (_sourceType == SubscriptionSourceType.local)
                  _FieldRow(
                    label: '规则文件',
                    child: Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: Text(
                            _localName ?? '未选择文件',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.listSubtitleStyle,
                          ),
                        ),
                        TonalButton(
                          size: TonalButtonSize.bar,
                          glyph: AppGlyphs.importFile,
                          label: _localName == null ? '选择' : '更换',
                          onPressed: _picking ? null : _pickFile,
                        ),
                      ],
                    ),
                  )
                else
                  _FieldRow(
                    label: '订阅地址',
                    child: TextFormField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      style: const TextStyle(fontFamily: 'JetBrainsMono'),
                      decoration: const InputDecoration(
                        hintText: 'https://example.com/rules.txt',
                      ),
                      validator: (value) => validateSubscriptionUrl(value ?? ''),
                    ),
                  ),
                if (_localError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Text(
                      _localError!,
                      style: context.listCaptionStyle.copyWith(
                        color: context.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            generateSection(
              title: '规则类型',
              items: [
                ListItem<SubscriptionKind>.options(
                  title: const Text('收录类型'),
                  options: SubscriptionKind.values,
                  value: _kind,
                  textBuilder: (kind) => kind.displayName,
                  onChanged: (kind) => setState(() => _kind = kind),
                ),
                ListItem<int?>.options(
                  title: const Text('所属分组'),
                  options: [null, for (final group in groups) group.id],
                  value: selected,
                  textBuilder: (id) => id == null
                      ? SubscriptionEntry.ungroupedLabel
                      : groups
                            .firstWhere(
                              (group) => group.id == id,
                              orElse: () => groups.first,
                            )
                            .name,
                  onChanged: (id) => setState(() => _groupId = id),
                ),
              ],
            ),
            ListFooter(
              text: _sourceType == SubscriptionSourceType.local
                  ? '本地文件通过系统的文件选择器读取，应用只保留读取权限；'
                        '同一个文件可以为黑白名单和 hosts 各建一条订阅（唯一性按「文件 + 类型」判定）。'
                        '保存后立即解析该文件并写入规则库，「更新」会重新读取同一个文件。'
                  : '同一条链接可以为黑白名单和 hosts 各建一条订阅（唯一性按「链接 + 类型」判定）。'
                        '保存后会立即下载一次正文，解析成规则并写入规则库。',
            ),
            const DockSpacer(),
          ],
        ),
      ),
    );
  }
}

/// `ListItem.input` is not reused: it opens a dialog on tap, unlike inline editing.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
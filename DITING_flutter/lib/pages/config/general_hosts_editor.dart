part of 'general_page.dart';

/// 添加一条 Hosts 记录。
Future<void> showHostEditor(BuildContext context, WidgetRef ref) async {
  final result = await showFloatingDialog<({String host, String address})>(
    context: context,
    child: const _HostEditorDialog(),
  );
  if (result == null || !context.mounted) {
    return;
  }
  final notifier = ref.read(generalConfigProvider.notifier);
  if (ref.read(generalConfigProvider).hosts.containsKey(result.host)) {
    showConfigHint(context, '「${result.host}」已存在，已更新解析');
  }
  notifier.putHost(result.host, result.address);
}

class _HostEditorDialog extends StatefulWidget {
  const _HostEditorDialog();

  @override
  State<_HostEditorDialog> createState() => _HostEditorDialogState();
}

class _HostEditorDialogState extends State<_HostEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _host = TextEditingController();
  final _address = TextEditingController();

  @override
  void dispose() {
    _host.dispose();
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    Navigator.of(context)
        .pop((host: _host.text.trim(), address: _address.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '添加 Hosts 记录',
      hasFields: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _submit, child: const Text('保存')),
      ],
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            TextFormField(
              controller: _host,
              autofocus: true,
              keyboardType: TextInputType.url,
              inputFormatters: TextInputLimits.limit(TextInputLimits.domain),
              decoration: const InputDecoration(hintText: '域名，如 router.lan'),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) {
                  return '域名不能为空';
                }
                if (text.contains(' ')) {
                  return '域名不能包含空格';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _address,
              keyboardType: TextInputType.url,
              inputFormatters: TextInputLimits.limit(TextInputLimits.hostValue),
              decoration: const InputDecoration(hintText: '地址，如 192.168.1.1'),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) {
                  return '地址不能为空';
                }
                if (text.contains(' ')) {
                  return '地址不能包含空格';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Hosts 全表编辑面板。
Future<void> showHostsSheet(BuildContext context, WidgetRef ref) =>
    showSheet<void>(context: context, builder: (_) => const _HostsSheet());

class _HostsSheet extends ConsumerWidget {
  const _HostsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hosts = ref.watch(generalConfigProvider).hosts;
    return CommonScaffold(
      title: 'Hosts',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加记录',
          onPressed: () => showHostEditor(context, ref),
        ),
      ],
      body: ListView(
        controller: sheetScrollController(context),
        padding: EdgeInsets.only(top: 8 + context.contentTopPadding),
        children: [
          if (hosts.isEmpty)
            SizedBox(
              height: 260,
              child: NullStatus(
                label: '还没有 Hosts 记录',
                description: '把常用域名指到固定地址，绕过 DNS 解析',
                illustration: NullStatusIllustration.dns,
              ),
            )
          else
            generateSection(
              title: '共 ${hosts.length} 条',
              items: [
                for (final entry in hosts.entries)
                  ListItem(
                    leading: const GlyphIcon(AppGlyphs.link),
                    title: Text(entry.key),
                    subtitle: Text(entry.value),
                    trailing: ConfigRemoveButton(
                      tooltip: '删除 ${entry.key}',
                      onPressed: () => ref
                          .read(generalConfigProvider.notifier)
                          .removeHost(entry.key),
                    ),
                  ),
              ],
              footer: '同一域名只保留一条；删除后该域名回落到常规 DNS 解析。',
            ),
          SizedBox(height: NavigationDock.insetOf(context)),
        ],
      ),
    );
  }
}

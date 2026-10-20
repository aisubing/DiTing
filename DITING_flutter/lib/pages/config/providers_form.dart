part of 'providers_page.dart';

/// 规则集行为类型。
///
/// 与 mihomo 的 `behavior` 字段一一对应，但带中文说明：单看 `ipcidr` 猜不出
/// 它是「按网段匹配」。
enum _ProviderBehavior {
  domain('domain', '域名规则集'),
  ipcidr('ipcidr', 'IP 网段规则集'),
  classical('classical', '完整规则集');

  const _ProviderBehavior(this.value, this.label);

  final String value;
  final String label;

  static _ProviderBehavior of(String value) => values.firstWhere(
    (item) => item.value == value,
    orElse: () => _ProviderBehavior.domain,
  );
}

/// 更新间隔选项（小时）。
const _intervalOptions = <String>['12 小时', '24 小时', '72 小时', '168 小时'];

/// 打开提供者表单；[existing] 为空表示新增。
Future<void> showProviderForm(
  BuildContext context,
  WidgetRef ref, {
  MockClashProvider? existing,
}) => showFormSheet<void>(
  context: context,
  builder: (_) => _ProviderFormSheet(existing: existing),
);

class _ProviderFormSheet extends ConsumerStatefulWidget {
  const _ProviderFormSheet({this.existing});

  final MockClashProvider? existing;

  @override
  ConsumerState<_ProviderFormSheet> createState() => _ProviderFormSheetState();
}

class _ProviderFormSheetState extends ConsumerState<_ProviderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _url = TextEditingController(text: widget.existing?.url ?? '');
  late _ProviderBehavior _behavior = _ProviderBehavior.of(
    widget.existing?.behavior ?? _ProviderBehavior.domain.value,
  );
  late String _interval =
      _intervalOptions.contains(widget.existing?.intervalLabel)
      ? widget.existing!.intervalLabel
      : _intervalOptions[1];

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final provider = MockClashProvider(
      name: _name.text.trim(),
      url: _url.text.trim(),
      behavior: _behavior.value,
      intervalLabel: _interval,
      fromUrl: widget.existing?.fromUrl ?? true,
    );
    final ok = ref
        .read(configResourcesProvider.notifier)
        .putProvider(widget.existing?.name, provider);
    if (!ok) {
      showConfigHint(context, '已有同名提供者「${provider.name}」');
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: widget.existing == null ? '添加提供者' : '编辑提供者',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存提供者',
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
                  hint: '规则里用 RULE-SET,这个名称,策略 引用它',
                  child: TextFormField(
                    controller: _name,
                    autofocus: widget.existing == null,
                    inputFormatters: TextInputLimits.limit(
                      TextInputLimits.name,
                    ),
                    decoration: const InputDecoration(
                      hintText: '如：reject-list',
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) {
                        return '名称不能为空';
                      }
                      if (text.contains(',')) {
                        return '名称不能包含逗号';
                      }
                      return null;
                    },
                  ),
                ),
                ConfigFieldRow(
                  label: '地址',
                  child: TextFormField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(fontFamily: 'JetBrainsMono'),
                    inputFormatters: TextInputLimits.limit(TextInputLimits.url),
                    decoration: const InputDecoration(
                      hintText: 'https://example.com/rules.yaml',
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
            ),
            generateSection(
              title: '选项',
              items: [
                ListItem<_ProviderBehavior>.options(
                  title: const Text('行为'),
                  subtitle: Text(_behavior.label),
                  options: _ProviderBehavior.values,
                  value: _behavior,
                  textBuilder: (behavior) => behavior.label,
                  onChanged: (behavior) => setState(() => _behavior = behavior),
                ),
                ListItem<String>.options(
                  title: const Text('更新间隔'),
                  subtitle: const Text('拉取失败的提供者会保留上一次的内容'),
                  options: _intervalOptions,
                  value: _interval,
                  textBuilder: (interval) => interval,
                  onChanged: (interval) => setState(() => _interval = interval),
                ),
              ],
              footer: '行为必须与文件内容一致：把网段文件设成 domain 会让整组规则失效。',
            ),
            SizedBox(height: NavigationDock.insetOf(context)),
          ],
        ),
      ),
    );
  }
}

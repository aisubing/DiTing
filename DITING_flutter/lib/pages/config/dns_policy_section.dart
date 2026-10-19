part of 'dns_page.dart';

/// DNS 策略表：规则集 → 服务商。
///
/// 键不可就地改：一条策略的键是「哪类域名」，改了就是另一条策略；要换分类
/// 只能删掉重加。值可以就地改，因为换服务商是最常见的操作。
class DnsPolicySection extends ConsumerWidget {
  const DnsPolicySection({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final existing = ref.read(dnsPolicyProvider);
    final result = await showFloatingDialog<({String key, String value})>(
      context: context,
      child: _PolicyDialog(existingKeys: existing.keys.toSet()),
    );
    if (result == null) {
      return;
    }
    ref.read(dnsPolicyProvider.notifier).put(result.key, result.value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policies = ref.watch(dnsPolicyProvider);
    return generateSection(
      title: '策略表',
      actions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加策略',
          onPressed: () => _add(context, ref),
        ),
      ],
      items: [
        for (final policy in policies.entries)
          ListItem.input(
            leading: ConfigRemoveButton(
              tooltip: '删除 ${policy.key}',
              onPressed: () =>
                  ref.read(dnsPolicyProvider.notifier).remove(policy.key),
            ),
            title: Text(policy.key),
            subtitle: Text(policy.value),
            dialogTitle: '服务商',
            value: policy.value,
            maxLength: TextInputLimits.dnsServer,
            validator: (value) => (value ?? '').trim().isEmpty
                ? '服务商不能为空；可填 system 表示走系统解析'
                : null,
            onChanged: (value) => ref
                .read(dnsPolicyProvider.notifier)
                .updateValue(policy.key, value ?? ''),
          ),
      ],
      footer: policies.isEmpty
          ? '还没有策略：所有域名都走上面的域名服务商。'
          : '键可以是 geosite:cn 这样的规则集，也可以是 domain:example.com；'
                '值为服务商地址或 system。',
    );
  }
}

/// 添加一条策略。
class _PolicyDialog extends StatefulWidget {
  const _PolicyDialog({required this.existingKeys});

  final Set<String> existingKeys;

  @override
  State<_PolicyDialog> createState() => _PolicyDialogState();
}

class _PolicyDialogState extends State<_PolicyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _key = TextEditingController();
  final _value = TextEditingController();

  @override
  void dispose() {
    _key.dispose();
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    Navigator.of(context)
        .pop((key: _key.text.trim(), value: _value.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '添加策略',
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
              controller: _key,
              autofocus: true,
              inputFormatters: TextInputLimits.limit(TextInputLimits.geoSite),
              decoration: const InputDecoration(hintText: '规则集，如 geosite:cn'),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) {
                  return '规则集不能为空';
                }
                if (widget.existingKeys.contains(text)) {
                  return '该规则集已有策略';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _value,
              inputFormatters: TextInputLimits.limit(TextInputLimits.dnsServer),
              decoration: const InputDecoration(
                hintText: '服务商，如 https://dns.alidns.com/dns-query',
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? '服务商不能为空' : null,
            ),
          ],
        ),
      ),
    );
  }
}

part of 'on_demand_page.dart';

/// 添加或编辑一条 SSID 规则；[existing] 为空表示新增。
Future<void> showSsidForm(
  BuildContext context,
  WidgetRef ref, {
  String? existing,
}) => showFormSheet<void>(
  context: context,
  builder: (_) => _SsidFormSheet(existing: existing),
);

class _SsidFormSheet extends ConsumerStatefulWidget {
  const _SsidFormSheet({this.existing});

  final String? existing;

  @override
  ConsumerState<_SsidFormSheet> createState() => _SsidFormSheetState();
}

class _SsidFormSheetState extends ConsumerState<_SsidFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _ssid = TextEditingController(text: widget.existing ?? '');
  late var _cellular = _initial?.cellular ?? true;
  late var _wifi = _initial?.wifi ?? true;
  late var _delay = _initial?.delayMs ?? 0;

  MockSsidRule? get _initial {
    for (final rule in ref.read(configResourcesProvider).ssidRules) {
      if (rule.ssid == widget.existing) {
        return rule;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _ssid.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final ok = ref
        .read(configResourcesProvider.notifier)
        .putSsid(
          widget.existing,
          MockSsidRule(
            ssid: _ssid.text,
            cellular: _cellular,
            wifi: _wifi,
            delayMs: _delay,
          ),
        );
    if (!ok) {
      showConfigHint(context, 'SSID 不能为空或已存在');
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: widget.existing == null ? '添加 SSID' : '编辑 SSID',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存 SSID',
        onPressed: _submit,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: sheetScrollController(context),
          padding: const EdgeInsets.only(top: 8),
          children: [
            generateSection(
              items: [
                ConfigFieldRow(
                  label: 'SSID',
                  hint: '区分大小写，与系统 Wi-Fi 列表里的名字完全一致',
                  child: TextFormField(
                    controller: _ssid,
                    autofocus: widget.existing == null,
                    decoration: const InputDecoration(hintText: '如：Home-5G'),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'SSID 不能为空' : null,
                  ),
                ),
              ],
            ),
            generateSection(
              title: '连接方式',
              items: [
                ListItem.toggle(
                  title: const Text('蜂窝网络'),
                  subtitle: const Text('在该网络下也启动 VPN'),
                  value: _cellular,
                  onChanged: (value) => setState(() => _cellular = value),
                ),
                ListItem.toggle(
                  title: const Text('Wi-Fi'),
                  subtitle: const Text('连上该 SSID 时启动 VPN'),
                  value: _wifi,
                  onChanged: (value) => setState(() => _wifi = value),
                ),
              ],
              footer: '两种都关掉，等于把这条 SSID 从白名单里排除（VPN 不会启动）。',
            ),
            generateSection(
              title: '延迟',
              items: [
                ListItem<int>.options(
                  title: const Text('启动延迟'),
                  subtitle: const Text('等待网络就绪后再启动 VPN'),
                  options: const [0, 500, 800, 1500, 3000],
                  value: [0, 500, 800, 1500, 3000].contains(_delay)
                      ? _delay
                      : 0,
                  textBuilder: (delay) => delay == 0 ? '立即连接' : '$delay ms',
                  onChanged: (delay) => setState(() => _delay = delay),
                ),
              ],
            ),
            SizedBox(height: NavigationDock.insetOf(context)),
          ],
        ),
      ),
    );
  }
}

part of 'general_page.dart';

/// 端口号的合法区间。
///
/// 下限 1024：低于它的端口需要 root 权限，普通应用绑定会直接失败；上限
/// 49151 是 IANA 的「注册端口」上界，再往上是临时端口，抢到了也会被系统回收。
const _minPort = 1024;
const _maxPort = 49151;

/// 一个端口输入框。
class _PortInput {
  _PortInput({
    required this.label,
    required this.controller,
    this.allowZero = true,
  });

  final String label;
  final TextEditingController controller;

  /// 是否允许填 0（0 = 关闭这个入站）。
  final bool allowZero;

  int get value => int.tryParse(controller.text.trim()) ?? -1;

  void dispose() => controller.dispose();
}

/// 打开端口表单。
Future<void> showPortForm(BuildContext context, WidgetRef ref) =>
    showFormSheet<void>(
      context: context,
      builder: (_) => const _PortFormSheet(),
    );

class _PortFormSheet extends ConsumerStatefulWidget {
  const _PortFormSheet();

  @override
  ConsumerState<_PortFormSheet> createState() => _PortFormSheetState();
}

class _PortFormSheetState extends ConsumerState<_PortFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final List<_PortInput> _inputs;

  @override
  void initState() {
    super.initState();
    final ports = ref.read(generalConfigProvider).ports;
    _inputs = [
      _PortInput(
        label: '混合端口',
        controller: TextEditingController(text: '${ports.mixed}'),
        allowZero: false,
      ),
      _PortInput(
        label: 'HTTP 端口',
        controller: TextEditingController(text: '${ports.port}'),
      ),
      _PortInput(
        label: 'SOCKS 端口',
        controller: TextEditingController(text: '${ports.socks}'),
      ),
      _PortInput(
        label: '透明代理端口',
        controller: TextEditingController(text: '${ports.redir}'),
      ),
      _PortInput(
        label: 'TProxy 端口',
        controller: TextEditingController(text: '${ports.tproxy}'),
      ),
    ];
  }

  @override
  void dispose() {
    for (final input in _inputs) {
      input.dispose();
    }
    super.dispose();
  }

  /// 逐字段校验：空、非数字、越界、与其他字段重复。
  ///
  /// 冲突检测必须在每个字段里都做一遍：`Form.validate()` 会遍历全部字段，
  /// 而「重复」是双方的属性——只标最后填的那个，用户会以为前一个是对的。
  String? _validate(_PortInput input, String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return '${input.label}不能为空';
    }
    final port = int.tryParse(text);
    if (port == null) {
      return '${input.label}必须是数字';
    }
    if (port == 0) {
      return input.allowZero ? null : '${input.label}不能为 0';
    }
    if (port < _minPort || port > _maxPort) {
      return '需在 $_minPort–$_maxPort 之间';
    }
    final clashes = _inputs
        .where((other) => !identical(other, input))
        .map((other) => other.value)
        .where((other) => other > 0);
    if (clashes.contains(port)) {
      return '与已有端口重复';
    }
    return null;
  }

  void _submit() {
    final fields = _formKey.currentState;
    if (fields == null || !fields.validate()) {
      return;
    }
    ref
        .read(generalConfigProvider.notifier)
        .setPorts(
          MockPorts(
            mixed: _inputs[0].value,
            port: _inputs[1].value,
            socks: _inputs[2].value,
            redir: _inputs[3].value,
            tproxy: _inputs[4].value,
          ),
        );
    Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    final confirmed = await confirmConfigAction(
      context,
      title: '恢复默认端口',
      message: '混合端口恢复为 ${mockDefaultPorts.mixed}，其余入站端口清零（等同关闭）。',
      confirmLabel: '恢复',
    );
    if (!confirmed || !mounted) {
      return;
    }
    ref.read(generalConfigProvider.notifier).setPorts(mockDefaultPorts);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: '端口',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存端口',
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
                for (final input in _inputs)
                  ConfigFieldRow(
                    label: input.label,
                    child: TextFormField(
                      controller: input.controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: TextInputLimits.digitsOnly(
                        TextInputLimits.port,
                      ),
                      decoration: InputDecoration(
                        hintText: input.allowZero ? '0 表示关闭' : '必填',
                      ),
                      validator: (value) => _validate(input, value),
                    ),
                  ),
              ],
              footer:
                  '端口需在 $_minPort–$_maxPort 之间且两两不同；'
                  '填 0 表示关闭该入站（混合端口除外）。',
            ),
            generateSection(
              items: [
                ListItem(
                  leading: const GlyphIcon(AppGlyphs.reset),
                  title: const Text('恢复默认端口'),
                  subtitle: const Text('混合端口 7890，其余入站关闭'),
                  onTap: _reset,
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

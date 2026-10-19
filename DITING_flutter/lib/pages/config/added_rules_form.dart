part of 'added_rules_page.dart';

/// 添加 / 编辑一条追加规则。
Future<void> showAddedRuleForm(
  BuildContext context,
  WidgetRef ref, {
  MockAddedRule? existing,
}) => showFormSheet<void>(
  context: context,
  builder: (_) => _AddedRuleFormSheet(existing: existing),
);

class _AddedRuleFormSheet extends ConsumerStatefulWidget {
  const _AddedRuleFormSheet({this.existing});

  final MockAddedRule? existing;

  @override
  ConsumerState<_AddedRuleFormSheet> createState() =>
      _AddedRuleFormSheetState();
}

class _AddedRuleFormSheetState extends ConsumerState<_AddedRuleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _payload = TextEditingController(
    text: widget.existing?.payload ?? '',
  );
  late AddedRuleKind _kind =
      widget.existing?.kind ?? AddedRuleKind.domainSuffix;
  late String _policy = widget.existing?.policy ?? mockRulePolicies.first;
  late bool _noResolve = widget.existing?.noResolve ?? false;

  @override
  void dispose() {
    _payload.dispose();
    super.dispose();
  }

  /// 逐类型的校验。
  ///
  /// `GEOIP` 只接受两位国家码，`IP-CIDR` 必须是带前缀长度的网段，`DOMAIN`
  /// 系列不能带协议头——这些错误写进配置后内核会整条规则丢掉，比在这里
  /// 拦住要难查得多。
  String? _validatePayload(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return '规则内容不能为空';
    }
    if (text.contains(' ')) {
      return '内容不能包含空格';
    }
    switch (_kind) {
      case AddedRuleKind.geoip:
        if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(text)) {
          return 'GeoIP 需为两位国家码，如 CN';
        }
      case AddedRuleKind.ipCidr:
        if (!RegExp(r'^[\d.]+/\d{1,2}$').hasMatch(text)) {
          return '需为带前缀长度的网段，如 203.0.113.0/24';
        }
        final prefix = int.tryParse(text.split('/').last);
        if (prefix == null || prefix < 0 || prefix > 32) {
          return '前缀长度需在 0–32 之间';
        }
      case AddedRuleKind.domain ||
          AddedRuleKind.domainSuffix ||
          AddedRuleKind.domainKeyword:
        if (text.contains('://')) {
          return '只写域名，不带协议头';
        }
      case AddedRuleKind.process:
        break;
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final notifier = ref.read(configResourcesProvider.notifier);
    final existing = widget.existing;
    notifier.putRule(
      existing == null
          ? notifier.newRule().copyWith(
              kind: _kind,
              payload: _payload.text.trim(),
              policy: _policy,
              noResolve: _noResolve,
            )
          : existing.copyWith(
              kind: _kind,
              payload: _payload.text.trim(),
              policy: _policy,
              noResolve: _noResolve,
            ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: widget.existing == null ? '添加规则' : '编辑规则',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存规则',
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
                ListItem<AddedRuleKind>.options(
                  title: const Text('规则类型'),
                  subtitle: Text(_kind.label),
                  options: AddedRuleKind.values,
                  value: _kind,
                  textBuilder: (kind) => kind.label,
                  onChanged: (kind) => setState(() => _kind = kind),
                ),
                ConfigFieldRow(
                  label: '内容',
                  hint: _payloadHint(_kind),
                  child: TextFormField(
                    controller: _payload,
                    autofocus: widget.existing == null,
                    autocorrect: false,
                    style: const TextStyle(fontFamily: 'JetBrainsMono'),
                    decoration: InputDecoration(
                      hintText: _payloadExample(_kind),
                    ),
                    validator: _validatePayload,
                  ),
                ),
                ListItem<String>.options(
                  title: const Text('命中策略'),
                  subtitle: Text(_policy),
                  options: mockRulePolicies,
                  value: _policy,
                  textBuilder: (policy) => policy,
                  onChanged: (policy) => setState(() => _policy = policy),
                ),
                if (_kind == AddedRuleKind.ipCidr)
                  ListItem.toggle(
                    title: const Text('不解析域名'),
                    subtitle: const Text('no-resolve：只用 IP 匹配，不为该规则做 DNS'),
                    value: _noResolve,
                    onChanged: (value) => setState(() => _noResolve = value),
                  ),
              ],
              footer: '生成的行：${_previewLine()}',
            ),
            SizedBox(height: NavigationDock.insetOf(context)),
          ],
        ),
      ),
    );
  }

  String _previewLine() {
    final payload = _payload.text.trim().isEmpty
        ? '<内容>'
        : _payload.text.trim();
    return [
      _kind.type,
      payload,
      _policy,
      if (_noResolve) 'no-resolve',
    ].join(',');
  }
}

String _payloadHint(AddedRuleKind kind) => switch (kind) {
  AddedRuleKind.domain => '精确匹配一个域名',
  AddedRuleKind.domainSuffix => '匹配该域名及其所有子域',
  AddedRuleKind.domainKeyword => '域名里出现该关键词就命中',
  AddedRuleKind.ipCidr => '带前缀长度的 IPv4 网段',
  AddedRuleKind.geoip => '两位国家码，匹配该国的 IP',
  AddedRuleKind.process => '发起连接的可执行文件名',
};

String _payloadExample(AddedRuleKind kind) => switch (kind) {
  AddedRuleKind.domain => 'api.internal.example.com',
  AddedRuleKind.domainSuffix => 'netflix.com',
  AddedRuleKind.domainKeyword => 'spotify',
  AddedRuleKind.ipCidr => '203.0.113.0/24',
  AddedRuleKind.geoip => 'CN',
  AddedRuleKind.process => 'Telegram.exe',
};

/// 快速预设浮层。
///
/// 预设是「一次加一组」的常用组合（拦 QUIC、局域网直连等）。上游有七个；
/// 这里保留其中四个最常用的，并把每组规则原文一起显示出来——用户需要先看清
/// 它到底加了什么，再决定要不要加。
Future<void> showRulePresetSheet(BuildContext context, WidgetRef ref) =>
    showSheet<void>(context: context, builder: (_) => const _RulePresetSheet());

class _RulePresetSheet extends ConsumerWidget {
  const _RulePresetSheet();

  static const presets = <_RulePreset>[
    _RulePreset(
      label: '拦截 QUIC',
      glyph: AppGlyphs.block,
      description: 'UDP 443 走 QUIC，绕过大部分分流；拦掉后会回落到 TCP',
      lines: ['AND,((NETWORK,UDP),(DST-PORT,443)),REJECT-DROP'],
      policy: 'REJECT',
      kind: AddedRuleKind.domain,
      payload: 'quic-block',
    ),
    _RulePreset(
      label: '拦截 DoT',
      glyph: AppGlyphs.dns,
      description: '853 端口是 DNS over TLS，拦掉后强制走内核 DNS',
      lines: ['DST-PORT,853,REJECT'],
      policy: 'REJECT',
      kind: AddedRuleKind.domain,
      payload: 'dot-block',
    ),
    _RulePreset(
      label: '局域网直连',
      glyph: AppGlyphs.wifi,
      description: '私有网段与本地域名不经过代理',
      lines: ['GEOSITE,private,DIRECT', 'GEOIP,LAN,DIRECT,no-resolve'],
      policy: 'DIRECT',
      kind: AddedRuleKind.ipCidr,
      payload: '192.168.0.0/16',
    ),
    _RulePreset(
      label: '系统服务直连',
      glyph: AppGlyphs.devices,
      description: 'Apple 与微软的系统服务直连，避免推送与更新走代理',
      lines: ['GEOSITE,apple,DIRECT', 'GEOSITE,microsoft,DIRECT'],
      policy: 'DIRECT',
      kind: AddedRuleKind.domainSuffix,
      payload: 'apple.com',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommonScaffold(
      title: '快速预设',
      body: ListView(
        controller: sheetScrollController(context),
        padding: const EdgeInsets.only(top: 8),
        children: [
          generateSection(
            items: [
              for (final preset in presets)
                ListItem(
                  leading: GlyphIcon(preset.glyph, size: 20),
                  title: Text(preset.label),
                  subtitle: Text(
                    '${preset.description}\n${preset.lines.join('\n')}',
                  ),
                  trailing: const GlyphIcon(AppGlyphs.addCircle, size: 20),
                  onTap: () {
                    final notifier = ref.read(configResourcesProvider.notifier);
                    notifier.putRule(
                      notifier.newRule().copyWith(
                        kind: preset.kind,
                        payload: preset.payload,
                        policy: preset.policy,
                      ),
                    );
                    showConfigHint(context, '已添加「${preset.label}」');
                    Navigator.of(context).pop();
                  },
                ),
            ],
            footer:
                '预设只写入一条代表性规则（原文见上方说明）；'
                '其余行可按同样格式手动添加。',
          ),
          SizedBox(height: NavigationDock.insetOf(context)),
        ],
      ),
    );
  }
}

class _RulePreset {
  const _RulePreset({
    required this.label,
    required this.glyph,
    required this.description,
    required this.lines,
    required this.policy,
    required this.kind,
    required this.payload,
  });

  final String label;
  final Glyph glyph;
  final String description;
  final List<String> lines;
  final String policy;
  final AddedRuleKind kind;
  final String payload;
}

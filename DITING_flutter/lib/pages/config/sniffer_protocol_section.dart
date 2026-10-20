part of 'sniffer_page.dart';

/// 三种协议各自的端口与「覆写目标地址」策略。
///
/// 一个协议就是一个行：标题是协议名，副标题报端口（空 = 标准端口），点进去
/// 是端口列表 + 覆写策略。上游同样是「列表一行 + 子页」，这里只是把三个子页
/// 合并成同一份面板。
class SnifferProtocolSection extends ConsumerWidget {
  const SnifferProtocolSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(snifferConfigProvider);
    return generateSection(
      title: '协议',
      items: [
        for (final config in configs)
          ListItem(
            leading: GlyphIcon(switch (config.protocol) {
              SniffProtocol.http => AppGlyphs.link,
              SniffProtocol.tls => AppGlyphs.lock,
              SniffProtocol.quic => AppGlyphs.bolt,
            }, size: 20),
            title: Text(config.protocol.label),
            subtitle: Text(
              config.ports.isEmpty
                  ? '标准端口 ${config.protocol.defaultPort}'
                  : '端口 ${config.ports.join('、')}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Text(
                  config.enable ? '已启用' : '已关闭',
                  style: context.listCaptionStyle.copyWith(
                    color: config.enable
                        ? context.colorScheme.success
                        : context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const GlyphIcon(AppGlyphs.chevronForward, size: 16),
              ],
            ),
            onTap: () => showSnifferProtocolSheet(context, config.protocol),
          ),
      ],
      footer:
          '不填端口时按标准端口嗅探（HTTP 80 / TLS 443 / QUIC 443）；'
          '列了端口就只嗅探这些端口。',
    );
  }
}

/// 打开某个协议的编辑面板。
Future<void> showSnifferProtocolSheet(
  BuildContext context,
  SniffProtocol protocol,
) => showSheet<void>(
  context: context,
  builder: (_) => _ProtocolSheet(protocol: protocol),
);

/// 「覆写目标地址」的三种取值。
enum _SniffDestination {
  inherit('跟随全局', null),
  enabled('覆写', true),
  disabled('不覆写', false);

  const _SniffDestination(this.label, this.value);

  final String label;
  final bool? value;

  static _SniffDestination of(bool? value) =>
      values.firstWhere((item) => item.value == value);
}

class _ProtocolSheet extends ConsumerWidget {
  const _ProtocolSheet({required this.protocol});

  final SniffProtocol protocol;

  Future<void> _addPort(BuildContext context, WidgetRef ref) async {
    final config = ref.read(snifferConfigProvider.notifier).of(protocol);
    final port = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: '添加端口',
        value: '',
        hintText: '单个端口或区间，如 80 或 8000-8100',
        maxLength: TextInputLimits.portRange,
        keyboardType: TextInputType.text,
        validator: (value) {
          final text = (value ?? '').trim();
          if (text.isEmpty) {
            return '端口不能为空';
          }
          if (config.ports.contains(text)) {
            return '该端口已存在';
          }
          if (!_isPortOrRange(text)) {
            return '格式应为 443 或 8000-8100';
          }
          return null;
        },
      ),
    );
    if (port == null) {
      return;
    }
    ref.read(snifferConfigProvider.notifier).addPort(protocol, port);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref
        .watch(snifferConfigProvider)
        .firstWhere((item) => item.protocol == protocol);
    final notifier = ref.read(snifferConfigProvider.notifier);
    final destination = _SniffDestination.of(config.overrideDestination);
    return CommonScaffold(
      title: protocol.label,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加端口',
          onPressed: () => _addPort(context, ref),
        ),
      ],
      body: ListView(
        controller: sheetScrollController(context),
        padding: EdgeInsets.only(top: 8 + context.contentTopPadding),
        children: [
          generateSection(
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.status),
                title: const Text('启用嗅探'),
                subtitle: Text('${protocol.label} 流量是否做域名嗅探'),
                value: config.enable,
                onChanged: (value) => notifier.setEnable(protocol, value),
              ),
              ListItem<_SniffDestination>.options(
                leading: const GlyphIcon(AppGlyphs.swap),
                title: const Text('覆写目标地址'),
                subtitle: Text(destination.label),
                options: _SniffDestination.values,
                value: destination,
                textBuilder: (item) => item.label,
                onChanged: (item) =>
                    notifier.setOverrideDestination(protocol, item.value),
              ),
            ],
            footer:
                '「跟随全局」表示用嗅探总开关里的覆写设置；'
                '这一个协议的设置会覆盖它。',
          ),
          if (config.ports.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                '未列端口：只嗅探标准端口 ${protocol.defaultPort}。',
                style: context.listCaptionStyle,
              ),
            )
          else
            generateSection(
              title: '端口',
              items: [
                for (final port in config.ports)
                  ListItem(
                    title: Text(port),
                    subtitle: Text(_portHint(port)),
                    trailing: ConfigRemoveButton(
                      tooltip: '删除端口 $port',
                      onPressed: () => notifier.removePort(protocol, port),
                    ),
                  ),
              ],
              footer: '端口按顺序尝试；区间形式（8000-8100）直接交给内核解析。',
            ),
          SizedBox(height: NavigationDock.insetOf(context)),
        ],
      ),
    );
  }
}

String _portHint(String port) => port.contains('-') ? '端口区间' : '单个端口';

/// 端口或端口区间的合法性。
bool _isPortOrRange(String value) {
  final parts = value.split('-');
  if (parts.length > 2) {
    return false;
  }
  for (final part in parts) {
    final port = int.tryParse(part.trim());
    if (port == null || port < 1 || port > 65535) {
      return false;
    }
  }
  return true;
}

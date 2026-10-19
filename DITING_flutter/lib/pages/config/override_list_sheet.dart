part of 'override_spec_page.dart';

/// 列表型覆写值的编辑浮层：一行一个值，可增可删。
Future<void> showOverrideListSheet(
  BuildContext context,
  MockOverrideSpec spec,
  MockOverrideEntry entry,
) => showSheet<void>(
  context: context,
  builder: (_) => _OverrideListSheet(spec: spec, entry: entry),
);

class _OverrideListSheet extends ConsumerWidget {
  const _OverrideListSheet({required this.spec, required this.entry});

  final MockOverrideSpec spec;
  final MockOverrideEntry entry;

  String _valueOf(WidgetRef ref) =>
      ref.read(overrideProvider)[spec.id]?.values[entry.key] ?? entry.value;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final current = splitOverrideList(_valueOf(ref));
    final value = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: '添加${entry.label}',
        value: '',
        hintText: _hintFor(entry.key),
        maxLength: TextInputLimits.dnsServer,
        validator: (text) {
          final trimmed = (text ?? '').trim();
          if (trimmed.isEmpty) {
            return '内容不能为空';
          }
          if (current.contains(trimmed)) {
            return '该条目已存在';
          }
          return null;
        },
      ),
    );
    if (value == null) {
      return;
    }
    final next = [...current, value.trim()];
    ref
        .read(overrideProvider.notifier)
        .setValue(spec.id, entry.key, next.join('\n'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = splitOverrideList(_valueOf(ref));
    return CommonScaffold(
      title: entry.label,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加${entry.label}',
          onPressed: () => _add(context, ref),
        ),
      ],
      body: ListView(
        controller: sheetScrollController(context),
        padding: const EdgeInsets.only(top: 8),
        children: [
          if (entry.description case final description?)
            ConfigNoteCard(text: description),
          if (items.isEmpty)
            SizedBox(
              height: 220,
              child: NullStatus(
                label: '还没有条目',
                description: _hintFor(entry.key),
                illustration: NullStatusIllustration.data,
              ),
            )
          else
            generateSection(
              title: '共 ${items.length} 项',
              items: [
                for (final item in items)
                  ListItem(
                    title: Text(item),
                    trailing: ConfigRemoveButton(
                      tooltip: '删除 $item',
                      onPressed: () => ref
                          .read(overrideProvider.notifier)
                          .setValue(
                            spec.id,
                            entry.key,
                            ([...items]..remove(item)).join('\n'),
                          ),
                    ),
                  ),
              ],
              footer: '条目按顺序写入配置；留空列表等于不覆写这一项。',
            ),
          SizedBox(height: NavigationDock.insetOf(context)),
        ],
      ),
    );
  }
}

/// 每个列表键的输入提示。
///
/// 覆写的列表大多是「域名 / CIDR / 服务商地址」三类，提示写清是哪一类比写
/// 「请输入」有用得多。
String _hintFor(String key) => switch (key) {
  'dns-hijack' => '如 any:53',
  'default-nameserver' => '纯 IP，如 223.5.5.5',
  'nameserver' ||
  'fallback' ||
  'proxy-server-nameserver' ||
  'direct-nameserver' => 'DoH / DoT / UDP 地址',
  'nameserver-policy' => '规则集:服务商，如 geosite:cn',
  'fake-ip-filter' => '域名，如 *.lan',
  'route-address' || 'route-exclude-address' => 'CIDR，如 198.18.0.1/16',
  'skip-src-address' || 'skip-dst-address' => 'CIDR，如 192.168.0.0/16',
  'force-domain' || 'skip-domain' => '域名，如 *.example.com',
  'include-interface' || 'exclude-interface' => '接口名，如 eth0',
  'include-uid' || 'exclude-uid' => '数字 UID，如 1000',
  'exclude-src-port' || 'exclude-dst-port' => '端口号，如 5353',
  _ => '输入一个值',
};

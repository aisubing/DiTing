import 'package:diting/data/mock_system.dart';
import 'package:diting/state/hub_settings_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 出站代理（上游 `OutboundProxySettingsScreen`）。
class OutboundProxyPage extends ConsumerStatefulWidget {
  const OutboundProxyPage({super.key});

  @override
  ConsumerState<OutboundProxyPage> createState() => _OutboundProxyPageState();
}

class _OutboundProxyPageState extends ConsumerState<OutboundProxyPage> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;

  @override
  void initState() {
    super.initState();
    final state = ref.read(outboundProxyProvider);
    _host = TextEditingController(text: state.host);
    _port = TextEditingController(text: '${state.port}');
    _username = TextEditingController(text: state.username);
    _password = TextEditingController(text: state.password);
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(outboundProxyProvider);
    final notifier = ref.read(outboundProxyProvider.notifier);
    final app = mockPackages
        .where((item) => item.packageName == state.appPackage)
        .firstOrNull;
    final status = state.enabled
        ? (state.validationError == null ? '代理可用' : '正在连接')
        : '未运行';
    return CommonScaffold(
      title: '出站代理',
      body: PageBody(
        children: [
          generateSection(
            title: '代理',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.link),
                title: const Text('启用出站代理功能'),
                subtitle: Text(status),
                value: state.enabled,
                onChanged: (value) => notifier.update(
                  (current) => current.copyWith(enabled: value),
                ),
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.appsList),
                title: const Text('代理应用'),
                subtitle: Text(app?.name ?? '未选择'),
                onTap: () => context.push('/hub/outbound-proxy/apps'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SegmentedControl<OutboundProtocol>(
              segments: [
                for (final protocol in OutboundProtocol.values)
                  (protocol, protocol.label),
              ],
              value: state.protocol,
              onChanged: (value) => notifier.update(
                (current) => current.copyWith(protocol: value),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _host,
                    autocorrect: false,
                    onChanged: (value) => notifier.update(
                      (current) => current.copyWith(host: value.trim()),
                    ),
                    decoration: const InputDecoration(labelText: '地址'),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _port,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => notifier.update(
                      (current) => current.copyWith(
                        port: int.tryParse(value) ?? current.port,
                      ),
                    ),
                    decoration: const InputDecoration(labelText: '端口'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _username,
              onChanged: (value) => notifier.update(
                (current) => current.copyWith(username: value),
              ),
              decoration: const InputDecoration(labelText: '账号（可选）'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _password,
              obscureText: true,
              onChanged: (value) => notifier.update(
                (current) => current.copyWith(password: value),
              ),
              decoration: const InputDecoration(labelText: '密码（可选）'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ListFooter(
              text: state.protocol == OutboundProtocol.http
                  ? 'HTTP CONNECT 不支持 UDP；UDP 会被严格阻断，QUIC 可回退到 TCP。'
                        '代理应用本身将绕过 DITING。'
                  : 'SOCKS5 通过 UDP ASSOCIATE 转发 UDP。代理应用本身将绕过 DITING，'
                        '防止流量环路。',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TonalButton(
              label: '保存',
              onPressed: () {
                final error = state.validationError;
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    content: Text(error ?? '出站代理设置已保存'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 选择代理应用（上游 `OutboundProxyAppsScreen`）。
class OutboundProxyAppsPage extends ConsumerStatefulWidget {
  const OutboundProxyAppsPage({super.key});

  @override
  ConsumerState<OutboundProxyAppsPage> createState() =>
      _OutboundProxyAppsPageState();
}

class _OutboundProxyAppsPageState
    extends ConsumerState<OutboundProxyAppsPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(outboundProxyProvider).appPackage;
    final query = _query.trim().toLowerCase();
    final visible = [
      for (final app in mockPackages)
        if (query.isEmpty ||
            app.name.toLowerCase().contains(query) ||
            app.packageName.toLowerCase().contains(query))
          app,
    ];
    return CommonScaffold(
      title: '选择代理应用',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              child: Text(
                '选择提供本地代理端口的应用。代理应用本身会绕过 DITING。',
                style: context.listSubtitleStyle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SearchField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          generateSection(
            title: '已安装应用',
            items: [
              for (final app in visible)
                ListItem(
                  leading: GlyphIcon(
                    selected == app.packageName
                        ? AppGlyphs.checkCircle
                        : glyphByName(app.glyphName),
                    size: 20,
                    color: selected == app.packageName
                        ? context.colorScheme.primary
                        : null,
                  ),
                  title: Text(app.name),
                  subtitle: Text(app.packageName),
                  trailing: selected == app.packageName
                      ? const SelectionCheck()
                      : null,
                  onTap: () {
                    ref.read(outboundProxyProvider.notifier).update(
                      (current) => current.copyWith(appPackage: app.packageName),
                    );
                    context.pop();
                  },
                ),
            ],
            footer: visible.isEmpty ? '未找到匹配应用' : null,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

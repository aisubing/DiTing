import 'package:diting/data/server/dns_server_config.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/pages/server/server_actions.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/server_upstream_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 服务器模式「上游服务器」Tab（上游 `server/ui/DnsServersScreen.kt`）。
///
/// 上游按协议分段（DNS / DoH / DoT）列出「内置 / 自定义」两组，内置项可选中，
/// 自定义项还可编辑与删除。这一屏照此实现：
///
/// - 协议分段用 `SegmentedControl`（设计系统里同一层的切换件）；
/// - 内置与自定义分开成两组，组标题逐字沿用上游「内置 DNS 服务商 / 自定义 DNS
///   服务商」；
/// - 选中即写入 `diting_dns_mode_prefs/selected_upstream_id`，服务重启后生效。
///
/// 上游的「按延迟排序」是 `ProviderManagementListContent` 的附带能力，但服务器
/// 模式只有一家上游、且没有经过测速存储，硬造一个排序开关等于给用户一个假控件。
/// 延迟测速属于服务商管理页（`/hub/providers`），本页不重复。
class ServerUpstreamPage extends ConsumerStatefulWidget {
  const ServerUpstreamPage({super.key});

  @override
  ConsumerState<ServerUpstreamPage> createState() => _ServerUpstreamPageState();
}

class _ServerUpstreamPageState extends ConsumerState<ServerUpstreamPage> {
  DnsProtocol _protocol = DnsProtocol.dns;

  Future<void> _select(ServerUpstream upstream) async {
    ref.read(serverSelectedUpstreamProvider.notifier).select(upstream.id);
    final running = ref.read(serverStatusProvider) == ServerStatus.running;
    if (!mounted) {
      return;
    }
    showServerHint(
      context,
      running ? '已切换到 ${upstream.name}，重启服务后生效' : '已选择 ${upstream.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(serverUpstreamListProvider);
    final selectedId = ref.watch(serverSelectedUpstreamProvider).id;
    final visible = [
      for (final upstream in all)
        if (upstream.protocol == _protocol) upstream,
    ];
    final presets = [
      for (final upstream in visible)
        if (!_isCustom(upstream)) upstream,
    ];
    final customs = [
      for (final upstream in visible)
        if (_isCustom(upstream)) upstream,
    ];
    return CommonScaffold(
      title: '上游服务器',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: SegmentedControl<DnsProtocol>(
              segments: const [
                (DnsProtocol.dns, 'DNS'),
                (DnsProtocol.doh, 'DoH'),
                (DnsProtocol.dot, 'DoT'),
              ],
              value: _protocol,
              onChanged: (value) => setState(() => _protocol = value),
            ),
          ),
          generateSection(
            title: '内置 DNS 服务商',
            items: [
              if (presets.isEmpty)
                const ListItem(
                  title: Text('暂无内置服务商'),
                  leading: GlyphIcon(AppGlyphs.info),
                )
              else
                for (final upstream in presets)
                  _UpstreamRow(
                    upstream: upstream,
                    selected: upstream.id == selectedId,
                    onTap: () => _select(upstream),
                  ),
            ],
          ),
          generateSection(
            title: '自定义 DNS 服务商',
            items: [
              if (customs.isEmpty)
                const ListItem(
                  title: Text('暂无自定义服务商'),
                  subtitle: Text('自定义上游在旧版设置页添加，本仓尚未接入编辑入口'),
                  leading: GlyphIcon(AppGlyphs.addCircle),
                )
              else
                for (final upstream in customs)
                  _UpstreamRow(
                    upstream: upstream,
                    selected: upstream.id == selectedId,
                    onTap: () => _select(upstream),
                  ),
            ],
            footer:
                '服务器模式只用一家上游；需要多路竞速请切到普通或极速模式。'
                '内置服务商由应用维护，只能切换。',
          ),
        ],
      ),
    );
  }

  /// 自定义项从 `custom_upstreams` 里解析出来，没有单独的 `isCustom` 标记；
  /// 内置 id 一律带 `preset_` 前缀（上游 `DnsUpstreamServer.PRESETS` 同约定）。
  static bool _isCustom(ServerUpstream upstream) =>
      !upstream.id.startsWith('preset_');
}

class _UpstreamRow extends StatelessWidget {
  const _UpstreamRow({
    required this.upstream,
    required this.selected,
    required this.onTap,
  });

  final ServerUpstream upstream;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: GlyphIcon(
        upstream.protocol == DnsProtocol.doh ? AppGlyphs.lock : AppGlyphs.dns,
        size: 20,
      ),
      title: Text(upstream.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        upstream.endpointLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: selected ? const SelectionCheck() : null,
      onTap: onTap,
    );
  }
}

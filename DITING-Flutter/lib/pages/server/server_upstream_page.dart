import 'package:diting/data/server/dns_server_config.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/pages/server/server_actions.dart';
import 'package:diting/pages/server/server_upstream_dialog.dart';
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
/// 模式只有一家上游、且本页没有测速存储，硬造一个排序开关等于给用户一个假控件。
/// 真实测速入口在首页「服务状态」卡片的刷新（原生 `dns_latency` 通道）与网络工具
/// 页的「测速」页签，本页不重复。
///
/// ## 自定义服务商的增删改
/// 上一轮这一组只列只读，副标题写着「自定义上游在旧版设置页添加，本仓尚未接入
/// 编辑入口」——旧版 `DnsMainScreen` 的 `onAddUpstream` / `onUpdateUpstream` /
/// `onDeleteUpstream` 三个回调都在这一屏上，缺的是本仓的实现。现在补上：
/// 内置项只能选中（由应用维护），自定义项可长按弹出「编辑 / 删除」，右上角
/// 加号新增、行尾「更多」出编辑/删除。三条落盘语义（id 前缀、IPv6 去括号、删选中项回落）在
/// [ServerUpstreamActions] 里。
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

  /// 新增（[existing] 为 null）或编辑一条自定义服务商。
  ///
  /// 校验失败时对话框自己保留并给出字段级提示，不在这里弹第二个提示——两处都
  /// 报会让用户看到两个重复的错误。
  Future<void> _edit(ServerUpstream? existing) async {
    final result = await showFloatingDialog<ServerUpstream>(
      context: context,
      child: UpstreamDialog(initial: existing, protocol: _protocol),
    );
    if (result == null || !mounted) {
      return;
    }
    final actions = ref.read(serverUpstreamActionsProvider);
    final saved = existing == null
        ? actions.add(
            name: result.name,
            protocol: result.protocol,
            address: result.address,
            port: result.port,
          )
        : (actions.update(result) ? result : null);
    if (saved == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    // 新增后切到它所在的协议分段，否则刚加完在别的分段里看不见。
    setState(() => _protocol = saved.protocol);
    showServerHint(
      context,
      existing == null ? '已添加 ${saved.name}' : '已保存 ${saved.name}',
    );
  }

  /// 删除一条自定义服务商。
  ///
  /// 删除会真的改 `custom_upstreams`；若它正是当前选中项，[ServerUpstreamActions.remove]
  /// 会把 `selected_upstream_id` 回落到第一个内置项，与旧版一致。
  Future<void> _delete(ServerUpstream upstream) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除 ${upstream.name}？',
        destructive: true,
        hasFields: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
        child: Text(
          '${upstream.endpointLabel}\n\n'
          '如果它正被使用，删除后会回落到第一个内置服务商。',
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final removed = ref.read(serverUpstreamActionsProvider).remove(upstream.id);
    if (removed && mounted) {
      showServerHint(context, '已删除 ${upstream.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(serverUpstreamListProvider);
    final selected = ref.watch(serverSelectedUpstreamProvider);
    final selectedId = selected.id;
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
      actions: [
        IconButton(
          tooltip: '添加自定义服务商',
          onPressed: () => _edit(null),
          icon: const GlyphIcon(AppGlyphs.addCircle),
        ),
      ],
      body: PageBody(
        children: [
          // 上游 `ProviderManagementListContent` 的 activeItemText：「当前用于解析
          // DNS：(DNS) 阿里云」。放在协议分段之上，因为它描述的是**整页**的当前
          // 选择，不是当前分段内的选择——切到 DoH 时它仍应显示那家 DNS 上游。
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              '当前用于解析 DNS：(${_protocolLabel(selected.protocol)}) '
              '${selected.name}',
              style: context.listCaptionStyle,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
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
                ListItem(
                  title: const Text('暂无自定义服务商'),
                  subtitle: const Text('点右上角加号添加 DoH / DoT / 明文 DNS 上游'),
                  leading: const GlyphIcon(AppGlyphs.addCircle),
                  trailing: const GlyphIcon(
                    AppGlyphs.chevronForward,
                    size: 20,
                  ),
                  onTap: () => _edit(null),
                )
              else
                for (final upstream in customs)
                  _UpstreamRow(
                    upstream: upstream,
                    selected: upstream.id == selectedId,
                    onTap: () => _select(upstream),
                    onEdit: () => _edit(upstream),
                    onDelete: () => _delete(upstream),
                  ),
              if (customs.isNotEmpty)
                ListItem(
                  title: const Text('添加自定义服务商'),
                  leading: const GlyphIcon(AppGlyphs.addCircle),
                  onTap: () => _edit(null),
                ),
            ],
            footer:
                '服务器模式只用一家上游；需要多路竞速请切到普通或极速模式。'
                '内置服务商由应用维护，只能切换；自定义项长按可编辑或删除。',
          ),
        ],
      ),
    );
  }

  /// 自定义项从 `custom_upstreams` 里解析出来，没有单独的 `isCustom` 标记；
  /// 内置 id 一律带 `preset_` 前缀（上游 `DnsUpstreamServer.PRESETS` 同约定）。
  static bool _isCustom(ServerUpstream upstream) =>
      !upstream.id.startsWith('preset_');

  /// 协议显示名。`DnsProtocol.storageValue` 是 `DNS`/`DOH`/`DOT` 的大写存储值，
  /// 直接上屏会是「(DOH)」，与旧版 `DnsModeProtocol.label` 的「DoH」不一致。
  static String _protocolLabel(DnsProtocol protocol) => switch (protocol) {
    DnsProtocol.dns => 'DNS',
    DnsProtocol.doh => 'DoH',
    DnsProtocol.dot => 'DoT',
  };
}

class _UpstreamRow extends StatelessWidget {
  const _UpstreamRow({
    required this.upstream,
    required this.selected,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final ServerUpstream upstream;
  final bool selected;
  final VoidCallback onTap;

  /// 自定义项才传；内置项由应用维护，没有编辑/删除入口。
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
      trailing: onEdit == null && onDelete == null
          ? (selected ? const SelectionCheck() : null)
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                if (selected) const SelectionCheck(),
                _RowMenu(
                  name: upstream.name,
                  onEdit: onEdit!,
                  onDelete: onDelete!,
                ),
              ],
            ),
      onTap: onTap,
    );
  }
}

/// 行尾的「更多」菜单：编辑 / 删除。
///
/// 点图标直接弹菜单，而不是依赖 `ContextMenuRegion` 的长按：后者在 `ListItem`
/// 的 `onTap` 之下，实测点图标会先被整行点击吃掉（只弹「已选择 X」）。
/// 直接 push [CommonPopupRoute] 与长按走的是同一条路由，视觉一致且点击即可用。
class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.name,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  void _open(BuildContext context) {
    final box = context.findRenderObject();
    final navigator = Navigator.maybeOf(context);
    final navigatorBox = navigator?.context.findRenderObject();
    if (box is! RenderBox ||
        navigator == null ||
        navigatorBox is! RenderBox ||
        !box.hasSize) {
      return;
    }
    final point = navigatorBox.globalToLocal(
      box.localToGlobal(box.size.bottomLeft(Offset.zero)),
    );
    navigator.push(
      CommonPopupRoute<void>(
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        placement: PopupPlacement.belowPoint,
        elevated: ElevatedSurfaceTheme.isIn(context),
        anchorOf: () => point & Size.zero,
        builder: (_) => CommonPopupMenu(
          items: [
            CommonPopupMenuItem(
              label: '编辑 $name',
              glyph: AppGlyphs.edit,
              onPressed: onEdit,
            ),
            CommonPopupMenuItem(
              label: '删除 $name',
              glyph: AppGlyphs.delete,
              danger: true,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: GlyphIcon(AppGlyphs.more, size: 20),
      ),
    );
  }
}

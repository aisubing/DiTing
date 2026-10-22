import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/server/dns_server_config.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Server mode's upstream list: 18 presets plus legacy custom entries.
///
/// 依赖 `legacySettingsProvider` 而不是 `ref.read`：新增 / 编辑 / 删除自定义上游
/// 写完会 bump `legacySettingsRevisionProvider`，这里必须跟着重建，否则列表页
/// 会一直显示旧的一份（旧版靠 `_upstreams` 的 StateFlow 通知，本仓用 revision）。
final serverUpstreamListProvider = Provider<List<ServerUpstream>>((ref) {
  return serverUpstreams(ref.watch(legacySettingsProvider));
});

class ServerSelectedUpstreamNotifier extends Notifier<ServerUpstream> {
  @override
  ServerUpstream build() {
    final settings = ref.watch(legacySettingsProvider);
    final upstreams = serverUpstreams(settings);
    return upstreams.firstWhere(
      (upstream) => upstream.id == settings.serverSelectedUpstreamId,
      orElse: () => upstreams.first,
    );
  }

  void select(String id) {
    final match = ref
        .read(serverUpstreamListProvider)
        .where((upstream) => upstream.id == id);
    if (match.isEmpty) return;
    state = match.first;
    ref.read(legacySettingsProvider).setServerSelectedUpstreamId(id);
    ref.read(legacySettingsRevisionProvider.notifier).bump();
  }
}

final serverSelectedUpstreamProvider =
    NotifierProvider<ServerSelectedUpstreamNotifier, ServerUpstream>(
      ServerSelectedUpstreamNotifier.new,
    );

/// 自定义上游的写入口（新增 / 编辑 / 删除）。
///
/// 三条语义照抄旧版 `DnsModeManager`，少一条都会让「界面说改了、引擎还是旧的」：
/// 1. **id 用 `custom_` 前缀 + 唯一串**：读取侧靠 `preset_` 前缀区分内置与自定义，
///    自定义项一旦用 `preset_` 开头就会被当成内置、变得不可编辑；
/// 2. **非 DoH 地址去掉 IPv6 方括号**再落盘，否则引擎拼 `host:port` 时会变成
///    `[[2001:db8::1]]:53`；
/// 3. **删掉的正是当前选中项时回落到第一个内置**，否则 `selected_upstream_id`
///    指向一条已不存在的记录，服务启动时只能靠兜底逻辑猜。
class ServerUpstreamActions {
  ServerUpstreamActions(this._ref);

  final Ref _ref;

  /// 新增一条；校验不过时返回 null（调用方据此保留对话框）。
  ServerUpstream? add({
    required String name,
    required DnsProtocol protocol,
    required String address,
    required int port,
  }) {
    final validation = validateServerUpstream(
      name: name,
      protocol: protocol,
      address: address,
      port: port,
    );
    if (validation is UpstreamInvalid) {
      return null;
    }
    final server = ServerUpstream(
      id: _newCustomId(),
      name: name.trim(),
      protocol: protocol,
      address: normalizeServerUpstreamAddress(protocol, address),
      port: port,
    );
    _write([..._custom(), server]);
    return server;
  }

  /// 编辑一条；`id` 必须是已有的自定义项，内置项不可改。
  bool update(ServerUpstream server) {
    if (!_isCustom(server.id)) {
      return false;
    }
    final validation = validateServerUpstream(
      name: server.name,
      protocol: server.protocol,
      address: server.address,
      port: server.port,
    );
    if (validation is UpstreamInvalid) {
      return false;
    }
    final normalized = ServerUpstream(
      id: server.id,
      name: server.name.trim(),
      protocol: server.protocol,
      address: normalizeServerUpstreamAddress(server.protocol, server.address),
      port: server.port,
    );
    _write([
      for (final existing in _custom())
        if (existing.id == normalized.id) normalized else existing,
    ]);
    return true;
  }

  /// 删除一条；删掉当前选中项时回落到第一个内置。
  bool remove(String id) {
    if (!_isCustom(id)) {
      return false;
    }
    _write([
      for (final existing in _custom())
        if (existing.id != id) existing,
    ]);
    final settings = _ref.read(legacySettingsProvider);
    if (settings.serverSelectedUpstreamId == id) {
      settings.setServerSelectedUpstreamId(serverPresetUpstreams.first.id);
      _ref.read(legacySettingsRevisionProvider.notifier).bump();
    }
    return true;
  }

  List<ServerUpstream> _custom() => parseServerCustomUpstreams(
    _ref.read(legacySettingsProvider).serverCustomUpstreamsJson,
  );

  void _write(List<ServerUpstream> servers) {
    _ref
        .read(legacySettingsProvider)
        .setServerCustomUpstreamsJson(encodeServerCustomUpstreams(servers));
    _ref.read(legacySettingsRevisionProvider.notifier).bump();
  }

  static bool _isCustom(String id) => !id.startsWith('preset_');

  /// `custom_` + 时间戳 + 计数器。旧版用 `UUID.randomUUID()`；本仓不引入额外依赖，
  /// 用「毫秒时间戳 + 同毫秒内自增」保证同一次会话里连续新增也不撞。
  static int _seq = 0;
  static String _newCustomId() {
    _seq++;
    return 'custom_${DateTime.now().microsecondsSinceEpoch}_$_seq';
  }
}

final serverUpstreamActionsProvider = Provider<ServerUpstreamActions>(
  ServerUpstreamActions.new,
);

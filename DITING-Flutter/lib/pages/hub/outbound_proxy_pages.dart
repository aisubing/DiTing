import 'dart:async';

import 'package:diting/data/native/apps_bridge.dart';
import 'package:diting/data/native/outbound_proxy_bridge.dart';
import 'package:diting/state/installed_apps_providers.dart';
import 'package:diting/state/outbound_proxy_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/app_icon_avatar.dart';
import 'package:diting/widgets/app_list_view.dart';
import 'package:diting/widgets/empty_state.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// DITING's own package id (`applicationId` in `DITING-Legacy/app/build.gradle.kts`).
/// Upstream reads `context.packageName`; this constant must match or the "cannot select
/// DITING itself" check breaks.
const ditingSelfPackage = 'com.haoze.diting';

/// Outbound proxy (upstream `OutboundProxySettingsScreen`). Config goes through
/// `OutboundProxyStore`, so initial values arrive asynchronously from
/// `outboundProxyConfigProvider`; a save bumps its revision.
class OutboundProxyPage extends ConsumerStatefulWidget {
  const OutboundProxyPage({super.key});

  @override
  ConsumerState<OutboundProxyPage> createState() => _OutboundProxyPageState();
}

class _OutboundProxyPageState extends ConsumerState<OutboundProxyPage> {
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  /// Filled once: another `read()` would overwrite what the user is typing.
  OutboundProxyConfig? _loaded;
  bool _saving = false;

  /// Status polling, as upstream's one-second loop: `outbound_proxy_status` goes connecting
  /// -> ready or error once the tunnel starts.
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _host.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Re-reads the store only while the tunnel may still come up; `ready`, `error` and
  /// `disabled` are terminal, so polling them only causes rebuilds.
  void _tick() {
    if (!mounted) {
      return;
    }
    final config = ref.read(outboundProxyConfigProvider).value;
    if (config == null || !config.enabled || config.status != 'connecting') {
      return;
    }
    ref.read(outboundProxyRevisionProvider.notifier).bump();
  }

  void _adopt(OutboundProxyConfig config) {
    if (_loaded != null) {
      return;
    }
    _loaded = config;
    _host.text = config.host;
    _port.text = '${config.port}';
    _username.text = config.username;
    _password.text = config.password;
  }

  OutboundProxyConfig _compose(OutboundProxyConfig base) => base.copyWith(
    host: _host.text.trim(),
    port: int.tryParse(_port.text.trim()) ?? 0,
    username: _username.text,
    password: _password.text,
  );

  Future<void> _save(OutboundProxyConfig base) async {
    final draft = _compose(base);
    // Upstream skips validation while disabled, or a disabled draft could never be saved.
    final error = draft.enabled
        ? draft.validationError(
            selfPackage: ditingSelfPackage,
            installedPackages: _installedPackages(),
          )
        : null;
    if (error != null) {
      _toast(error);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(outboundProxyStoreProvider).write(draft);
      await ref
          .read(outboundProxyStoreProvider)
          .setStatus(draft.enabled ? 'connecting' : 'disabled', '');
      ref.read(outboundProxyRevisionProvider.notifier).bump();
      _loaded = draft;
      _toast('出站代理设置已保存，启动隧道后生效');
    } on Object catch (error) {
      _toast('保存失败：$error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _reset() async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '重置出站代理？',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('重置'),
          ),
        ],
        child: const Text('将删除全部九个出站代理键（包括已加密保存的账号与密码）。'),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(outboundProxyStoreProvider).reset();
    ref.read(outboundProxyRevisionProvider.notifier).bump();
    if (!mounted) {
      return;
    }
    setState(() {
      _loaded = null;
      _host.clear();
      _port.clear();
      _username.clear();
      _password.clear();
    });
    _toast('已重置出站代理');
  }

  Set<String>? _installedPackages() {
    final snapshot = ref.read(installedAppsProvider).value;
    // Null when the list is unavailable (missing channel), so `validationError` skips the
    // "not installed" check instead of failing a valid package.
    return snapshot == null || snapshot.error != null
        ? null
        : snapshot.packageNames;
  }

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncConfig = ref.watch(outboundProxyConfigProvider);
    final config = asyncConfig.value;
    if (config == null) {
      return CommonScaffold(
        title: '出站代理',
        body: const Center(child: CommonCircleLoading.page()),
      );
    }
    _adopt(config);
    final apps = ref.watch(installedAppsProvider).value;
    final appLabel = _labelOf(config.proxyAppPackage, apps?.apps ?? const []);
    // Validation problems are shown only while enabled, matching upstream.
    final validation = config.enabled
        ? _compose(config).validationError(
            selfPackage: ditingSelfPackage,
            installedPackages: _installedPackages(),
          )
        : null;
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '出站代理',
      menuItems: [
        CommonPopupMenuItem(
          label: '重置出站代理',
          glyph: AppGlyphs.reset,
          danger: true,
          onPressed: _saving ? null : _reset,
        ),
      ],
      body: PageBody(
        children: [
          generateSection(
            title: '代理',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.link),
                title: const Text('启用出站代理功能'),
                subtitle: Text(
                  _statusLabel(config),
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: _statusColor(context, config)),
                ),
                value: config.enabled,
                onChanged: _saving
                    ? null
                    : (value) async {
                        // As upstream: the switch persists immediately and moves to
                        // connecting or disabled; other fields wait for save.
                        final next = config.copyWith(enabled: value);
                        await ref.read(outboundProxyStoreProvider).write(next);
                        await ref
                            .read(outboundProxyStoreProvider)
                            .setStatus(value ? 'connecting' : 'disabled', '');
                        ref.read(outboundProxyRevisionProvider.notifier).bump();
                      },
              ),
              ListItem(
                leading: const GlyphIcon(AppGlyphs.appsList),
                title: const Text('代理应用'),
                subtitle: Text(
                  config.proxyAppPackage.isEmpty ? '未选择' : appLabel,
                ),
                onTap: () => context.push('/hub/outbound-proxy/apps'),
              ),
            ],
            footer: _statusFooter(config),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SegmentedControl<OutboundProxyProtocol>(
              segments: [
                for (final protocol in OutboundProxyProtocol.values)
                  (protocol, protocol.label),
              ],
              value: config.protocol,
              onChanged: _saving
                  ? (_) {}
                  : (value) async {
                      await ref
                          .read(outboundProxyStoreProvider)
                          .write(config.copyWith(protocol: value));
                      ref.read(outboundProxyRevisionProvider.notifier).bump();
                    },
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
                    decoration: const InputDecoration(
                      labelText: '地址',
                      helperText: '仅支持 127.0.0.1 或 ::1',
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _port,
                    keyboardType: TextInputType.number,
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
              autocorrect: false,
              decoration: const InputDecoration(labelText: '账号（可选）'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密码（可选）'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ListFooter(
              text: config.protocol == OutboundProxyProtocol.http
                  ? 'HTTP CONNECT 不支持 UDP；UDP 会被严格阻断，QUIC 可回退到 TCP。'
                        '代理应用本身将绕过 DITING。'
                  : 'SOCKS5 通过 UDP ASSOCIATE 转发 UDP。代理应用本身将绕过 DITING，'
                        '防止流量环路。',
            ),
          ),
          if (validation != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: CommonCard(
                padding: const EdgeInsets.all(12),
                child: Text(
                  validation,
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: colorScheme.error),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TonalButton(
              label: '保存',
              onPressed: _saving ? null : () => _save(config),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// The four engine states: disabled, connecting, ready and error. Unknown values display
  /// as disabled, as upstream does.
  static String _statusLabel(OutboundProxyConfig config) {
    if (!config.enabled) {
      return '未运行';
    }
    return switch (config.status) {
      'connecting' => '正在连接',
      'ready' => '代理可用',
      'error' => config.statusMessage.isEmpty ? '连接失败' : config.statusMessage,
      _ => '未运行',
    };
  }

  static Color _statusColor(BuildContext context, OutboundProxyConfig config) {
    final colorScheme = context.colorScheme;
    if (!config.enabled) {
      return colorScheme.onSurfaceVariant;
    }
    return switch (config.status) {
      'ready' => colorScheme.success,
      'error' => colorScheme.error,
      'connecting' => colorScheme.primary,
      _ => colorScheme.onSurfaceVariant,
    };
  }

  static String? _statusFooter(OutboundProxyConfig config) {
    if (!config.enabled) {
      return null;
    }
    return switch (config.status) {
      'error' => '引擎上报的错误会一直保留到下一次隧道启动，便于回看原因。',
      'ready' => '引擎已确认代理可用；修改配置后需要重启隧道才会重新校验。',
      'connecting' => '隧道启动时会校验代理连通性，结果会实时显示在这里。',
      _ => null,
    };
  }

  static String _labelOf(String packageName, List<InstalledApp> apps) {
    if (packageName.isEmpty) {
      return '未选择';
    }
    for (final app in apps) {
      if (app.packageName == packageName) {
        return app.label;
      }
    }
    return packageName;
  }
}

/// Proxy app selection (upstream `OutboundProxyAppsScreen`). Single select that writes
/// straight into `OutboundProxyStore`, matching upstream's `singleSelect` with `onSave`.
class OutboundProxyAppsPage extends ConsumerStatefulWidget {
  const OutboundProxyAppsPage({super.key});

  @override
  ConsumerState<OutboundProxyAppsPage> createState() =>
      _OutboundProxyAppsPageState();
}

class _OutboundProxyAppsPageState extends ConsumerState<OutboundProxyAppsPage> {
  final _search = TextEditingController();
  String _query = '';

  /// In-memory only: 1.4.3 `OutboundProxySettingsScreen` passes empty change callbacks here, so the
  /// picker never persisted its filter or sort.
  AppListFilter _filter = AppListFilter.user;
  AppListSort _sort = AppListSort.labelAsc;

  /// Same 250 ms debounce as 1.4.3 `AppPickerScreen`.
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value);
    });
  }

  Future<void> _pick(OutboundProxyConfig config, String packageName) async {
    await ref
        .read(outboundProxyStoreProvider)
        .write(config.copyWith(proxyAppPackage: packageName));
    ref.read(outboundProxyRevisionProvider.notifier).bump();
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(outboundProxyConfigProvider).value;
    final selected = config?.proxyAppPackage ?? '';
    final snapshot = ref.watch(installedAppsProvider);
    final apps = snapshot.value?.apps ?? const <InstalledApp>[];
    final visible = visibleInstalledApps(
      apps: apps,
      query: _query,
      filter: _filter,
      sort: _sort,
      selected: {selected},
    );
    return CommonScaffold(
      title: '选择代理应用',
      menuItems: appListMenuItems(
        filter: _filter,
        sort: _sort,
        onFilterChanged: (value) => setState(() => _filter = value),
        onSortChanged: (value) => setState(() => _sort = value),
      ),
      body: AppListScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: CommonCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '选择提供本地代理端口的应用。代理应用本身会绕过 DITING。'
                      '端口由该应用绑定，谛听无法代它监听。',
                      style: context.listSubtitleStyle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SearchField(
                    controller: _search,
                    onChanged: _onSearchChanged,
                  ),
                ),
                if (snapshot.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CommonCircleLoading()),
                  )
                else if (snapshot.value?.error != null)
                  EmptyStateBox(
                    minHeight: 260,
                    child: NullStatus(
                      label: '读不到应用列表',
                      description: snapshot.value!.error,
                      illustration: NullStatusIllustration.apps,
                      action: TextButton(
                        onPressed: () => ref
                            .read(installedAppsRevisionProvider.notifier)
                            .bump(),
                        child: const Text('重试'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!snapshot.isLoading && snapshot.value?.error == null)
            ...appListSlivers(
              title: '已安装应用（${visible.length}）',
              itemCount: visible.length,
              footer: visible.isEmpty
                  ? (apps.isEmpty ? '设备上没有可选的代理应用' : '未找到匹配应用')
                  : null,
              itemBuilder: (context, index) {
                final app = visible[index];
                final isSelected = selected == app.packageName;
                return ListItem(
                  leading: AppIconAvatar(packageName: app.packageName),
                  title: Text(
                    app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isSelected ? const SelectionCheck() : null,
                  onTap: config == null
                      ? null
                      : () => _pick(config, app.packageName),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

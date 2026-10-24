// ignore_for_file: sort_child_properties_last
import 'dart:async';

import 'package:diting/data/native/apps_bridge.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/pages/hub/app_rules_store.dart';
import 'package:diting/state/app_rules_providers.dart';
import 'package:diting/state/installed_apps_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/app_list_view.dart';
import 'package:diting/widgets/empty_state.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Per-app rules (upstream `AppRuleManagementScreen`): master switch, search and configured
/// apps; picking an app swaps to the detail panel within the same route.
class AppRulesPage extends ConsumerStatefulWidget {
  const AppRulesPage({super.key});

  @override
  ConsumerState<AppRulesPage> createState() => _AppRulesPageState();
}

class _AppRulesPageState extends ConsumerState<AppRulesPage> {
  static const _searchDebounce = Duration(milliseconds: 250);

  final _search = TextEditingController();
  Timer? _debounce;

  String _query = '';

  String? _selected;

  AppRulesDraft? _draft;

  String? _lastKey;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) {
        return;
      }
      setState(() => _query = value.trim().toLowerCase());
    });
  }

  /// Rebuilds the draft from prefs when another page changed the keys. `/apps` deletes apps from
  /// `app_allowlist_rules_json`, and a stale draft would write a removed allow rule back on save.
  AppRulesDraft _draftOf(LegacySettings settings) {
    final key = appRulesKey(
      settings.appAllowlistEnabled,
      settings.appAllowlistRules,
    );
    if (_draft == null || (key != _lastKey && key != _draft!.baselineKey)) {
      _draft = AppRulesDraft.load(settings);
      _lastKey = key;
    }
    return _draft!;
  }

  void _save() {
    final draft = _draft;
    if (draft == null) {
      return;
    }
    saveAppRules(ref, draft);
    setState(() {
      draft.commit();
      _lastKey = draft.baselineKey;
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('已保存，启动 DNS VPN 后生效'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(legacySettingsProvider);
    final draft = _draftOf(settings);
    final snapshot = ref.watch(installedAppsProvider);
    final apps = snapshot.value?.apps ?? const <InstalledApp>[];
    // Fall back to the list when the selected app disappears after uninstall. Only a local
    // field is set: scheduling a frame from `build` is not allowed.
    final app = _selected == null
        ? null
        : apps.where((item) => item.packageName == _selected).firstOrNull;
    final showing = app != null ? _selected : null;
    return PopScope(
      canPop: showing == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && showing != null) {
          setState(() => _selected = null);
        }
      },
      child: app == null
          ? _buildList(context, draft, snapshot, settings)
          : _buildDetail(context, draft, app),
    );
  }
  Widget _buildList(
    BuildContext context,
    AppRulesDraft draft,
    AsyncValue<InstalledAppsSnapshot> snapshot,
    LegacySettings settings,
  ) {
    final apps = snapshot.value?.apps ?? const <InstalledApp>[];
    final filter = AppListFilter.fromStorageValue(
      settings.appAllowlistFilterRaw,
    );
    final sort = AppListSort.fromStorageValue(settings.appAllowlistSortRaw);
    final visible = appRulesVisibleApps(
      apps: apps,
      query: _query,
      filter: filter,
      sort: sort,
      draft: draft,
    );
    final hasAllowlist = draft.configuredApps > 0;
    return CommonScaffold(
      title: '应用独立规则',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.broom,
          tooltip: '清空全部放行规则',
          onPressed: hasAllowlist ? () => _clearAll(draft) : null,
        ),
      ],
      menuItems: [
        CommonPopupMenuItem(
          label: '过滤',
          glyph: AppGlyphs.filter,
          subItems: [
            for (final option in AppListFilter.values)
              CommonPopupMenuItem(
                label: option.label,
                checked: option == filter,
                onPressed: () {
                  settings.setAppAllowlistFilterRaw(option.storageValue);
                  ref.read(legacySettingsRevisionProvider.notifier).bump();
                },
              ),
          ],
        ),
        CommonPopupMenuItem(
          label: '排序',
          glyph: AppGlyphs.sort,
          subItems: [
            for (final option in AppListSort.values)
              CommonPopupMenuItem(
                label: option.label,
                checked: option == sort,
                onPressed: () {
                  settings.setAppAllowlistSortRaw(option.storageValue);
                  ref.read(legacySettingsRevisionProvider.notifier).bump();
                },
              ),
          ],
        ),
        CommonPopupMenuItem(
          label: '保存',
          glyph: AppGlyphs.checkCircle,
          onPressed: draft.dirty ? _save : null,
        ),
      ],
      body: AppListScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                generateSection(
                  title: '总开关',
                  items: [
                    ListItem.toggle(
                      leading: const GlyphIcon(AppGlyphs.verified),
                      title: const Text('启用单应用域名放行'),
                      subtitle: Text(
                        draft.configuredApps == 0
                            ? '暂未配置任何应用独立规则'
                            : '已配置 ${draft.configuredApps} 个应用 · '
                                  '放行 ${draft.totalDomains} 个域名',
                      ),
                      value: draft.master,
                      onChanged: (value) =>
                          setState(() => draft.master = value),
                    ),
                  ],
                  footer:
                      '为指定应用深度定制网络与解析控制：网络层白名单隔离（只放行列出的域名）、'
                      'DNS 专属黑/白名单与「默认拦截全部外联」。进入某个应用可分别配置，'
                      '保存后启动 DNS VPN 时下发。',
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
                    minHeight: 280,
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
              title: '应用（${visible.length}）',
              itemCount: visible.length,
              footer: visible.isEmpty
                  ? (apps.isEmpty ? '设备上没有可配置的应用' : '未找到匹配应用')
                  : null,
              itemBuilder: (context, index) {
                final item = visible[index];
                return AppRuleAppRow(
                  app: item,
                  domainCount: draft.domainsOf(item.packageName).length,
                  onTap: () => setState(() => _selected = item.packageName),
                );
              },
            ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: TonalButton(
                    label: '保存',
                    onPressed: draft.dirty ? _save : null,
                  ),
                ),
                ListFooter(
                  text: apps.isEmpty
                      ? '未读取到任何已安装应用，无法配置应用独立规则。'
                      : '保存后写入 app_allowlist_enabled 与 '
                            'app_allowlist_rules_json，启动 DNS VPN 时下发给引擎。',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context,
    AppRulesDraft draft,
    InstalledApp app,
  ) {
    final domains = draft.domainsOf(app.packageName);
    final rules = ref.watch(appScopedRulesProvider(app.packageName));
    return CommonScaffold(
      title: app.label,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加放行域名',
          onPressed: () => _addDomain(draft, app.packageName),
        ),
      ],
      body: PageBody(
        children: [
          generateSection(
            title: '应用',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.arrowBack, size: 20),
                title: const Text('返回应用列表'),
                subtitle: Text(app.packageName),
                onTap: () => setState(() => _selected = null),
              ),
            ],
          ),
          generateSection(
            title: '专属放行域名（网络层） (${domains.length})',
            actions: [
              IconButtonData(
                glyph: AppGlyphs.add,
                tooltip: '添加放行域名',
                onPressed: () => _addDomain(draft, app.packageName),
              ),
            ],
            items: [
              if (domains.isEmpty)
                const ListItem(
                  title: Text('未配置网络放行域名'),
                  subtitle: Text('网络层白名单为空时，该应用不受额外限制'),
                  leading: GlyphIcon(AppGlyphs.info),
                ),
              for (final domain in domains.toList()..sort())
                AppAllowDomainRow(
                  domain: domain,
                  onDelete: () => setState(
                    () => draft.removeDomain(app.packageName, domain),
                  ),
                ),
            ],
            footer: domains.isEmpty
                ? null
                : '这些域名会写入 app_allowlist_rules_json，'
                      '由引擎在下一次启动隧道时下发给 setAppAllowlist。',
          ),
          generateSection(
            title: 'DNS 专属黑/白名单',
            actions: [
              IconButtonData(
                glyph: AppGlyphs.add,
                tooltip: '添加 DNS 规则',
                onPressed: () => _addScopedRule(app),
              ),
            ],
            items: [
              ..._buildScopedRuleItems(app),
            ],
            footer:
                '这些规则写入规则库的 block_rule / allow_rule，带 appScope 只对本应用生效，'
                '并随规则快照的 appRules 下发，不会扩大成全局拦截。',
          ),
          generateSection(
            title: '外联与隔离模式',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.wifiOff),
                title: const Text('默认拦截全部外联'),
                subtitle: const Text('开启后阻断该应用的所有网络连接，仅放行白名单'),
                value: rules.value?.fullBlock ?? false,
                onChanged: (value) => _toggleFullBlock(app, value),
              ),
              if (rules.value?.fullBlock ?? false)
                const ListItem(
                  leading: GlyphIcon(AppGlyphs.info),
                  title: Text('已开启全阻断模式'),
                  subtitle: Text('请确保已添加必要的放行白名单，否则应用可能无法联网。'),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _clearAll(AppRulesDraft draft) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '清空全部放行规则？',
        destructive: true,
        child: const Text('将删除所有应用的专属放行域名。保存后生效，黑名单与全阻断设置不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(draft.clearAll);
  }

  Future<void> _addDomain(AppRulesDraft draft, String packageName) async {
    final domain = await showAppAllowDomainDialog(context);
    if (domain == null || !mounted) {
      return;
    }
    setState(() => draft.addDomain(packageName, domain));
  }

  List<Widget> _buildScopedRuleItems(InstalledApp app) {
    final rules = ref.watch(appScopedRulesProvider(app.packageName));
    if (rules.isLoading) {
      return const [
        ListItem(
          leading: GlyphIcon(AppGlyphs.info),
          title: Text('正在读取规则库'),
          subtitle: Text('稍候'),
        ),
      ];
    }
    final value = rules.value;
    if (value == null || !value.available) {
      return [
        ListItem(
          leading: const GlyphIcon(AppGlyphs.info),
          title: const Text('读不到规则库'),
          subtitle: Text(value?.error ?? '当前环境无法读写规则库'),
        ),
      ];
    }
    if (value.block.isEmpty && value.allow.isEmpty) {
      return const [
        ListItem(
          leading: GlyphIcon(AppGlyphs.info),
          title: Text('未配置 DNS 专属规则'),
          subtitle: Text('添加后仅对本应用生效，不影响其他应用'),
        ),
      ];
    }
    return [
      for (final rule in [...value.block, ...value.allow])
        AppScopedRuleRow(
          rule: rule,
          onToggle: (enabled) => _toggleScopedRule(app, rule, enabled),
          onDelete: () => _deleteScopedRule(app, rule),
        ),
    ];
  }

  Future<void> _addScopedRule(InstalledApp app) async {
    final result = await showAppScopedRuleDialog(context, app.packageName);
    if (result == null || !mounted) {
      return;
    }
    final controller = ref.read(appScopedRulesControllerProvider);
    final ok = await controller.addRule(
      app.packageName,
      result.kind,
      result.pattern,
    );
    if (!mounted) {
      return;
    }
    if (!ok) {
      _tip('规则已存在或规则库不可用');
      return;
    }
    _tip('已添加${result.kind == RuleKind.allow ? '白名单' : '黑名单'}规则');
  }

  Future<void> _toggleScopedRule(
    InstalledApp app,
    MockRule rule,
    bool enabled,
  ) async {
    await ref
        .read(appScopedRulesControllerProvider)
        .toggle(app.packageName, rule, enabled);
  }

  Future<void> _deleteScopedRule(InstalledApp app, MockRule rule) async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除这条规则？',
        destructive: true,
        child: Text(rule.pattern),
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
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref
        .read(appScopedRulesControllerProvider)
        .delete(app.packageName, rule);
  }

  Future<void> _toggleFullBlock(InstalledApp app, bool enabled) async {
    final next = await ref
        .read(appScopedRulesControllerProvider)
        .setFullBlock(app.packageName, enabled);
    if (!mounted) {
      return;
    }
    _tip(next ? '已开启全外联拦截模式' : '已关闭全外联拦截模式');
  }

  void _tip(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
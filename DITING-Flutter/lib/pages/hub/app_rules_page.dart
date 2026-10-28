// ignore_for_file: sort_child_properties_last
import 'dart:async';

import 'package:diting/data/native/apps_bridge.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/pages/hub/app_rules_store.dart';
import 'package:diting/state/app_rules_providers.dart';
import 'package:diting/state/installed_apps_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/app_list_error_state.dart';
import 'package:diting/widgets/app_list_view.dart';
import 'package:diting/widgets/section_slivers.dart';
import 'package:diting/widgets/unsaved_changes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'app_rules_detail.dart';

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
      canPop: showing == null && !draft.dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        // Back inside the page walks out of the detail panel first; only leaving the page asks
        // about the pending rules.
        if (showing != null) {
          setState(() => _selected = null);
          return;
        }
        if (!await _confirmLeave(draft)) {
          return;
        }
        if (mounted) {
          Navigator.of(this.context).pop();
        }
      },
      child: app == null
          ? _buildList(context, draft, snapshot, settings)
          : _buildDetail(context, draft, app),
    );
  }

  /// Same question as the blocked/excluded pickers: the draft here is also saved by an explicit
  /// button, so leaving without it would silently drop the edits.
  Future<bool> _confirmLeave(AppRulesDraft draft) async {
    final choice = await showUnsavedChangesDialog(
      context,
      title: '保存更改？',
      message: '「应用独立规则」还有未保存的修改。保存后离开，还是放弃这些修改？',
    );
    if (!mounted) {
      return false;
    }
    switch (choice) {
      case UnsavedChangesChoice.cancel:
        return false;
      case UnsavedChangesChoice.discard:
        return true;
      case UnsavedChangesChoice.save:
        _save();
        return true;
    }
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
                else if (snapshot.value?.error case final error?)
                  AppListErrorState(error: error, minHeight: 280),
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
      body: SliverPageBody(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
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
              ],
            ),
          ),
          ..._allowDomainSlivers(draft, app, domains),
          ..._scopedRuleSlivers(app),
          SliverToBoxAdapter(child: _detailFooter(app, rules)),
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

  /// Drops one locally edited allowlisted domain; the change lands on save.
  void _removeDomain(AppRulesDraft draft, String packageName, String domain) =>
      setState(() => draft.removeDomain(packageName, domain));

  Future<void> _addDomain(AppRulesDraft draft, String packageName) async {
    final domain = await showAppAllowDomainDialog(context);
    if (domain == null || !mounted) {
      return;
    }
    setState(() => draft.addDomain(packageName, domain));
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

// ignore_for_file: sort_child_properties_last
import 'dart:async';

import 'package:diting/data/native/apps_bridge.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/pages/hub/app_rules_store.dart';
import 'package:diting/state/installed_apps_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 应用独立规则（上游 `AppRuleManagementScreen` + `SingleAppRulePanel`）。
///
/// 列表页：总开关、搜索、已配置应用；点进某个应用后在同一路由内切换到详情面板
/// （上游也是 `BackHandler` 返回列表，而不是新路由）。
///
/// 数据源与持久化见 `app_rules_store.dart` 的文件头：网络层放行域名已接
/// `app_allowlist_rules_json`；DNS 专属黑白名单与「默认拦截全部外联」仍在 Room 的
/// `appScope` 列上，`RuleRepository` 尚无按应用读写的接口，因此面板里如实说明
/// 「未接库」，而不是留一个点了没反应的开关。
class AppRulesPage extends ConsumerStatefulWidget {
  const AppRulesPage({super.key});

  @override
  ConsumerState<AppRulesPage> createState() => _AppRulesPageState();
}

class _AppRulesPageState extends ConsumerState<AppRulesPage> {
  static const _searchDebounce = Duration(milliseconds: 250);

  final _search = TextEditingController();
  Timer? _debounce;

  /// 防抖后的关键词；输入框不受防抖影响，否则打字会掉字。
  String _query = '';

  String? _selected;

  /// 跨 prefs 版本的草稿：只在首次 build 时按落盘值构建，之后由本页维护。
  AppRulesDraft? _draft;

  /// 上次见到的落盘值指纹；用来识别「别人写了同一份键」。
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

  /// 取草稿；prefs 被别处改过时以落盘值为准重建。
  ///
  /// `/apps`（排除应用）在勾选「排除」时会把这台应用从 `app_allowlist_rules_json`
  /// 里删掉。本页若继续用旧草稿，用户会看到一条已经不存在的放行规则，点保存还会
  /// 把它写回去——正是 1.4.3 里互斥清洗要防的那种「自我复活」。
  AppRulesDraft _draftOf(LegacySettings settings) {
    final key = appRulesKey(settings.appAllowlistEnabled, settings.appAllowlistRules);
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
    // 选中的应用在列表刷新后消失（被卸载）时退回列表，避免卡在空面板。这里
    // 只改本地字段而不 `setState`：`build` 里禁止再排一帧，而下一帧读到的
    // 列表就是这一份。
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
    final filter = AppListFilter.fromStorageValue(settings.appAllowlistFilterRaw);
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
      body: PageBody(
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
                onChanged: (value) => setState(() => draft.master = value),
              ),
            ],
            footer: '为指定应用深度定制网络与解析控制。以下是软件网络层的白名单隔离'
                '（只放行列出的域名）；DNS 专属黑白名单与「默认拦截全部外联」'
                '需要按应用读写规则库，本轮尚未接通，配置入口暂为只读说明。',
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
            SizedBox(
              height: 280,
              child: NullStatus(
                label: '读不到应用列表',
                description: snapshot.value!.error,
                illustration: NullStatusIllustration.apps,
                action: TextButton(
                  onPressed: () =>
                      ref.read(installedAppsRevisionProvider.notifier).bump(),
                  child: const Text('重试'),
                ),
              ),
            )
          else
            generateSection(
              title: '应用（${visible.length}）',
              items: [
                for (final item in visible)
                  AppRuleAppRow(
                    app: item,
                    domainCount: draft.domainsOf(item.packageName).length,
                    onTap: () => setState(() => _selected = item.packageName),
                  ),
              ],
              footer: visible.isEmpty
                  ? (apps.isEmpty ? '设备上没有可配置的应用' : '未找到匹配应用')
                  : null,
            ),
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
                : '保存后写入 app_allowlist_enabled 与 app_allowlist_rules_json，'
                      '启动 DNS VPN 时下发给引擎。',
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
            footer: domains.isEmpty ? null : '这些域名会写入 app_allowlist_rules_json，'
                '由引擎在下一次启动隧道时下发给 setAppAllowlist。',
          ),
          generateSection(
            title: 'DNS 专属黑/白名单',
            items: const [
              ListItem(
                title: Text('尚未接通'),
                subtitle: Text(
                  '1.4.3 把它存在规则库的 appScope 列，当前规则仓储没有按应用读写的接口，'
                  '本轮不改数据层，因此这里只作说明。',
                ),
                leading: GlyphIcon(AppGlyphs.info),
              ),
            ],
          ),
          generateSection(
            title: '外联与隔离模式',
            items: const [
              ListItem(
                title: Text('默认拦截全部外联'),
                subtitle: Text(
                  '1.4.3 通过注入 *\$app=<包名> 的拦截规则实现，同样依赖 appScope，'
                  '尚未接通。',
                ),
                leading: GlyphIcon(AppGlyphs.wifiOff),
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
}

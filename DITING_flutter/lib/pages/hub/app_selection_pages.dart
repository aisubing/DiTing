import 'package:diting/data/native/apps_bridge.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/installed_apps_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/empty_state.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 禁止联网应用（上游 `BlockedAppsScreen`）。
///
/// 写 `dns_vpn_prefs` 的 `blocked_app_packages` + `blocked_apps_enabled`；普通
/// 模式启动时会把它换算成 UID 交给 Go 引擎。与「排除应用」「HTTPS 检查应用」
/// 「应用独立规则」互斥：一处勾选会从另外三处移除，和上游保存时的清洗一致。
class BlockedAppsPage extends ConsumerWidget {
  const BlockedAppsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(legacySettingsProvider);
    return _AppSelectionScaffold(
      title: '禁止联网应用',
      info: '通过本机 VPN 按 UID 阻止所选应用的全部网络连接。共享同一 UID 的应用会一并受影响。',
      enableToggleTitle: '启用禁止联网',
      enableToggleEmptyHint: '尚未选择应用；开启后不会阻断流量',
      selectionTitle: '禁止联网的应用',
      icon: AppGlyphs.wifiOff,
      selected: settings.blockedAppPackages,
      enabled: settings.blockedAppsEnabled,
      onSave: (packages, enabled) => _saveBlocked(ref, packages, enabled),
    );
  }

  /// 保存禁止联网名单，并清掉另外三处的同名应用。
  ///
  /// 上游 `BlockedAppsScreen.saveBlockedApps` 四件事一起做；少清一处，同一个应用
  /// 会同时被「禁止联网」和「排除」命中，最终行为由引擎侧判定顺序决定。
  static void _saveBlocked(WidgetRef ref, Set<String> packages, bool enabled) {
    final settings = ref.read(legacySettingsProvider);
    settings.setBlockedApps(packages: packages, enabled: enabled);
    _dropOverlaps(settings, packages, _Owner.blocked);
    ref.read(legacySettingsRevisionProvider.notifier).bump();
  }
}

/// 排除应用（上游 `ExcludedAppsScreen`）。
///
/// 写 `excluded_app_packages`；排除后应用使用系统 DNS，不参与本应用的过滤、
/// 缓存、日志和统计。与 `/apps` 是同一份数据，只是入口不同（`/apps` 带过滤与
/// 排序菜单，这里是二级页）。
class ExcludedAppsPage extends ConsumerWidget {
  const ExcludedAppsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(legacySettingsProvider);
    return _AppSelectionScaffold(
      title: '排除应用',
      info: '排除后，应用将使用系统 DNS，不参与本应用的过滤、缓存、日志和统计。',
      selectionTitle: '排除的应用',
      icon: AppGlyphs.appsList,
      selected: settings.excludedPackages,
      enabled: true,
      showToggle: false,
      onSave: (packages, _) {
        settings.setExcludedPackages(packages);
        _dropOverlaps(settings, packages, _Owner.excluded);
        ref.read(legacySettingsRevisionProvider.notifier).bump();
      },
    );
  }
}

/// 刚写进哪一份名单——互斥清洗要跳过它。
///
/// 清洗不能靠「读回来再差集」：`LegacySettings` 是直接读写 store 的视图，
/// `setBlockedApps(packages)` 之后再读 `blockedAppPackages` 拿到的就是刚写进去的
/// 那份，`difference(packages)` 当场变成空集，把用户刚保存的选择清空。
/// 归属方必须显式传进来。
enum _Owner { blocked, excluded }

/// 把刚写进某一处名单的应用从**另外三处**移除。
///
/// 1.4.3 的三个页面各写一遍这段清洗，其中两处都漏了 `app_allowlist_rules_json`
/// ——勾了「禁止联网」但应用独立规则还在，引擎会同时收到「拦」和「放行」。这里
/// 合成一份，四张选择页共用，避免再漂移。
void _dropOverlaps(
  LegacySettings settings,
  Set<String> packages,
  _Owner owner,
) {
  if (packages.isEmpty) {
    return;
  }
  if (owner != _Owner.excluded) {
    settings.setExcludedPackages(
      settings.excludedPackages.difference(packages),
    );
  }
  if (owner != _Owner.blocked) {
    settings.setBlockedApps(
      packages: settings.blockedAppPackages.difference(packages),
      enabled: settings.blockedAppsEnabled,
    );
  }
  final inspection = settings.httpInspectionPackages.difference(packages);
  settings.setHttpInspectionApps(
    packages: inspection,
    // 检查清单被清空时必须把总开关一起关掉：留一个「已启用但零目标」的开关，
    // 引擎会按 `httpsInspectionOperational == false` 直接跳过，UI 却显示开着。
    enabled: settings.httpInspectionEnabled && inspection.isNotEmpty,
  );
  final allowlist = settings.appAllowlistRules;
  if (allowlist.keys.any(packages.contains)) {
    settings.setAppAllowlistRules({
      for (final entry in allowlist.entries)
        if (!packages.contains(entry.key)) entry.key: entry.value,
    });
  }
}

class _AppSelectionScaffold extends ConsumerStatefulWidget {
  const _AppSelectionScaffold({
    required this.title,
    required this.info,
    required this.selectionTitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onSave,
    this.enableToggleTitle,
    this.enableToggleEmptyHint,
    this.showToggle = true,
  });

  final String title;
  final String info;
  final String selectionTitle;
  final Glyph icon;

  /// Persisted set the page starts from; edits live locally until "保存".
  final Set<String> selected;
  final bool enabled;
  final bool showToggle;
  final String? enableToggleTitle;
  final String? enableToggleEmptyHint;
  final void Function(Set<String> packages, bool enabled) onSave;

  @override
  ConsumerState<_AppSelectionScaffold> createState() =>
      _AppSelectionScaffoldState();
}

class _AppSelectionScaffoldState extends ConsumerState<_AppSelectionScaffold> {
  final _search = TextEditingController();

  /// 上一次同步的落盘值，用来识别「别人改了同一份键」。
  Set<String> _initial = const {};
  Set<String> _selected = const {};
  bool _synced = false;
  late bool _enabled = widget.enabled;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// prefs 是唯一真相源：落盘值变了就丢弃本地草稿。
  ///
  /// 同一个应用可能被 `/apps`、HTTPS 检查页或应用独立规则页从某份名单里删掉；
  /// 本页若继续用旧草稿，用户点「保存」会把对方刚删掉的项写回去。
  void _sync(Set<String> persisted) {
    if (!_synced) {
      _synced = true;
      _initial = {...persisted};
      _selected = {...persisted};
      return;
    }
    if (!_sameSet(persisted, _initial)) {
      _initial = {...persisted};
      _selected = {...persisted};
    }
  }

  void _save() {
    widget.onSave({..._selected}, _enabled);
    setState(() {
      _initial = {..._selected};
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('已保存，启动 DNS VPN 后生效'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggle(String packageName) {
    setState(() {
      if (!_selected.remove(packageName)) {
        _selected.add(packageName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _sync(widget.selected);
    final snapshot = ref.watch(installedAppsProvider);
    final apps = snapshot.value?.apps ?? const <InstalledApp>[];
    // 这两页在 1.4.3 里也是「用户应用」优先（`initialFilter` 默认 USER），但
    // 排序与过滤菜单在 `/apps`，这里只做搜索，两组都在列表里分节展示。
    final visible = visibleInstalledApps(
      apps: apps,
      query: _query,
      filter: AppListFilter.all,
      sort: AppListSort.labelAsc,
      selected: _selected,
    );
    final dirty = _enabled != widget.enabled || !_sameSet(_selected, _initial);
    return CommonScaffold(
      title: widget.title,
      body: PageBody(
        children: [
          if (widget.showToggle && widget.enableToggleTitle != null)
            generateSection(
              title: '开关',
              items: [
                ListItem.toggle(
                  leading: const GlyphIcon(AppGlyphs.wifiOff),
                  title: Text(widget.enableToggleTitle!),
                  subtitle: Text(
                    _selected.isEmpty
                        ? (widget.enableToggleEmptyHint ?? '尚未选择应用')
                        : '已选择 ${_selected.length} 个应用',
                  ),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Text(widget.info, style: context.listSubtitleStyle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SearchField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (snapshot.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CommonCircleLoading()),
            )
          else if (snapshot.value?.error case final error?)
            // 读不到应用列表时的错误串长度不可控，写死 260 会把说明裁掉，
            // 下面的「保存」按钮就压在被裁掉的文字上（真机上两段叠着）。
            EmptyStateBox(
              minHeight: 260,
              child: NullStatus(
                label: '读不到应用列表',
                description: error,
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
              title: '${widget.selectionTitle}（${_selected.length}）',
              items: [
                for (final app in visible)
                  ListItem(
                    leading: GlyphIcon(
                      _selected.contains(app.packageName)
                          ? AppGlyphs.checkCircle
                          : AppGlyphs.appsList,
                      size: 20,
                      color: _selected.contains(app.packageName)
                          ? context.colorScheme.primary
                          : null,
                    ),
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
                    trailing: CommonCheckBox(
                      value: _selected.contains(app.packageName),
                      isCircle: true,
                      onChanged: (_) => _toggle(app.packageName),
                    ),
                    onTap: () => _toggle(app.packageName),
                  ),
              ],
              footer: visible.isEmpty
                  ? (apps.isEmpty ? '设备上没有可选的应用' : '未找到匹配应用')
                  : null,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TonalButton(label: '保存', onPressed: dirty ? _save : null),
          ),
          ListFooter(
            text: apps.isEmpty
                ? '未读取到任何已安装应用；此处的勾选保存后不会命中任何应用。'
                : '勾选会同时取消该应用在「排除应用」「禁止联网」「HTTPS 检查」'
                      '与应用独立规则里的选择。',
          ),
        ],
      ),
    );
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

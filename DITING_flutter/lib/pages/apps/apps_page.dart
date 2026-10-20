/// 排除应用编辑器（`/apps`）。
///
/// **语义决定**：1.4.3 没有 `/apps` 这条路由——它是第二轮迁移留下的通用「应用
/// 选择」页，演示数据里还带着 `MockInstalledApp.category` 这种没有真实对应物的
/// 假分类。真实数据里唯一说得通的用途是「排除应用」（`excluded_app_packages`），
/// 因此本页接成它的编辑器，页头明确写出这一点。`/hub/excluded-apps`
/// （`ExcludedAppsPage`）功能重叠但仍在，它走的是通用 `_AppSelectionScaffold`。
///
/// 三处细节必须做对（`docs/refactor/04-rules-ui.md` §5）：
/// 搜索要防抖 250ms（列表里有几百个应用时，每次按键重建整张表会卡）；
/// 分组按系统 / 用户两档（正是旧版 `AppListFilter` 的两档，不再有假分类）；
/// 全选 / 反选必须只作用于「当前可见」的应用，否则搜索状态下点全选会静默选中
/// 一堆看不见的条目。
library;

import 'dart:async';

import 'package:diting/data/native/apps_bridge.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/installed_apps_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'apps_rows.dart';

/// 与规则页一致的防抖时长：同属「边打边筛」的交互，两页手感应当一致。
const _searchDebounce = Duration(milliseconds: 250);

/// 应用选择页（排除应用编辑器）。
class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({super.key});

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  /// 防抖后的关键词；输入框本身不受防抖影响，否则打字会掉字。
  var _query = '';

  /// 草稿与「上一次同步的落盘值」。`null` 表示还没抄过——首帧 prefs 里已经有值，
  /// 但 `build` 才是唯一安全的读取点。
  Set<String>? _draft;
  Set<String> _lastPrefs = const {};

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

  /// 排除与「禁止联网」「HTTPS 检查应用」「应用独立规则」互斥。
  ///
  /// 1.4.3 的 `ExcludedAppsScreen.saveExcludedApps` 三处都清；少清一处，同一个
  /// 应用会同时被「排除」和「禁止联网」命中，最终行为由引擎侧的判定顺序决定，
  /// 用户看到的是随机结果。
  void _save(Set<String> packages) {
    final settings = ref.read(legacySettingsProvider);
    settings.setExcludedPackages(packages);
    settings.setBlockedApps(
      packages: settings.blockedAppPackages.difference(packages),
      enabled: settings.blockedAppsEnabled,
    );
    settings.setHttpInspectionApps(
      packages: settings.httpInspectionPackages.difference(packages),
      enabled: settings.httpInspectionEnabled,
    );
    final allowlist = settings.appAllowlistRules;
    if (allowlist.keys.any(packages.contains)) {
      settings.setAppAllowlistRules({
        for (final entry in allowlist.entries)
          if (!packages.contains(entry.key)) entry.key: entry.value,
      });
    }
    ref.read(legacySettingsRevisionProvider.notifier).bump();
    setState(() {
      _lastPrefs = packages;
      _draft = {...packages};
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('已保存，启动 DNS VPN 后生效'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 把落盘值同步进草稿，并在**别人**改了同一份键时丢弃本地草稿。
  ///
  /// prefs 是唯一真相源：`/hub/excluded-apps` 那张二级页与「HTTPS 检查应用」
  /// 都会写 `excluded_app_packages`，它们写完后如果本页还抱着旧草稿，用户看到
  /// 的就是一份已经不存在的选择集，一旦点「保存」会把对方的改动原样覆盖掉。
  Set<String> _syncDraft(Set<String> persisted) {
    if (!_sameSet(persisted, _lastPrefs)) {
      _lastPrefs = persisted;
      _draft = {...persisted};
    }
    return _draft ??= {...persisted};
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(installedAppsProvider);
    final settings = ref.watch(legacySettingsProvider);

    final persisted = settings.excludedPackages;
    final selected = _syncDraft(persisted);

    final filter = AppListFilter.fromStorageValue(settings.excludedAppsFilterRaw);
    final sort = AppListSort.fromStorageValue(settings.excludedAppsSortRaw);
    final colorScheme = context.colorScheme;

    final apps = snapshot.value?.apps ?? const <InstalledApp>[];
    final loadError = snapshot.value?.error;
    final visible = visibleInstalledApps(
      apps: apps,
      query: _query,
      filter: filter,
      sort: sort,
      selected: selected,
    );
    final labels = {for (final app in apps) app.packageName: app.label};
    final dirty = !_sameSet(selected, persisted);
    final visibleNames = [for (final app in visible) app.packageName];

    return CommonScaffold(
      title: '排除应用',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.selectAll,
          tooltip: '全选当前结果',
          onPressed: visible.isEmpty
              ? null
              : () => setState(
                  () => _draft = {...selected, ...visibleNames},
                ),
        ),
        IconButtonData(
          glyph: AppGlyphs.deselect,
          tooltip: '反选当前结果',
          onPressed: visible.isEmpty
              ? null
              : () => setState(() => _draft = _inverted(selected, visibleNames)),
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
                  settings.setExcludedAppsFilterRaw(option.storageValue);
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
                  settings.setExcludedAppsSortRaw(option.storageValue);
                  ref.read(legacySettingsRevisionProvider.notifier).bump();
                },
              ),
          ],
        ),
        CommonPopupMenuItem(
          label: '清除全部选择',
          glyph: AppGlyphs.broom,
          danger: true,
          onPressed: selected.isEmpty
              ? null
              : () => setState(() => _draft = <String>{}),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                '排除后，应用将使用系统 DNS，不参与本应用的过滤、缓存、日志和统计。'
                '勾选会同时取消它在「禁止联网」「HTTPS 检查」与应用独立规则里的选择。',
                style: context.listSubtitleStyle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              child: StatStrip(
                stats: [
                  StatItem(
                    label: '已安装',
                    value: snapshot.isLoading ? '—' : '${apps.length}',
                    unit: snapshot.isLoading ? null : '个',
                  ),
                  StatItem(
                    label: '已选择',
                    value: '${selected.length}',
                    color: selected.isEmpty
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary,
                  ),
                  StatItem(
                    label: '当前可见',
                    value: '${visible.length}',
                    unit: '个',
                  ),
                ],
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
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SelectedSummary(
                selected: selected,
                labels: labels,
                onClear: () => setState(() => _draft = <String>{}),
              ),
            ),
          if (snapshot.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CommonCircleLoading()),
            )
          else if (loadError != null)
            SizedBox(
              height: 300,
              child: NullStatus(
                label: '读不到应用列表',
                description: loadError,
                illustration: NullStatusIllustration.apps,
                action: TextButton(
                  onPressed: () =>
                      ref.read(installedAppsRevisionProvider.notifier).bump(),
                  child: const Text('重试'),
                ),
              ),
            )
          else if (visible.isEmpty)
            SizedBox(
              height: 300,
              child: NullStatus(
                label: apps.isEmpty ? '没有可排除的应用' : '没有匹配的应用',
                description: apps.isEmpty
                    ? '应用列表读取失败，或设备上只有谛听自身；'
                          '未授权读取应用列表时也会是空的。'
                    : '换个名称或包名片段，或把「过滤」改回「全部应用」。',
                illustration: NullStatusIllustration.apps,
                action: apps.isEmpty
                    ? TextButton(
                        onPressed: () => ref
                            .read(installedAppsRevisionProvider.notifier)
                            .bump(),
                        child: const Text('重试'),
                      )
                    : TextButton(
                        onPressed: () {
                          _search.clear();
                          settings.setExcludedAppsFilterRaw(
                            AppListFilter.all.storageValue,
                          );
                          setState(() => _query = '');
                          ref.read(legacySettingsRevisionProvider.notifier).bump();
                        },
                        child: const Text('清空搜索与筛选'),
                      ),
              ),
            )
          else
            for (final system in const [false, true])
              if (visible.any((app) => app.isSystem == system))
                generateSection(
                  title: system ? '系统应用' : '用户应用',
                  items: [
                    for (final app in visible)
                      if (app.isSystem == system)
                        _AppRow(
                          app: app,
                          selected: selected.contains(app.packageName),
                          onToggle: () => setState(
                            () => _draft = _toggled(selected, app.packageName),
                          ),
                        ),
                  ],
                ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TonalButton(
              label: '保存',
              onPressed: dirty ? () => _save(selected) : null,
            ),
          ),
          ListFooter(
            text: apps.isEmpty
                ? '未读取到任何已安装应用，勾选后不会有任何应用被排除。'
                : '已选择 ${selected.length} / ${apps.length} 个应用。'
                      '保存后写入 excluded_app_packages，启动 DNS VPN 时生效。',
          ),
        ],
      ),
    );
  }

  static Set<String> _toggled(Set<String> selected, String packageName) {
    final next = {...selected};
    if (!next.remove(packageName)) {
      next.add(packageName);
    }
    return next;
  }

  /// 反选只作用于传入的候选集（当前可见项）；候选集外的既有选择保持不变。
  static Set<String> _inverted(Set<String> selected, Iterable<String> visible) {
    final next = {...selected};
    for (final packageName in visible) {
      if (!next.remove(packageName)) {
        next.add(packageName);
      }
    }
    return next;
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

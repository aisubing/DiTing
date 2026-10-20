import 'package:diting/data/mock_system.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 禁止联网应用（上游 `BlockedAppsScreen`）。
///
/// 写 `dns_vpn_prefs` 的 `blocked_app_packages` + `blocked_apps_enabled`；普通
/// 模式启动时会把它换算成 UID 交给 Go 引擎。与「排除应用」「HTTPS 检查应用」
/// 互斥：一处勾选会从另外两处移除，和上游保存时的清洗一致。
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
      onSave: (packages, enabled) {
        settings.setBlockedApps(packages: packages, enabled: enabled);
        settings.setExcludedPackages(settings.excludedPackages.difference(packages));
        settings.setHttpInspectionApps(
          packages: settings.httpInspectionPackages.difference(packages),
          enabled: settings.httpInspectionEnabled && settings.httpInspectionPackages.difference(packages).isNotEmpty,
        );
        ref.read(legacySettingsRevisionProvider.notifier).bump();
      },
    );
  }
}

/// 排除应用（上游 `ExcludedAppsScreen`）。
///
/// 写 `excluded_app_packages`；排除后应用使用系统 DNS，不参与本应用的过滤、
/// 缓存、日志和统计。
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
        settings.setBlockedApps(
          packages: settings.blockedAppPackages.difference(packages),
          enabled: settings.blockedAppsEnabled,
        );
        ref.read(legacySettingsRevisionProvider.notifier).bump();
      },
    );
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
  late final Set<String> _initial = {...widget.selected};
  late final Set<String> _selected = {...widget.selected};
  final TextEditingController _search = TextEditingController();
  late bool _enabled = widget.enabled;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MockPackage> get _visible {
    final query = _query.trim().toLowerCase();
    return [
      for (final app in mockPackages)
        if (query.isEmpty ||
            app.name.toLowerCase().contains(query) ||
            app.packageName.toLowerCase().contains(query))
          app,
    ];
  }

  void _save() {
    widget.onSave({..._selected}, _enabled);
    _initial
      ..clear()
      ..addAll(_selected);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('已保存，启动 DNS VPN 后生效'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
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
          generateSection(
            title: '${widget.selectionTitle}（${_selected.length}）',
            items: [
              for (final app in visible)
                ListItem(
                  leading: GlyphIcon(
                    _selected.contains(app.packageName)
                        ? AppGlyphs.checkCircle
                        : glyphByName(app.glyphName),
                    size: 20,
                    color: _selected.contains(app.packageName)
                        ? context.colorScheme.primary
                        : null,
                  ),
                  title: Text(app.name),
                  subtitle: Text(app.packageName),
                  trailing: CommonCheckBox(
                    value: _selected.contains(app.packageName),
                    isCircle: true,
                    onChanged: (_) => setState(() {
                      if (!_selected.remove(app.packageName)) {
                        _selected.add(app.packageName);
                      }
                    }),
                  ),
                  onTap: () => setState(() {
                    if (!_selected.remove(app.packageName)) {
                      _selected.add(app.packageName);
                    }
                  }),
                ),
            ],
            footer: visible.isEmpty ? '未找到匹配应用' : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TonalButton(label: '保存', onPressed: dirty ? _save : null),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

import 'package:diting/data/mock_system.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:material_ui/material_ui.dart';

/// 禁止联网应用（上游 `BlockedAppsScreen`）。
class BlockedAppsPage extends StatelessWidget {
  const BlockedAppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppSelectionScaffold(
      title: '禁止联网应用',
      info: '通过本机 VPN 按 UID 阻止所选应用的全部网络连接。共享同一 UID 的应用会一并受影响。',
      enableToggleTitle: '启用禁止联网',
      enableToggleEmptyHint: '尚未选择应用；开启后不会阻断流量',
      selectionTitle: '禁止联网的应用',
      icon: AppGlyphs.wifiOff,
      initial: {'com.example.video', 'com.example.games'},
    );
  }
}

/// 排除应用（上游 `ExcludedAppsScreen`）。
class ExcludedAppsPage extends StatelessWidget {
  const ExcludedAppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppSelectionScaffold(
      title: '排除应用',
      info: '排除后，应用将使用系统 DNS，不参与本应用的过滤、缓存、日志和统计。',
      selectionTitle: '排除的应用',
      icon: AppGlyphs.appsList,
      initial: {'com.android.updater'},
    );
  }
}

class _AppSelectionScaffold extends StatefulWidget {
  const _AppSelectionScaffold({
    required this.title,
    required this.info,
    required this.selectionTitle,
    required this.icon,
    required this.initial,
    this.enableToggleTitle,
    this.enableToggleEmptyHint,
  });

  final String title;
  final String info;
  final String selectionTitle;
  final Glyph icon;
  final Set<String> initial;
  final String? enableToggleTitle;
  final String? enableToggleEmptyHint;

  @override
  State<_AppSelectionScaffold> createState() => _AppSelectionScaffoldState();
}

class _AppSelectionScaffoldState extends State<_AppSelectionScaffold> {
  late final Set<String> _initial = {...widget.initial};
  late final Set<String> _selected = {...widget.initial};
  late final TextEditingController _search = TextEditingController();
  bool _enabled = true;
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
    final dirty = _enabled != true || !_sameSet(_selected, _initial);
    return CommonScaffold(
      title: widget.title,
      body: PageBody(
        children: [
          if (widget.enableToggleTitle != null)
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
            child: TonalButton(
              label: '保存',
              onPressed: dirty ? _save : null,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

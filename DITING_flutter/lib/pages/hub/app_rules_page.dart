// ignore_for_file: sort_child_properties_last
import 'package:diting/data/mock_system.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:diting/widgets/glyph_lookup.dart';
import 'package:material_ui/material_ui.dart';

/// 应用独立规则（上游 `AppRuleManagementScreen` + `SingleAppRulePanel`）。
///
/// 列表页：总开关、搜索、已配置应用；点进某个应用后在同一路由内切换到
/// 详情面板（上游也是 `BackHandler` 返回列表，而不是新路由）。
class AppRulesPage extends StatefulWidget {
  const AppRulesPage({super.key});

  @override
  State<AppRulesPage> createState() => _AppRulesPageState();
}

class _AppRuleEntry {
  _AppRuleEntry({this.enabled = true, this.important = false});

  bool enabled;
  bool important;
}

class _AppRulesPageState extends State<AppRulesPage> {
  final _search = TextEditingController();
  bool _master = true;
  String? _selected;
  String _query = '';
  final Map<String, Set<String>> _allowDomains = {
    'com.example.browser': {'api.example.com', 'static.example.com'},
  };
  final Map<String, bool> _fullBlock = {'com.example.video': true};
  final Map<String, Map<String, _AppRuleEntry>> _blockRules = {
    'com.example.browser': {
      '||ads.example.com^': _AppRuleEntry(),
      '||tracker.example.net^': _AppRuleEntry(enabled: false),
    },
    'com.example.video': {'||ad.video.example^': _AppRuleEntry()},
  };
  final Map<String, Map<String, _AppRuleEntry>> _allowRules = {
    'com.example.browser': {'||cdn.example.com^': _AppRuleEntry()},
  };

  MockPackage? _packageOf(String packageName) =>
      mockPackages.where((item) => item.packageName == packageName).firstOrNull;

  int _ruleCount(String packageName) =>
      (_blockRules[packageName]?.length ?? 0) +
      (_allowRules[packageName]?.length ?? 0);

  int _domainCount(String packageName) =>
      _allowDomains[packageName]?.length ?? 0;

  List<MockPackage> get _visible {
    final query = _query.trim().toLowerCase();
    final items = [
      for (final app in mockPackages)
        if (query.isEmpty ||
            app.name.toLowerCase().contains(query) ||
            app.packageName.toLowerCase().contains(query))
          app,
    ];
    items.sort((a, b) {
      final aConfigured = _ruleCount(a.packageName) > 0 ||
          _domainCount(a.packageName) > 0;
      final bConfigured = _ruleCount(b.packageName) > 0 ||
          _domainCount(b.packageName) > 0;
      if (aConfigured != bConfigured) {
        return aConfigured ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });
    return items;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPackage = _selected == null ? null : _packageOf(_selected!);
    return PopScope(
      canPop: selectedPackage == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selectedPackage != null) {
          setState(() => _selected = null);
        }
      },
      child: selectedPackage == null
          ? _buildList(context)
          : _buildDetail(context, selectedPackage),
    );
  }

  Widget _buildList(BuildContext context) {
    final configured = mockPackages
        .where(
          (app) => _ruleCount(app.packageName) > 0 || _domainCount(app.packageName) > 0,
        )
        .length;
    final totalRules = _blockRules.values.fold<int>(
      0,
      (sum, map) => sum + map.length,
    );
    final totalDomains = _allowDomains.values.fold<int>(
      0,
      (sum, set) => sum + set.length,
    );
    final visible = _visible;
    final hasAllowlist =
        _allowDomains.values.any((domains) => domains.isNotEmpty) ||
        _allowRules.values.any((rules) => rules.isNotEmpty);
    return CommonScaffold(
      title: '应用独立规则',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.broom,
          tooltip: '清空全部放行规则',
          onPressed: hasAllowlist ? _clearAllAllowlist : null,
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
                  configured == 0
                      ? '暂未配置任何应用独立规则'
                      : '已配置 $configured 个应用 · 放行 $totalDomains 个域名 · DNS 规则 $totalRules 条',
                ),
                value: _master,
                onChanged: (value) => setState(() => _master = value),
              ),
            ],
            footer: '为指定应用深度定制网络与解析控制。支持网络层白名单隔离、'
                'DNS 专属黑白名单及「默认拦截全部外联」向导模式。',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SearchField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          generateSection(
            title: '应用（${visible.length}）',
            items: [
              for (final app in visible)
                ListItem(
                  leading: GlyphIcon(
                    glyphByName(app.glyphName),
                    size: 20,
                    color: _ruleCount(app.packageName) > 0 ||
                            _domainCount(app.packageName) > 0
                        ? context.colorScheme.primary
                        : null,
                  ),
                  title: Text(app.name),
                  subtitle: Text(
                    '${app.packageName} · '
                    '${_ruleCount(app.packageName)} 条规则 · '
                    '${_domainCount(app.packageName)} 个放行域名',
                  ),
                  trailing: _fullBlock[app.packageName] == true
                      ? const MetaChip(label: '全阻断')
                      : null,
                  onTap: () => setState(() => _selected = app.packageName),
                ),
            ],
            footer: visible.isEmpty ? '未找到匹配应用' : null,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDetail(BuildContext context, MockPackage app) {
    final domains = _allowDomains[app.packageName] ?? <String>{};
    final blockRules = _blockRules[app.packageName] ?? <String, _AppRuleEntry>{};
    final allowRules = _allowRules[app.packageName] ?? <String, _AppRuleEntry>{};
    final fullBlock = _fullBlock[app.packageName] ?? false;
    return CommonScaffold(
      title: app.name,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加规则',
          onPressed: () => _addRule(app.packageName),
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
            title: '外联与隔离模式',
            items: [
              ListItem.toggle(
                leading: const GlyphIcon(AppGlyphs.wifiOff),
                title: const Text('默认拦截全部外联'),
                subtitle: const Text('开启后阻断该应用的所有网络连接，仅放行白名单'),
                value: fullBlock,
                onChanged: (value) async {
                  if (value) {
                    final confirmed = await showFloatingDialog<bool>(
                      context: context,
                      child: CommonDialog(
                        title: '开启全阻断模式？',
                        destructive: true,
                        child: const Text(
                          '开启后该应用的所有外联都会被阻断，仅放行下方白名单域名。'
                          '请确保已添加必要的放行域名，否则应用可能无法联网。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('仍然开启'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !mounted) {
                      return;
                    }
                  }
                  setState(() => _fullBlock[app.packageName] = value);
                },
              ),
            ],
          ),
          generateSection(
            title: '专属放行域名（网络层） (${domains.length})',
            actions: [
              IconButtonData(
                glyph: AppGlyphs.add,
                tooltip: '添加放行域名',
                onPressed: () => _addDomain(app.packageName),
              ),
            ],
            items: [
              if (domains.isEmpty)
                const ListItem(
                  title: Text('未配置网络放行域名'),
                  subtitle: Text('全阻断模式下建议至少添加一个必要域名'),
                  leading: GlyphIcon(AppGlyphs.info),
                ),
              for (final domain in domains.toList()..sort())
                ListItem(
                  leading: const GlyphIcon(AppGlyphs.verified, size: 20),
                  title: Text(domain),
                  subtitle: const Text('包含子域名'),
                  trailing: IconButton(
                    tooltip: '删除',
                    onPressed: () => setState(
                      () => _allowDomains[app.packageName]?.remove(domain),
                    ),
                    icon: const GlyphIcon(AppGlyphs.delete, size: 20),
                  ),
                ),
            ],
          ),
          generateSection(
            title: 'DNS 专属黑名单 (${blockRules.length})',
            items: [
              for (final entry in blockRules.entries)
                _RuleRow(
                  pattern: entry.key,
                  entry: entry.value,
                  onToggle: () => setState(
                    () => entry.value.enabled = !entry.value.enabled,
                  ),
                  onDelete: () => setState(
                    () => _blockRules[app.packageName]?.remove(entry.key),
                  ),
                ),
            ],
            footer: blockRules.isEmpty ? '暂无专属黑名单规则' : null,
          ),
          generateSection(
            title: 'DNS 专属白名单 (${allowRules.length})',
            items: [
              for (final entry in allowRules.entries)
                _RuleRow(
                  pattern: entry.key,
                  entry: entry.value,
                  onToggle: () => setState(
                    () => entry.value.enabled = !entry.value.enabled,
                  ),
                  onDelete: () => setState(
                    () => _allowRules[app.packageName]?.remove(entry.key),
                  ),
                ),
            ],
            footer: allowRules.isEmpty ? '暂无专属白名单规则' : null,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _clearAllAllowlist() async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '清空全部放行规则？',
        destructive: true,
        child: const Text(
          '将删除所有应用的专属放行域名与 DNS 白名单规则，黑名单与全阻断设置不受影响。',
        ),
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
    setState(() {
      _allowDomains.clear();
      _allowRules.clear();
    });
  }

  Future<void> _addDomain(String packageName) async {
    final controller = TextEditingController();
    final domain = await showFloatingDialog<String>(
      context: context,
      child: CommonDialog(
        title: '添加放行域名',
        hasFields: true,
        child: TextField(
          controller: controller,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: '域名',
            hintText: 'api.example.com',
            helperText: '包含子域名；不需要写通配符',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) {
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (domain == null || !mounted) {
      return;
    }
    setState(() {
      _allowDomains.putIfAbsent(packageName, () => {}).add(domain);
    });
  }

  Future<void> _addRule(String packageName) async {
    final controller = TextEditingController();
    var allow = false;
    var important = false;
    final result = await showFloatingDialog<({String pattern, bool allow})>(
      context: context,
      child: StatefulBuilder(
        builder: (context, setDialogState) => CommonDialog(
          title: '添加 DNS 规则',
          hasFields: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              SegmentedControl<bool>(
                segments: const [(false, '黑名单'), (true, '白名单')],
                value: allow,
                onChanged: (value) => setDialogState(() => allow = value),
              ),
              TextField(
                controller: controller,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '规则内容',
                  hintText: '||ads.example.com^',
                ),
              ),
              ListItem.toggle(
                title: const Text('标记为重要规则'),
                value: important,
                padding: EdgeInsets.zero,
                onChanged: (value) => setDialogState(() => important = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  return;
                }
                Navigator.of(context).pop((pattern: value, allow: allow));
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      final map = result.allow
          ? _allowRules.putIfAbsent(packageName, () => {})
          : _blockRules.putIfAbsent(packageName, () => {});
      map[result.pattern] = _AppRuleEntry(important: important);
    });
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.pattern,
    required this.entry,
    required this.onToggle,
    required this.onDelete,
  });

  final String pattern;
  final _AppRuleEntry entry;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: GlyphIcon(
        entry.enabled ? AppGlyphs.checkCircle : AppGlyphs.removeCircle,
        size: 20,
      ),
      title: Text(pattern),
      subtitle: Text(entry.important ? '重要规则 · 优先匹配' : '普通规则'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CommonCheckBox(value: entry.enabled, onChanged: (_) => onToggle()),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: const GlyphIcon(AppGlyphs.delete, size: 20),
          ),
        ],
      ),
      onTap: onToggle,
    );
  }
}

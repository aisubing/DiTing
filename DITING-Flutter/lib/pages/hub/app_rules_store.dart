/// 应用独立规则的草稿模型、列表筛选与行组件。
///
/// 从 `app_rules_page.dart` 拆出来是因为那个文件本来就有 502 行，再往里加
/// 「真实数据源 + 持久化 + 过滤排序」必然突破 550 的上限。
///
/// 数据源分工（1.4.3 的 `AppRuleViewModel`）：
/// - **网络层放行域名**（白名单隔离）：`app_allowlist_rules_json`，一个
///   `Map<包名, Set<域名>>`，引擎侧走 `Engine.setAppAllowlist`；本文件只碰这一份。
/// - **DNS 专属黑/白名单**：1.4.3 存在 Room 的 `block_rule` / `allow_rule` 里，
///   靠 `appScope` 列区分应用。现在 `RuleRepository` 已补上按应用读写
///   （`loadForApp` / `addForApp` / `setFullBlock`），页面用
///   `appScopedRulesProvider` 读、`AppScopedRulesController` 写；规则随快照的
///   `appRules[pkg]` 下发，不会泄露成全局拦截。
/// - **默认拦截全部外联**：上游是往 `block_rule` 注入 `*$app=<包名>`（`setFullBlock`），
///   由「外联与隔离模式」里的开关真实读写。
library;

import 'package:diting/data/mock_data.dart';
import 'package:diting/data/native/apps_bridge.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/installed_apps_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 页面内的可变草稿：总开关 + 每应用的放行域名。
///
/// 用可变对象而不是每键复制整张 map：详情面板里增删域名时都改它，保存时才落盘，
/// 与上游「面板里即时落盘、列表页读回」的行为不同却有同样的可见结果——1.4.3
/// 的 `SingleAppRulePanel` 也是每次增删立刻写 `setAppAllowlistDomainsForApp`，
/// 但它同时刷新了 `appAllowlistMap`，所以用户看不出差别。这里选择「保存时一次
/// 写入」，好处是取消/返回不会留下半改状态。
class AppRulesDraft {
  AppRulesDraft({required this.master, required Map<String, Set<String>> rules})
    : _baseline = _copy(rules),
      _baselineMaster = master,
      _rules = _copy(rules);

  /// 从 prefs 建草稿。
  factory AppRulesDraft.load(LegacySettings settings) => AppRulesDraft(
    master: settings.appAllowlistEnabled,
    rules: settings.appAllowlistRules,
  );

  /// `app_allowlist_enabled` 总开关。
  bool master;

  final Map<String, Set<String>> _baseline;
  final Map<String, Set<String>> _rules;
  bool _baselineMaster;

  Map<String, Set<String>> get rules => _rules;

  /// 已配置的应用数（只算放行域名非空的）。
  int get configuredApps => _rules.length;

  int get totalDomains =>
      _rules.values.fold<int>(0, (sum, domains) => sum + domains.length);

  Set<String> domainsOf(String packageName) => _rules[packageName] ?? const {};

  bool isConfigured(String packageName) => domainsOf(packageName).isNotEmpty;

  void addDomain(String packageName, String domain) {
    final trimmed = domain.trim();
    if (trimmed.isEmpty) {
      return;
    }
    (_rules[packageName] ??= <String>{}).add(trimmed);
  }

  void removeDomain(String packageName, String domain) {
    final domains = _rules[packageName];
    if (domains == null) {
      return;
    }
    domains.remove(domain);
    if (domains.isEmpty) {
      // 空集合与「没配置」在 1.4.3 里等价（`getAppAllowlistRuleMap` 只保留非空
      // 项），留着空集合会让列表页把该应用算成「已配置」。
      _rules.remove(packageName);
    }
  }

  void clearDomains(String packageName) => _rules.remove(packageName);

  void clearAll() => _rules.clear();

  /// 草稿是否与落盘值不同（决定「保存」按钮是否可点）。
  bool get dirty {
    if (master != _baselineMaster) {
      return true;
    }
    if (_rules.length != _baseline.length) {
      return true;
    }
    for (final entry in _rules.entries) {
      final baseline = _baseline[entry.key];
      if (baseline == null || baseline.length != entry.value.length) {
        return true;
      }
      if (!baseline.containsAll(entry.value)) {
        return true;
      }
    }
    return false;
  }

  /// 记下新基线（保存成功后调用，让「保存」按钮回到不可点）。
  void commit() {
    _baseline
      ..clear()
      ..addAll(_copy(_rules));
    _baselineMaster = master;
  }

  /// 落盘值的指纹，和 [appRulesKey] 同一套编码。
  String get baselineKey => appRulesKey(_baselineMaster, _baseline);

  static Map<String, Set<String>> _copy(Map<String, Set<String>> source) => {
    for (final entry in source.entries) entry.key: {...entry.value},
  };
}

/// 判断 prefs 上的值是否变了（用于决定要不要丢弃本地草稿）。
///
/// 不用 `==` 比 map/set：`LegacySettings` 每次都返回新建的对象，深比较更直观
/// 也便宜（规则条数是个位数）。签名里包名与域名都排过序，所以「别人的写入」
/// 与「自己刚保存的值」会被视为同一个状态。
String appRulesKey(bool master, Map<String, Set<String>> rules) {
  final parts = <String>[];
  for (final packageName in rules.keys.toList()..sort()) {
    final domains = rules[packageName]!.toList()..sort();
    parts.add('$packageName=${domains.join(',')}');
  }
  return '$master|${parts.join(';')}';
}

/// 落盘：`app_allowlist_enabled` + `app_allowlist_rules_json`。
///
/// 写后必须 `bump()`：`SharedPreferences` 写入不可观察，不 bump 的话其他页面
/// （以及本页重建后的列表）会一直读旧值。
void saveAppRules(WidgetRef ref, AppRulesDraft draft) {
  ref.writeSettings((settings) {
    settings.setAppAllowlistEnabled(draft.master);
    settings.setAppAllowlistRules(draft.rules);
  });
}

/// 列表排序：已配置的排前面（1.4.3 的 `compareByDescending { hasAnyConfig }`），
/// 其余按选中的 `AppListSort`。
List<InstalledApp> appRulesVisibleApps({
  required List<InstalledApp> apps,
  required String query,
  required AppListFilter filter,
  required AppListSort sort,
  required AppRulesDraft draft,
}) {
  final needle = query.trim().toLowerCase();
  final configured = {
    for (final app in apps)
      if (draft.isConfigured(app.packageName)) app.packageName,
  };
  final visible = [
    for (final app in apps)
      if (filter.accept(app, configured) && app.matches(needle)) app,
  ];
  visible.sort((a, b) {
    final aConfigured = draft.isConfigured(a.packageName);
    final bConfigured = draft.isConfigured(b.packageName);
    if (aConfigured != bConfigured) {
      return aConfigured ? -1 : 1;
    }
    return sort.compare(a, b);
  });
  return visible;
}

/// 应用列表里的一行：名称 + 包名 + 放行域名数。
class AppRuleAppRow extends StatelessWidget {
  const AppRuleAppRow({
    super.key,
    required this.app,
    required this.domainCount,
    required this.onTap,
  });

  final InstalledApp app;
  final int domainCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final configured = domainCount > 0;
    return ListItem(
      leading: GlyphIcon(
        configured ? AppGlyphs.checkCircle : AppGlyphs.appsList,
        size: 20,
        color: configured ? context.colorScheme.primary : null,
      ),
      title: Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${app.packageName} · $domainCount 个放行域名',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyle.footnote.of(context),
      ),
      trailing: app.isSystem ? const MetaChip(label: '系统') : null,
      onTap: onTap,
    );
  }
}

/// 一条放行域名（详情面板里的一行）。
class AppAllowDomainRow extends StatelessWidget {
  const AppAllowDomainRow({
    super.key,
    required this.domain,
    required this.onDelete,
  });

  final String domain;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: const GlyphIcon(AppGlyphs.verified, size: 20),
      title: Text(domain, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: const Text('包含子域名'),
      trailing: IconButton(
        tooltip: '删除',
        onPressed: onDelete,
        icon: const GlyphIcon(AppGlyphs.delete, size: 20),
      ),
    );
  }
}

/// 「添加放行域名」对话框，返回清洗后的域名或 null。
Future<String?> showAppAllowDomainDialog(BuildContext context) async {
  return showFloatingDialog<String>(
    context: context,
    child: const _AllowDomainDialog(),
  );
}

/// 放行域名输入弹窗；控制器由弹窗自己持有（见 `InputDialog` 的同一套生命周期：
/// 调用方 `await` 之后立刻 dispose 会在退场动画中途把输入框的依赖弄失效）。
class _AllowDomainDialog extends StatefulWidget {
  const _AllowDomainDialog();

  @override
  State<_AllowDomainDialog> createState() => _AllowDomainDialogState();
}

class _AllowDomainDialogState extends State<_AllowDomainDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '添加放行域名',
      hasFields: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _submit, child: const Text('添加')),
      ],
      child: TextField(
        controller: _controller,
        autocorrect: false,
        autofocus: true,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: '域名',
          hintText: 'api.example.com',
          helperText: '只填裸域名；包含子域名，不需要写通配符或 @@ 前缀',
        ),
      ),
    );
  }
}

/// 一条按应用生效的 DNS 规则（黑/白名单）行。
class AppScopedRuleRow extends StatelessWidget {
  const AppScopedRuleRow({
    super.key,
    required this.rule,
    required this.onToggle,
    required this.onDelete,
  });

  final MockRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isAllow = rule.kind == RuleKind.allow;
    return ListItem(
      leading: GlyphIcon(
        isAllow ? AppGlyphs.verified : AppGlyphs.block,
        size: 20,
        color: isAllow ? context.colorScheme.primary : context.colorScheme.error,
      ),
      title: Text(rule.pattern, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(isAllow ? '白名单（放行）' : '黑名单（拦截）'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rule.important) const MetaChip(label: '重要'),
          IconButton(
            tooltip: rule.enabled ? '停用' : '启用',
            onPressed: () => onToggle(!rule.enabled),
            icon: GlyphIcon(
              rule.enabled ? AppGlyphs.check : AppGlyphs.close,
              size: 20,
            ),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: const GlyphIcon(AppGlyphs.delete, size: 20),
          ),
        ],
      ),
    );
  }
}

/// 「添加 DNS 规则」对话框的返回值：类型 + 清洗后的域名。
typedef AppScopedRuleInput = ({RuleKind kind, String pattern});

/// 「添加 DNS 专属规则」对话框：选黑/白名单 + 填裸域名。
///
/// 与放行域名对话框同一套输入清洗：只接受裸域名，避免把 `@@||x^` 这类未解析的
/// 规则串原样写进 `block_rule` / `allow_rule`（引擎读到的会是一个永远匹配不上的
/// 字符串）。控制器由弹窗自己持有（见 `InputDialog` 的生命周期约定）。
Future<AppScopedRuleInput?> showAppScopedRuleDialog(
  BuildContext context,
  String packageName,
) async {
  return showFloatingDialog<AppScopedRuleInput>(
    context: context,
    child: const _ScopedRuleDialog(),
  );
}

class _ScopedRuleDialog extends StatefulWidget {
  const _ScopedRuleDialog();

  @override
  State<_ScopedRuleDialog> createState() => _ScopedRuleDialogState();
}

class _ScopedRuleDialogState extends State<_ScopedRuleDialog> {
  final _controller = TextEditingController();
  var _kind = RuleKind.block;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final pattern = _controller.text.trim();
    if (pattern.isEmpty) {
      return;
    }
    Navigator.of(context).pop((kind: _kind, pattern: pattern));
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: '添加 DNS 规则',
      hasFields: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _submit, child: const Text('添加')),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedControl<RuleKind>(
            segments: const [
              (RuleKind.block, '黑名单'),
              (RuleKind.allow, '白名单'),
            ],
            value: _kind,
            onChanged: (value) => setState(() => _kind = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autocorrect: false,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: '域名',
              hintText: 'ads.example.com',
              helperText: '只填裸域名；仅对本应用生效',
            ),
          ),
        ],
      ),
    );
  }
}

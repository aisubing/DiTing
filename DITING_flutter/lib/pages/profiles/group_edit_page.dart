import 'package:diting/data/mock_profiles.dart';
import 'package:diting/pages/profiles/proxy_groups_page.dart';
import 'package:diting/routes/profiles_routes.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 代理组编辑页（上游 `EditProxyGroupView`）。
///
/// 字段按类型条件显示，而不是全部铺开再灰掉：
/// - 手动选择：只要成员；
/// - 自动测速 / 故障转移：加测速地址与间隔、容差；
/// - 负载均衡：加策略；
/// - 链式代理：加成员顺序说明（顺序即链路）；
/// - 所有类型都可以有筛选正则与 `use` 引用。
///
/// 这样每个类型点进来只看到与自己相关的四五项，与上游一致。
class GroupEditPage extends ConsumerStatefulWidget {
  const GroupEditPage({
    super.key,
    required this.profileId,
    required this.groupId,
  });

  final String profileId;
  final String groupId;

  @override
  ConsumerState<GroupEditPage> createState() => _GroupEditPageState();
}

class _GroupEditPageState extends ConsumerState<GroupEditPage> {
  final _name = TextEditingController();
  final _filter = TextEditingController();
  final _probeUrl = TextEditingController();
  final _interval = TextEditingController();
  var _kind = GroupKind.selector;
  var _strategy = BalanceStrategy.consistentHashing;
  var _hidden = false;
  var _lazy = true;
  final _use = <String>{};
  var _loaded = false;

  MockProxyGroup? get _group => _findGroup(ref.read(proxyGroupsProvider));

  MockProxyGroup? _findGroup(List<MockProxyGroup> groups) {
    for (final group in groups) {
      if (group.id == widget.groupId) {
        return group;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final group = _group;
    if (group == null) {
      _loaded = true;
      return;
    }
    _name.text = group.name;
    _filter.text = group.filter;
    _probeUrl.text = group.probeUrl;
    _interval.text = '${group.intervalSeconds}';
    _kind = group.kind;
    _strategy = group.strategy;
    _hidden = group.hidden;
    _lazy = group.lazy;
    _use.addAll(group.useProviders);
    _loaded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _filter.dispose();
    _probeUrl.dispose();
    _interval.dispose();
    super.dispose();
  }

  void _save() {
    final group = _group;
    if (group == null || _name.text.trim().isEmpty) {
      return;
    }
    final interval = int.tryParse(_interval.text.trim()) ?? 300;
    final notifier = ref.read(proxyGroupsProvider.notifier);
    final saved = notifier.put(
      group.copyWith(
        name: _name.text.trim(),
        kind: _kind,
        filter: _filter.text.trim(),
        probeUrl: _probeUrl.text.trim(),
        intervalSeconds: interval.clamp(10, 86400),
        strategy: _strategy,
        hidden: _hidden,
        lazy: _lazy,
        useProviders: _use.toList(),
      ),
    );
    if (!saved) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('已有同名代理组'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1600),
        ),
      );
      return;
    }
    context.safeNestedPop();
  }

  Future<void> _pickIcon() async {
    final group = _group;
    if (group == null) {
      return;
    }
    final icon = await context.push<String>(
      ProfilesPaths.iconOf(widget.profileId, current: group.icon),
    );
    if (icon != null && icon.isNotEmpty) {
      ref.read(proxyGroupsProvider.notifier).setIcon(group.id, icon);
      setState(() {});
    }
  }

  Future<void> _delete() async {
    final localizations = UiLocalizations.of(context);
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除代理组',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
        child: const Text('把流量指向这个组的规则会失效。'),
      ),
    );
    if ((confirmed ?? false) && mounted) {
      ref.read(proxyGroupsProvider.notifier).remove({widget.groupId});
      context.safeNestedPop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    if (!_loaded || group == null) {
      return CommonScaffold(
        title: '编辑代理组',
        body: const AppBarClearance(
          child: SizedBox(
            height: 320,
            child: NullStatus(
              label: '代理组不存在',
              description: '它可能已被删除',
              illustration: NullStatusIllustration.proxies,
            ),
          ),
        ),
      );
    }
    final proxies = ref.watch(customProxiesProvider);
    final providers = ref.watch(proxyProvidersProvider);
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '编辑代理组',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '保存',
        onPressed: _save,
      ),
      menuItems: [
        CommonPopupMenuItem(
          label: '选择成员',
          glyph: AppGlyphs.selectAll,
          onPressed: () => context.push(
            ProfilesPaths.groupMembersOf(widget.profileId, widget.groupId),
          ),
        ),
        CommonPopupMenuItem(
          label: '删除组',
          glyph: AppGlyphs.delete,
          danger: true,
          onPressed: _delete,
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            // 横向 16 交给 `generateSection`，外层再加会让组头缩进 32。
            padding: const EdgeInsets.only(top: 8),
            child: generateSection(
              title: '基本信息',
              items: [
                _GroupFieldRow(
                  label: '名称',
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(hintText: '组名'),
                  ),
                ),
                ListItem<GroupKind>.options(
                  title: const Text('类型'),
                  subtitle: Text(_kind.description),
                  options: GroupKind.values,
                  value: _kind,
                  textBuilder: (kind) => kind.label,
                  onChanged: (kind) => setState(() => _kind = kind),
                ),
                ListItem(
                  leading: GlyphIcon(groupGlyphOf(group)),
                  title: const Text('图标'),
                  subtitle: Text(
                    group.icon.isEmpty ? '按类型自动选择' : group.icon,
                    style: context.listCaptionStyle,
                  ),
                  trailing: const DisclosureIndicator(),
                  onTap: _pickIcon,
                ),
              ],
            ),
          ),
          Padding(
            // 横向 16 交给 `generateSection`，外层再加会让组头缩进 32。
            padding: const EdgeInsets.only(top: 24),
            child: generateSection(
              title: '成员',
              items: [
                ListItem(
                  leading: const GlyphIcon(AppGlyphs.layers),
                  title: const Text('选择成员'),
                  subtitle: Text(
                    group.members.isEmpty
                        ? '还没有成员'
                        : '${group.members.length} 个：${group.members.take(3).join('、')}'
                              '${group.members.length > 3 ? '…' : ''}',
                    style: context.listCaptionStyle,
                  ),
                  trailing: const DisclosureIndicator(),
                  onTap: () => context.push(
                    ProfilesPaths.groupMembersOf(
                      widget.profileId,
                      widget.groupId,
                    ),
                  ),
                ),
                _GroupFieldRow(
                  label: '筛选正则',
                  child: TextField(
                    controller: _filter,
                    style: const TextStyle(fontFamily: 'JetBrainsMono'),
                    decoration: const InputDecoration(hintText: '如：香港|HK'),
                  ),
                ),
              ],
              footer: _kind == GroupKind.relay
                  ? '链式代理按成员顺序逐跳转发，顺序错了会绕远路。'
                  : '筛选正则会自动把匹配到的节点加进组里，与手动选择的成员合并。',
            ),
          ),
          if (_kind.needsProbe || _kind.needsStrategy)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: generateSection(
                title: '策略参数',
                items: [
                  if (_kind.needsProbe) ...[
                    _GroupFieldRow(
                      label: '测速地址',
                      child: TextField(
                        controller: _probeUrl,
                        style: const TextStyle(fontFamily: 'JetBrainsMono'),
                        decoration: const InputDecoration(
                          hintText: 'https://www.gstatic.com/generate_204',
                        ),
                      ),
                    ),
                    _GroupFieldRow(
                      label: '测速间隔',
                      child: TextField(
                        controller: _interval,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontFamily: 'JetBrainsMono'),
                        decoration: const InputDecoration(
                          hintText: '300',
                          suffixText: '秒',
                        ),
                      ),
                    ),
                  ],
                  if (_kind.needsStrategy)
                    ListItem<BalanceStrategy>.options(
                      title: const Text('负载均衡策略'),
                      subtitle: const Text('轮询最公平，会话保持适合需要固定出口的服务'),
                      options: BalanceStrategy.values,
                      value: _strategy,
                      textBuilder: (strategy) => strategy.label,
                      onChanged: (strategy) =>
                          setState(() => _strategy = strategy),
                    ),
                ],
              ),
            ),
          if (providers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: generateSection(
                title: '引用提供者',
                items: [
                  for (final provider in providers)
                    ListItem.checkbox(
                      title: Text(provider.name),
                      subtitle: Text(
                        '${provider.proxyCount} 个节点 · ${provider.updatedAt}',
                        style: context.listCaptionStyle,
                      ),
                      value: _use.contains(provider.name),
                      onChanged: (value) => setState(() {
                        if (value ?? false) {
                          _use.add(provider.name);
                        } else {
                          _use.remove(provider.name);
                        }
                      }),
                    ),
                ],
                footer: '勾选后组会自动包含该提供者拉到的全部节点。',
              ),
            ),
          Padding(
            // 横向 16 交给 `generateSection`，外层再加会让组头缩进 32。
            padding: const EdgeInsets.only(top: 24),
            child: generateSection(
              title: '显示',
              items: [
                ListItem.toggle(
                  title: const Text('在选择器里隐藏'),
                  subtitle: const Text('隐藏的组只能用在该组的 proxy-groups 里'),
                  value: _hidden,
                  onChanged: (value) => setState(() => _hidden = value),
                ),
                ListItem.toggle(
                  title: const Text('懒加载'),
                  subtitle: const Text('没有流量经过时不测速，省电'),
                  value: _lazy,
                  onChanged: (value) => setState(() => _lazy = value),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16)
                .copyWith(top: 24),
            child: CommonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KeyValueRow(label: '成员数', value: '${group.members.length}'),
                  KeyValueRow(
                    label: '可用节点',
                    value: '${proxies.length} 个',
                    monospace: true,
                  ),
                  KeyValueRow(
                    label: '成员顺序',
                    value: group.kind == GroupKind.relay ? '决定链路' : '决定优先级',
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '改动保存后立即生效；正在使用这个组的连接会按新策略重新选择。',
                    style: context.listCaptionStyle.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 表单行：左标签 + 右输入框。
class _GroupFieldRow extends StatelessWidget {
  const _GroupFieldRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        spacing: 12,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: context.listTitleStyle),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

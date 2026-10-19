/// 代理页（上游 `views/proxies/proxies.dart`，2,660 行域）。
///
/// 单页双形态：**标签页形式**（顶部组 chip 条，一次显示一组）与**列表形式**
/// （所有组纵向堆叠、可折叠）。上游也是同一个 View 切两种 body，所以这里不分
/// 两条路由——切换只改 `proxiesSettingsProvider.type`。
///
/// 顶栏承载：搜索、测速全部、定位当前节点、设置菜单。
library;

import 'package:diting/data/mock_proxies.dart';
import 'package:diting/pages/proxies/proxies_settings_sheet.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:diting/pages/proxies/proxy_group_section.dart';
import 'package:diting/routes/routes.dart';
import 'package:diting/state/proxies_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class ProxiesPage extends ConsumerStatefulWidget {
  const ProxiesPage({super.key});

  @override
  ConsumerState<ProxiesPage> createState() => _ProxiesPageState();
}

class _ProxiesPageState extends ConsumerState<ProxiesPage> {
  /// tab 形式下当前显示的组名。
  ///
  /// 存名字而不是下标：搜索过滤会改变可见组的顺序与数量，下标会指到别的组。
  String? _activeGroup;

  void _hint(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  Future<void> _openSettings() async {
    await showExtend(
      context,
      builder: (context) => const ProxiesSettingsSheet(),
    );
  }

  /// 长按节点：延迟测试 / 复制名字。
  Future<void> _showNodeMenu(ProxyGroupView group, ProxyNodeView node) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _NodeMenuSheet(groupName: group.name, node: node),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'test':
        await ref.read(proxiesProvider.notifier).testGroup(group.name);
      case 'copy':
        _hint('已复制「${node.name}」');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(proxiesSettingsProvider);
    final state = ref.watch(proxiesProvider);
    final groups = ref.watch(visibleProxyGroupsProvider);
    final notifier = ref.read(proxiesProvider.notifier);

    // 过滤后当前组可能不在列表里：回退到第一个可见组，避免整页空着但 chip 条
    // 还高亮着一个不存在的组。
    final activeName = _resolvedActiveGroup(groups);

    return CommonScaffold(
      title: '代理',
      searchState: AppBarSearchState(
        onSearch: notifier.setQuery,
        // **不要**传 `query:`。`CommonScaffold` 用 `searchState.query != null`
        // 判断「当前是否处于搜索模式」（`scaffold_a.dart:13` 的 `_isSearch`），
        // 传了非空 query 会让页面一进来就展开搜索框、藏掉标题与下面所有组。
        // 搜索词的「当前值」由 provider 持有，不需要回灌给顶栏。
      ),
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.speed,
          tooltip: state.testingAll ? '测速中…' : '测速全部',
          onPressed: state.testingAll ? null : notifier.testAll,
        ),
        IconButtonData(
          glyph: AppGlyphs.locate,
          tooltip: '定位当前节点',
          onPressed: () => _locate(groups, activeName),
        ),
      ],
      actions: [
        _ModeToggle(
          type: settings.type,
          onChanged: (value) =>
              ref.read(proxiesSettingsProvider.notifier).setType(value),
        ),
      ],
      menuItems: [
        CommonPopupMenuItem(
          label: '代理设置',
          glyph: AppGlyphs.sliders,
          onPressed: _openSettings,
        ),
        CommonPopupMenuItem(
          label: '代理提供者',
          glyph: AppGlyphs.cloudSync,
          onPressed: () => context.push(ProxiesPaths.providers),
        ),
      ],
      body: groups.isEmpty
          ? NullStatus(
              label: '没有匹配的节点',
              description: state.query.isEmpty
                  ? '当前配置还没有代理组'
                  : '换个关键词，或清空搜索',
              illustration: NullStatusIllustration.proxies,
            )
          : settings.type == ProxiesType.tab
          ? _TabBody(
              groups: groups,
              activeName: activeName,
              settings: settings,
              state: state,
              notifier: notifier,
              onActiveChanged: (name) => setState(() => _activeGroup = name),
              onNodeMenu: _showNodeMenu,
            )
          : _ListBody(
              groups: groups,
              settings: settings,
              state: state,
              notifier: notifier,
              onNodeMenu: _showNodeMenu,
            ),
    );
  }

  String? _resolvedActiveGroup(List<ProxyGroupView> groups) {
    if (groups.isEmpty) {
      return null;
    }
    final wanted = _activeGroup;
    if (wanted != null && groups.any((group) => group.name == wanted)) {
      return wanted;
    }
    return groups.first.name;
  }

  /// 滚到当前选中节点所在的组，并提示它的名字。
  void _locate(List<ProxyGroupView> groups, String? activeName) {
    if (groups.isEmpty) {
      return;
    }
    final group = groups.firstWhere(
      (item) => item.selectedName != null,
      orElse: () => groups.first,
    );
    setState(() => _activeGroup = group.name);
    _hint(
      group.selectedName == null
          ? '「${group.name}」还没有选中节点'
          : '当前节点：${group.selectedName}',
    );
  }
}

/// 顶部形态切换（标签页 / 列表）。
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.type, required this.onChanged});

  final ProxiesType type;
  final ValueChanged<ProxiesType> onChanged;

  @override
  Widget build(BuildContext context) {
    // 这两个词很短，用两个小胶囊而不是 `SegmentedControl`：顶栏高度只有 44，
    // 分段控件的最小高度会把它撑开。
    return Row(
      spacing: 2,
      children: [
        for (final value in ProxiesType.values)
          GestureDetector(
            onTap: () => onChanged(value),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: ShapeDecoration(
                shape: AppShape.full,
                color: value == type
                    ? context.colorScheme.primaryContainer
                    : Colors.transparent,
              ),
              child: Text(
                value.label,
                style: AppTextStyle.caption2
                    .of(context, emphasized: value == type)
                    .copyWith(
                      color: value == type
                          ? context.colorScheme.onPrimaryContainer
                          : context.colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 标签页形式：chip 条 + 单组内容。
class _TabBody extends StatelessWidget {
  const _TabBody({
    required this.groups,
    required this.activeName,
    required this.settings,
    required this.state,
    required this.notifier,
    required this.onActiveChanged,
    required this.onNodeMenu,
  });

  final List<ProxyGroupView> groups;
  final String? activeName;
  final ProxiesSettings settings;
  final ProxiesState state;
  final ProxiesNotifier notifier;
  final ValueChanged<String> onActiveChanged;
  final Future<void> Function(ProxyGroupView group, ProxyNodeView node)
  onNodeMenu;

  @override
  Widget build(BuildContext context) {
    final group = groups.firstWhere(
      (item) => item.name == activeName,
      orElse: () => groups.first,
    );
    return PageBody(
      children: [
        _GroupTabs(
          groups: groups,
          activeName: group.name,
          layout: settings.layout,
          onSelected: onActiveChanged,
        ),
        ProxyGroupSection(
          group: group,
          settings: settings,
          headerStyle: ProxyGroupHeaderStyle.tab,
          isTesting: notifier.isTesting(group.name),
          onSelect: (name) => _select(group, name),
          onTest: () => notifier.testGroup(group.name),
          onNodeMenu: (node) => onNodeMenu(group, node),
          onToggleFold: () {},
        ),
      ],
    );
  }

  void _select(ProxyGroupView group, String name) {
    if (!notifier.select(group.name, name)) {
      // 负载均衡 / 链式代理组没有「手动选中」语义，点了要有反馈，
      // 否则用户会以为点击失效。
      onNodeMenu(group, ProxyNodeView(name: name, protocol: ProxyProtocol.ss,
          delayMs: null));
      return;
    }
    onActiveChanged(group.name);
  }
}

/// 分组 chip 条。
class _GroupTabs extends StatelessWidget {
  const _GroupTabs({
    required this.groups,
    required this.activeName,
    required this.layout,
    required this.onSelected,
  });

  final List<ProxyGroupView> groups;
  final String activeName;
  final ProxiesLayout layout;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final padding = switch (layout) {
      ProxiesLayout.tight => 10.0,
      ProxiesLayout.standard => 14.0,
      ProxiesLayout.loose => 18.0,
    };
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: padding),
        itemCount: groups.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final group = groups[index];
          final colorScheme = context.colorScheme;
          return Center(
            child: TonalChip(
              label: group.name,
              color: group.name == activeName
                  ? colorScheme.primaryContainer
                  : SurfaceLevel.block.colorOf(colorScheme),
              foregroundColor: group.name == activeName
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              onPressed: () => onSelected(group.name),
            ),
          );
        },
      ),
    );
  }
}

/// 列表形式：所有组纵向堆叠、可折叠。
class _ListBody extends StatelessWidget {
  const _ListBody({
    required this.groups,
    required this.settings,
    required this.state,
    required this.notifier,
    required this.onNodeMenu,
  });

  final List<ProxyGroupView> groups;
  final ProxiesSettings settings;
  final ProxiesState state;
  final ProxiesNotifier notifier;
  final Future<void> Function(ProxyGroupView group, ProxyNodeView node)
  onNodeMenu;

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        for (final group in groups)
          ProxyGroupSection(
            group: group,
            settings: settings,
            headerStyle: ProxyGroupHeaderStyle.list,
            isTesting: notifier.isTesting(group.name),
            unfolded: notifier.isUnfolded(group.name),
            onSelect: (name) => notifier.select(group.name, name),
            onTest: () => notifier.testGroup(group.name),
            onNodeMenu: (node) => onNodeMenu(group, node),
            onToggleFold: () => notifier.toggleUnfolded(group.name),
          ),
      ],
    );
  }
}

/// 节点长按菜单。
class _NodeMenuSheet extends StatelessWidget {
  const _NodeMenuSheet({required this.groupName, required this.node});

  final String groupName;
  final ProxyNodeView node;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: CommonCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.subheadline.of(
                        context,
                        emphasized: true,
                      ),
                    ),
                    Text(
                      '$groupName · ${node.protocol.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.caption2.of(context).copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const GlyphIcon(AppGlyphs.speed),
                title: const Text('测速这个组'),
                onTap: () => Navigator.of(context).pop('test'),
              ),
              ListTile(
                leading: const GlyphIcon(AppGlyphs.copy),
                title: const Text('复制节点名'),
                onTap: () => Navigator.of(context).pop('copy'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

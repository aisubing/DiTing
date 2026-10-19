import 'package:diting/data/mock_profiles.dart';
import 'package:diting/pages/profiles/extend_global_rules.dart';
import 'package:diting/pages/profiles/rule_form_sheet.dart';
import 'package:diting/state/profiles_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'extend_standard.dart';
part 'extend_script.dart';

/// 扩展页（上游 `views/profiles/extend/extend.dart`，158 行）。
///
/// 上游是一个「模式选择卡 + 内容区」：标准模式用表单维护追加规则与匹配目标，
/// 脚本模式选一段 JS 覆盖配置。两种模式互斥，切模式不会丢对方的数据（脚本
/// 选择与追加规则各自独立保存）。
///
/// 模式按档案 id 记在 `extendModesProvider` 里，因为同一份配置在不同档案下
/// 可以有不同的扩展方式。
class ExtendPage extends ConsumerWidget {
  const ExtendPage({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      extendModesProvider.select((modes) => modes[profileId]),
    );
    final current = mode ?? ExtendMode.standard;
    return CommonScaffold(
      title: '扩展',
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              spacing: 12,
              children: [
                for (final option in ExtendMode.values)
                  Expanded(
                    child: CommonCard(
                      isSelected: current == option,
                      fillsSelection: true,
                      onPressed: () => ref
                          .read(extendModesProvider.notifier)
                          .select(profileId, option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: Column(
                          spacing: 6,
                          children: [
                            GlyphIcon(switch (option) {
                              ExtendMode.standard => AppGlyphs.star,
                              ExtendMode.script => AppGlyphs.code,
                            }, size: 22),
                            Text(
                              option.label,
                              style: context.listTitleStyle.copyWith(
                                color: current == option
                                    ? context.colorScheme.onPrimary
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(current.description, style: context.listCaptionStyle),
          ),
          const SizedBox(height: 20),
          switch (current) {
            ExtendMode.standard => _StandardContent(profileId: profileId),
            ExtendMode.script => _ScriptContent(profileId: profileId),
          },
        ],
      ),
    );
  }
}

/// 标准模式的匹配目标项：一行「匹配目标 + 当前值」。
///
/// 上游 `_MatchTargetItem`：值是组名或内置策略；空表示「跟随档案默认」。
/// 值失效（组被删了）时把文字画成错误色——上游同样做这个判断，因为内核会
/// 静默忽略一个不存在的目标，用户不会收到任何报错。
class _MatchTargetItem extends ConsumerWidget {
  const _MatchTargetItem({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(
      matchTargetsProvider.select((targets) => targets[profileId]),
    );
    final groups = ref.watch(proxyGroupsProvider);
    final proxies = ref.watch(customProxiesProvider);
    final valid =
        target == null ||
        MockRuleTarget.values.any((item) => item.value == target) ||
        groups.any((group) => group.name == target) ||
        proxies.any((proxy) => proxy.name == target);
    final colorScheme = context.colorScheme;
    return MoreActionButton(
      label: '匹配目标',
      trailing: Text(
        target ?? '跟随档案默认',
        style: AppTextStyle.subheadline
            .of(context)
            .copyWith(
              fontFamily: 'JetBrainsMono',
              color: valid ? colorScheme.tertiary : colorScheme.error,
            ),
      ),
      onPressed: () => _select(context, ref, target),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final groups = ref.read(proxyGroupsProvider);
    final proxies = ref.read(customProxiesProvider);
    final result = await showSheet<String>(
      context: context,
      builder: (_) =>
          _MatchTargetSheet(current: current, groups: groups, proxies: proxies),
    );
    if (result == null) {
      return;
    }
    ref
        .read(matchTargetsProvider.notifier)
        .select(profileId, result.isEmpty ? null : result);
  }
}

/// 匹配目标选择面板（上游 `SelectionSheet<String>`）。
///
/// 四段：跟随默认、内置策略、代理组、节点。分组而不是一个长列表：这三类在
/// 内核里的含义不同（策略 / 组 / 具体节点），混在一起选错的机会更大。
class _MatchTargetSheet extends StatelessWidget {
  const _MatchTargetSheet({
    required this.current,
    required this.groups,
    required this.proxies,
  });

  final String? current;
  final List<MockProxyGroup> groups;
  final List<MockProxy> proxies;

  @override
  Widget build(BuildContext context) {
    final selected = current ?? '';
    return CommonScaffold(
      title: '匹配目标',
      body: ListView(
        controller: sheetScrollController(context),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Text('所有没被前面规则命中的流量，最终交给这里选的目标。', style: context.listCaptionStyle),
          const SizedBox(height: 12),
          generateSection(
            title: '默认',
            items: [
              _TargetRow(
                label: '跟随档案默认',
                subtitle: '使用这份档案自己的 MATCH 目标',
                isSelected: selected.isEmpty,
                onTap: () => Navigator.of(context).pop(''),
              ),
            ],
          ),
          generateSection(
            title: '内置策略',
            items: [
              for (final target in MockRuleTarget.values)
                _TargetRow(
                  label: target.value,
                  subtitle: target.description,
                  isSelected: selected == target.value,
                  onTap: () => Navigator.of(context).pop(target.value),
                ),
            ],
          ),
          if (groups.isNotEmpty)
            generateSection(
              title: '代理组',
              items: [
                for (final group in groups)
                  _TargetRow(
                    label: group.name,
                    subtitle: group.kind.label,
                    isSelected: selected == group.name,
                    onTap: () => Navigator.of(context).pop(group.name),
                  ),
              ],
            ),
          if (proxies.isNotEmpty)
            generateSection(
              title: '节点',
              items: [
                for (final proxy in proxies)
                  _TargetRow(
                    label: proxy.name,
                    subtitle: proxy.endpoint,
                    isSelected: selected == proxy.name,
                    onTap: () => Navigator.of(context).pop(proxy.name),
                  ),
              ],
            ),
          SizedBox(height: NavigationDock.insetOf(context)),
        ],
      ),
    );
  }
}

/// 选择面板里的一行：选中时右侧出现勾选标记。
class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      isSelected: isSelected,
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyle.subheadline
            .of(context)
            .copyWith(fontFamily: 'JetBrainsMono'),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.listCaptionStyle,
      ),
      trailing: isSelected ? const SelectionCheck() : null,
      onPressed: onTap,
    );
  }
}

/// 打开「控制全局追加规则」页（上游 `_EditGlobalAddedRules`）。
///
/// 用 `showExtend` 而不是 push 路由：它只是从扩展页分出去的一层，关掉要回到
/// 扩展页的同一个位置，走独立路由会把档案层级搞乱。
Future<void> showGlobalRulesPage(
  BuildContext context, {
  required String profileId,
}) {
  return showExtend<void>(
    context,
    builder: (_) => GlobalRulesPage(profileId: profileId),
  );
}

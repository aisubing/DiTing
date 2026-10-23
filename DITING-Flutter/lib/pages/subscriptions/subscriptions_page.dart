import 'package:diting/data/db/subscription_models.dart';
import 'package:diting/data/subscriptions/subscription_url.dart';
import 'package:diting/state/subscription_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/chip_row.dart';
import 'package:diting/widgets/empty_state.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'subscriptions_cards.dart';
part 'subscriptions_sheet.dart';

/// Subscriptions page: group filter, summary and card list. Groups sit at the top because
/// users usually watch one group; data comes from the legacy `subscription_group` table
/// ordered by `addedAt`.
class SubscriptionsPage extends ConsumerWidget {
  const SubscriptionsPage({super.key});

  Future<void> _updateAll(BuildContext context, WidgetRef ref) async {
    final entries = ref.read(subscriptionEntriesProvider).value ?? const [];
    final targets = [
      for (final entry in entries)
        if (entry.enabled && entry.isRemote) entry,
    ];
    if (targets.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('没有可更新的远程订阅'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1600),
        ),
      );
      return;
    }
    await ref.read(subscriptionUpdateProvider.notifier).updateAll(targets);
    if (!context.mounted) {
      return;
    }
    final message = ref.read(subscriptionUpdateProvider).lastMessage;
    if (message != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 2400),
        ),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SubscriptionEntry entry,
  ) async {
    final localizations = UiLocalizations.of(context);
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除订阅',
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
        child: Text(
          '删除「${entry.name}」后不可撤销。\n\n'
          '删除会同时移除这条订阅贡献的全部规则（来源标签 sub_<id>）。',
        ),
      ),
    );
    if (confirmed ?? false) {
      await ref.read(subscriptionActionsProvider).remove(entry.id);
    }
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    SubscriptionEntry entry,
  ) async {
    final name = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: '重命名订阅',
        value: entry.name,
        validator: (value) => (value ?? '').trim().isEmpty ? '名称不能为空' : null,
      ),
    );
    if (name != null) {
      await ref.read(subscriptionActionsProvider).rename(entry.id, name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final asyncEntries = ref.watch(subscriptionEntriesProvider);
    final entries = asyncEntries.value ?? const <SubscriptionEntry>[];
    final groups = ref.watch(subscriptionGroupsProvider).value ?? const [];
    final groupId = ref.watch(subscriptionGroupFilterProvider);
    final selectedEntries = ref.watch(filteredSubscriptionsProvider);
    final update = ref.watch(subscriptionUpdateProvider);

    final enabledCount = entries.where((entry) => entry.enabled).length;
    final lineCount = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.ruleCount,
    );
    final failedCount = entries.where((entry) => entry.isFailed).length;

    return CommonScaffold(
      title: '订阅',
      isLoading: update.updatingAll,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.refresh,
          tooltip: '更新全部订阅',
          isLoading: update.updatingAll,
          onPressed: update.updatingAll ? null : () => _updateAll(context, ref),
        ),
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加订阅',
          onPressed: () => showSheet<void>(
            context: context,
            builder: (_) => const _AddSubscriptionSheet(),
          ),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              child: StatStrip(
                stats: [
                  StatItem(label: '订阅数', value: '${entries.length}'),
                  StatItem(
                    label: '已启用',
                    value: '$enabledCount',
                    color: colorScheme.success,
                  ),
                  StatItem(label: '已入库规则', value: _formatCount(lineCount)),
                  if (failedCount > 0)
                    StatItem(
                      label: '异常',
                      value: '$failedCount',
                      color: colorScheme.destructive,
                    ),
                ],
              ),
            ),
          ),
          if (asyncEntries.isLoading)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (update.updatingAll)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  Row(
                    children: [
                      Text('正在更新订阅…', style: context.listCaptionStyle),
                      const Spacer(),
                      Text(
                        '${(update.progress * 100).round()}%',
                        style: context.listCaptionStyle,
                      ),
                    ],
                  ),
                  LinearProgressIndicator(
                    value: update.progress,
                    minHeight: 4,
                    borderRadius: AppRadius.full,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _GroupChips(
              groups: groups,
              value: groupId,
              totalCount: entries.length,
              onSelect: (id) =>
                  ref.read(subscriptionGroupFilterProvider.notifier).select(id),
              onManage: () => _manageGroups(context, ref),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              groupId == null
                  ? '共 ${entries.length} 个订阅'
                  : '「${_groupNameOf(groups, groupId)}」下 ${selectedEntries.length} 个订阅',
              style: context.listCaptionStyle,
            ),
          ),
          if (entries.isEmpty && !asyncEntries.isLoading)
            // Minimum height only, never a fixed 300: the description wraps to two lines
            // and the button sits below, so a fixed height clips them.
            EmptyStateBox(
              minHeight: 300,
              child: NullStatus(
                label: '还没有订阅',
                description:
                    '订阅可以批量维护规则；更新会下载正文、解析并写入规则库，'
                    '拦截随之生效。',
                illustration: NullStatusIllustration.rules,
                action: FilledButton(
                  onPressed: () => showSheet<void>(
                    context: context,
                    builder: (_) => const _AddSubscriptionSheet(),
                  ),
                  child: const Text('添加订阅'),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                for (final entry in selectedEntries)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SubscriptionCard(
                      entry: entry,
                      isUpdating: update.updatingIds.contains(entry.id),
                      busy: update.isBusy,
                      onToggle: (value) => ref
                          .read(subscriptionActionsProvider)
                          .setEnabled(entry.id, value),
                      onUpdate: () => ref
                          .read(subscriptionUpdateProvider.notifier)
                          .updateOne(entry.id),
                      onDelete: () => _delete(context, ref, entry),
                      onEdit: () => _rename(context, ref, entry),
                    ),
                  ),
              ],
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 8, 0, 0),
            child: ListFooter(
              text:
                  '更新会下载正文、解析成黑/白名单与覆写规则并写入规则库，'
                  '同时替换该订阅上一次贡献的规则；元素隐藏规则本仓不注入，不计入条数。',
            ),
          ),
        // `PageBody` already adds a `DockSpacer`, so no extra bottom padding here: doubling
        // it leaves roughly twice the dock height of empty space.
        ],
      ),
    );
  }

  Future<void> _manageGroups(BuildContext context, WidgetRef ref) async {
    final name = await showFloatingDialog<String>(
      context: context,
      child: InputDialog(
        title: '新建分组',
        value: '',
        validator: (value) => (value ?? '').trim().isEmpty ? '分组名称不能为空' : null,
      ),
    );
    if (name == null) {
      return;
    }
    await ref.read(subscriptionActionsProvider).createGroup(name);
  }

  static String _groupNameOf(List<SubscriptionGroupRecord> groups, int id) {
    for (final group in groups) {
      if (group.id == id) {
        return group.name;
      }
    }
    return SubscriptionEntry.ungroupedLabel;
  }
}

class _GroupChips extends StatelessWidget {
  const _GroupChips({
    required this.groups,
    required this.value,
    required this.totalCount,
    required this.onSelect,
    required this.onManage,
  });

  final List<SubscriptionGroupRecord> groups;

  final int? value;
  final int totalCount;
  final ValueChanged<int?> onSelect;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final options = <(int?, String)>[
      (null, '全部'),
      for (final group in groups) (group.id, group.name),
    ];
    return ChipRow(
      children: [
        for (final (groupId, label) in options)
          FilterPill(
            label: label,
            selected: groupId == value,
            onPressed: () => onSelect(groupId),
          ),
        // The create chip is a management entry, not a filter, so it is never selected.
        TonalChip(
          label: '+ 分组',
          color: context.raisedSurfaceLevel.colorOf(colorScheme),
          foregroundColor: colorScheme.onSurfaceVariant,
          onPressed: onManage,
        ),
      ],
    );
  }
}

/// Thousands separators: the rule count is the only large number here and `48,213` reads
/// faster than `48213`.
String _formatCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
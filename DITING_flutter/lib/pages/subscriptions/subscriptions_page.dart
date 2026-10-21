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

/// 订阅页：分组筛选 → 汇总 → 订阅卡片列表。
///
/// 分组放在页面顶部而不是每张卡片的标签里：订阅按用途分组后，用户平时只想看
/// 某一组，顶部一行 chip 比逐张卡片阅读快得多。分组数据来自 1.4.3 的
/// `subscription_group` 表（`addedAt ASC, name COLLATE NOCASE ASC`）。
///
/// ## 本轮边界（必须让用户看见）
/// 更新是真实 HTTP 下载，但订阅正文**没有**写进 `block_rule` / `allow_rule`：
/// 规则解析链（`AdGuardRuleParser` 等）本轮未移植。因此卡片上显示的是「已下载
/// N 行」而不是「N 条规则生效」，页面底部固定一条说明。不要把这条文案删掉换成
/// 「规则已更新」，那是谎报。
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
          '本轮订阅正文尚未写入规则表，因此删除只影响这一条订阅记录本身。',
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
                  StatItem(label: '已下载行数', value: _formatCount(lineCount)),
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
            // 只给下限，不写死 300：说明有两行、按钮又排在下面，固定高度会把
            // 它裁掉（真机上「添加订阅」只剩一条蓝边，页脚压在原位置）。
            EmptyStateBox(
              minHeight: 300,
              child: NullStatus(
                label: '还没有订阅',
                description:
                    '订阅可以批量维护规则；本轮只下载正文并统计行数，'
                    '规则解析与入库将在后续版本接入',
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
                  '本轮订阅更新只做真实下载与行数统计：正文不会写入拦截/放行规则表，'
                  '因此更新后拦截行为不会改变。规则解析与入库将在后续版本接入。',
            ),
          ),
          SizedBox(height: NavigationDock.insetOf(context)),
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

/// 分组 chip 行：全部 + 每个分组 + 新建。
class _GroupChips extends StatelessWidget {
  const _GroupChips({
    required this.groups,
    required this.value,
    required this.totalCount,
    required this.onSelect,
    required this.onManage,
  });

  final List<SubscriptionGroupRecord> groups;

  /// `null` 表示「全部」。
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
        // 「+ 分组」不是筛选档，是管理入口，因此不参与选中态。
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

/// 千分位。行数是这里唯一的大数字，`48213` 读起来比 `48,213` 慢得多。
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

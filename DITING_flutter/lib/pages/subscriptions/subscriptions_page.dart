import 'package:diting/data/mock_data.dart';
import 'package:diting/state/subscription_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

part 'subscriptions_cards.dart';
part 'subscriptions_sheet.dart';

/// 订阅页：分组筛选 → 汇总 → 订阅卡片列表。
///
/// 分组放在页面顶部而不是每张卡片的标签里：订阅按用途分组（广告拦截 / 内网
/// 加速 / 实验）后，用户平时只想看某一组，顶部一行 chip 比逐张卡片阅读快得多。
class SubscriptionsPage extends ConsumerWidget {
  const SubscriptionsPage({super.key});

  Future<void> _updateAll(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(subscriptionsProvider.notifier);
    final enabled = ref
        .read(subscriptionsProvider)
        .entries
        .where(
          (entry) =>
              entry.enabled &&
              entry.importType == SubscriptionImportType.remote,
        )
        .length;
    if (enabled == 0) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('没有可更新的远程订阅'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1600),
        ),
      );
      return;
    }
    await notifier.updateAll();
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
          '删除「${entry.name}」后，来自它的 ${_formatCount(entry.ruleCount)} '
          '条规则会一起移除。此操作不可撤销。',
        ),
      ),
    );
    if (confirmed ?? false) {
      ref.read(subscriptionsProvider.notifier).remove(entry.id);
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
        validator: (value) =>
            (value ?? '').trim().isEmpty ? '名称不能为空' : null,
      ),
    );
    if (name != null) {
      ref.read(subscriptionsProvider.notifier).rename(entry.id, name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionsProvider);
    final entries = ref.watch(filteredSubscriptionsProvider);
    final groups = ref.watch(subscriptionGroupsProvider);
    final group = ref.watch(subscriptionGroupFilterProvider);
    final colorScheme = context.colorScheme;
    final enabledCount = state.entries.where((entry) => entry.enabled).length;
    final ruleCount = state.entries.fold<int>(
      0,
      (sum, entry) => sum + entry.ruleCount,
    );
    final failedCount = state.entries
        .where((entry) => entry.error != null)
        .length;

    return CommonScaffold(
      title: '订阅',
      isLoading: state.updatingAll,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.refresh,
          tooltip: '更新全部订阅',
          isLoading: state.updatingAll,
          onPressed: state.updatingAll
              ? null
              : () => _updateAll(context, ref),
        ),
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: '添加订阅',
          onPressed: () =>
              showSheet<void>(context: context, builder: (_) => const _AddSubscriptionSheet()),
        ),
      ],
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CommonCard(
              child: StatStrip(
                stats: [
                  StatItem(label: '订阅数', value: '${state.entries.length}'),
                  StatItem(
                    label: '已启用',
                    value: '$enabledCount',
                    color: colorScheme.success,
                  ),
                  StatItem(label: '规则总数', value: _formatCount(ruleCount)),
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
          if (state.updatingAll)
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
                        '${(state.progress * 100).round()}%',
                        style: context.listCaptionStyle,
                      ),
                    ],
                  ),
                  LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 4,
                    borderRadius: AppRadius.full,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _GroupChips(groups: groups, value: group),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              group == null
                  ? '共 ${entries.length} 个订阅'
                  : '「$group」下 ${entries.length} 个订阅',
              style: context.listCaptionStyle,
            ),
          ),
          if (entries.isEmpty)
            SizedBox(
              height: 320,
              child: NullStatus(
                label: group == null ? '还没有订阅' : '该分组下没有订阅',
                description: group == null
                    ? '订阅可以批量维护规则，更新一次全表生效'
                    : '切换到其他分组，或往这个分组里添加订阅',
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
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SubscriptionCard(
                      entry: entry,
                      isUpdating: state.updatingIds.contains(entry.id),
                      busy: state.updatingAll || state.updatingIds.isNotEmpty,
                      onToggle: (value) => ref
                          .read(subscriptionsProvider.notifier)
                          .toggleEnabled(entry.id),
                      onUpdate: () => ref
                          .read(subscriptionsProvider.notifier)
                          .updateOne(entry.id),
                      onDelete: () => _delete(context, ref, entry),
                      onEdit: () => _rename(context, ref, entry),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 分组 chip 行：全部 + 每个分组。
class _GroupChips extends ConsumerWidget {
  const _GroupChips({required this.groups, required this.value});

  final List<String> groups;

  /// `null` 表示「全部」。
  final String? value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final options = <(String?, String)>[
      (null, '全部'),
      for (final group in groups) (group, group),
    ];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (group, label) = options[index];
          final selected = group == value;
          return TonalChip(
            label: label,
            color: selected
                ? colorScheme.primary
                : context.raisedSurfaceLevel.colorOf(colorScheme),
            foregroundColor: selected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
            onPressed: () =>
                ref.read(subscriptionGroupFilterProvider.notifier).select(group),
          );
        },
      ),
    );
  }
}

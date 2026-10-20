part of 'override_spec_page.dart';

/// 添加条目的选择浮层。
///
/// 分组 + 副标题（每个键的一句说明）：覆写的键名本身不直观（`force-dns-mapping`
/// 到底干什么），只列键名等于让用户猜。
Future<void> showOverrideAddSheet(
  BuildContext context,
  MockOverrideSpec spec,
) => showSheet<void>(
  context: context,
  builder: (_) => _OverrideAddSheet(spec: spec),
);

class _OverrideAddSheet extends ConsumerWidget {
  const _OverrideAddSheet({required this.spec});

  final MockOverrideSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked =
        ref.watch(overrideProvider.select((all) => all[spec.id]))?.picked ??
        const <String>[];
    final remaining = [
      for (final entry in spec.allKeys)
        if (!picked.contains(entry.key)) entry,
    ];
    final grouped = groupOverrideEntries(remaining);
    return CommonScaffold(
      title: '添加条目',
      body: NullStatusSwitcher(
        isEmpty: remaining.isEmpty,
        nullStatus: const NullStatus(
          label: '所有键都已添加',
          description: '把不需要的条目移除后可以重新加回来',
          illustration: NullStatusIllustration.data,
        ),
        child: ListView(
          controller: sheetScrollController(context),
          padding: EdgeInsets.only(top: 8 + context.contentTopPadding),
          children: [
            for (final section in grouped.entries)
              generateSection(
                title: section.key,
                items: [
                  for (final entry in section.value)
                    ListItem(
                      title: Text(entry.label),
                      subtitle: Text(
                        entry.description ?? _kindSummary(entry.kind),
                      ),
                      trailing: const GlyphIcon(AppGlyphs.addCircle, size: 20),
                      onTap: () {
                        ref
                            .read(overrideProvider.notifier)
                            .add(spec.id, entry.key);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            SizedBox(height: NavigationDock.insetOf(context)),
          ],
        ),
      ),
    );
  }
}

String _kindSummary(OverrideFieldKind kind) => switch (kind) {
  OverrideFieldKind.toggle => '布尔开关',
  OverrideFieldKind.options => '从固定选项中选择',
  OverrideFieldKind.number => '数字输入',
  OverrideFieldKind.text => '文本输入',
  OverrideFieldKind.list => '字符串列表，可增删',
};

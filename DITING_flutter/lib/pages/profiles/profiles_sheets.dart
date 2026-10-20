part of 'profiles_page.dart';

/// 排序与重排面板（上游 `ReorderableProfilesSheet`）。
///
/// 用 `showSheet` + `ReorderableListView` 而不是直接把网格做成可拖拽：网格里
/// 每张卡还带菜单、点击切换、长按多选三种手势，再叠一个拖拽会互相抢；面板里
/// 只剩「一行一个名字 + 拖拽把手」，手势就没有歧义了。
class _ReorderProfilesSheet extends ConsumerStatefulWidget {
  const _ReorderProfilesSheet({required this.onSave});

  final VoidCallback onSave;

  @override
  ConsumerState<_ReorderProfilesSheet> createState() =>
      _ReorderProfilesSheetState();
}

class _ReorderProfilesSheetState extends ConsumerState<_ReorderProfilesSheet> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profilesProvider);
    final notifier = ref.read(profilesProvider.notifier);
    return CommonScaffold(
      title: '排序与重排',
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: '完成',
        onPressed: widget.onSave,
      ),
      // body 是顶对齐的 `Column`（说明 + 筛选 chip 在最上方），浮层标题压在
      // 正文之上，所以整列都要让开浮位；里层列表的 padding 里再补一次就会
      // 双重留白，故那里保持原始的 `top: 8`。
      body: AppBarClearance(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                '拖动右侧把手调整顺序；网格按此顺序排列',
                style: context.listCaptionStyle,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sort in ProfileSort.values)
                    TonalChip(
                      label: sort.label,
                      color: context.raisedSurfaceLevel.colorOf(
                        context.colorScheme,
                      ),
                      foregroundColor: context.colorScheme.onSurfaceVariant,
                      onPressed: () => notifier.sortBy(sort),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: NavigationDock.insetOf(context) + 16,
                ),
                onReorderItem: notifier.reorder,
                itemCount: state.profiles.length,
                itemBuilder: (context, index) {
                  final profile = state.profiles[index];
                  return Padding(
                    key: ValueKey(profile.id),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ItemPositionProvider(
                      position: ItemPosition.get(index, state.profiles.length),
                      child: DecorationListItem(
                        contentPadding: const EdgeInsets.only(left: 16),
                        title: Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${profile.kind.label} · ${profile.updatedAt}',
                          style: context.listCaptionStyle,
                        ),
                        trailing: SortHandle(index: index),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

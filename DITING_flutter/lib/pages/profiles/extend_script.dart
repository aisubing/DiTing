part of 'extend_page.dart';

/// 脚本模式内容（上游 `extend/script.dart`，89 行）。
///
/// 一份脚本列表 + 「再次点击取消选中」的互斥选择。脚本本身在脚本库里编辑，
/// 这里只挑一份挂到当前档案上；没选就是不加任何覆盖。
class _ScriptContent extends ConsumerWidget {
  const _ScriptContent({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      scriptSelectionProvider.select((scripts) => scripts[profileId]),
    );
    final colorScheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoHeader(info: const Info(label: '覆盖脚本')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '脚本在配置加载后运行，可以改写节点名、替换地址或删掉不想要的条目。'
            '同一份档案只挂一段脚本。',
            style: context.listCaptionStyle,
          ),
        ),
        const SizedBox(height: 12),
        generateSection(
          items: [
            for (final script in mockScripts)
              DecorationListItem(
                isSelected: selected == script.id,
                leading: GlyphIcon(
                  script.enabled ? AppGlyphs.code : AppGlyphs.block,
                  color: script.enabled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                title: Text(script.name),
                subtitle: Text(
                  '${script.lineCount} 行 · ${script.updatedAt}'
                  '${script.enabled ? '' : ' · 已停用'}',
                  style: context.listCaptionStyle,
                ),
                trailing: selected == script.id ? const SelectionCheck() : null,
                onPressed: script.enabled
                    ? () => ref
                          .read(scriptSelectionProvider.notifier)
                          .select(profileId, script.id)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 16),
        MoreActionButton(
          label: '管理脚本库',
          onPressed: () => showScriptLibrarySheet(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            '再点一次已选中的脚本可以取消挂载，回到「不覆盖」。',
            style: context.listCaptionStyle.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// 脚本库面板：只读展示每段脚本的摘要。
///
/// 上游这里是一个完整的脚本编辑器（`ScriptsView` + 代码编辑器 + 增删改）。
/// 演示版没有 JS 运行时，编辑了也无法验证，所以收成「摘要 + 停用标记」，
/// 把「入口存在」这件事保留下来。
Future<void> showScriptLibrarySheet(BuildContext context) {
  return showFormSheet<void>(
    context: context,
    builder: (_) => const _ScriptLibrarySheet(),
  );
}

class _ScriptLibrarySheet extends StatelessWidget {
  const _ScriptLibrarySheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return CommonScaffold(
      title: '脚本库',
      body: ListView(
        controller: sheetScrollController(context),
        padding: EdgeInsets.fromLTRB(
          16,
          12 + context.contentTopPadding,
          16,
          16,
        ),
        children: [
          Text(
            '脚本用 JavaScript 编写，在配置加载后执行。演示版不运行脚本，'
            '只展示它们的存在与状态。',
            style: context.listCaptionStyle,
          ),
          const SizedBox(height: 12),
          generateSection(
            title: '全部脚本',
            items: [
              for (final script in mockScripts)
                ListItem(
                  leading: GlyphIcon(
                    AppGlyphs.code,
                    color: script.enabled
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(script.name),
                  subtitle: Text(
                    '${script.lineCount} 行 · ${script.updatedAt}',
                    style: context.listCaptionStyle,
                  ),
                  trailing: MetaChip(label: script.enabled ? '启用' : '停用'),
                ),
            ],
            footer: '真实实现里这里能新建、编辑与调试脚本。',
          ),
          SizedBox(height: NavigationDock.insetOf(context)),
        ],
      ),
    );
  }
}

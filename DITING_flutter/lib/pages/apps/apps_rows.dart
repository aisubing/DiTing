part of 'apps_page.dart';

/// 一行应用：名称 + 包名 + 勾选框。
///
/// 整行可点而不是只有勾选框可点：手机上一行 56dp，让用户精确点中右侧那个
/// 24dp 的框是没必要的刁难。
class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.selected,
    required this.onToggle,
  });

  final MockInstalledApp app;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ListItem(
      leading: GlyphIcon(
        selected ? AppGlyphs.checkCircle : AppGlyphs.appsList,
        size: 20,
        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        app.packageName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyle.footnote
            .of(context)
            .copyWith(fontFamily: 'JetBrainsMono'),
      ),
      trailing: CommonCheckBox(
        value: selected,
        isCircle: true,
        onChanged: (_) => onToggle(),
      ),
      onTap: onToggle,
    );
  }
}

/// 已选应用摘要：横向 chip 行 + 一键清除。
///
/// 为什么不只在统计带里显示数字：用户需要确认「我到底选了哪几个」，尤其在做
/// 反向操作（先全选再取消几个）时，数字无法承担这个核对。
class _SelectedSummary extends StatelessWidget {
  const _SelectedSummary({required this.selected, required this.onClear});

  final Set<String> selected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final names = [
      for (final app in mockInstalledApps)
        if (selected.contains(app.packageName)) app.name,
    ];
    return CommonCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '已选 ${selected.length} 个应用',
                  style: context.listTitleStyle,
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: Text(
                  '清除',
                  style: AppTextStyle.subheadline
                      .of(context)
                      .copyWith(color: colorScheme.error),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final name in names) CommonChip(label: name),
            ],
          ),
        ],
      ),
    );
  }
}

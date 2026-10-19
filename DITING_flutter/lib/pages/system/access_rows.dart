part of 'access_page.dart';

/// 一行应用（上游 `PackageListItem`，第 533 行起）。
///
/// 整行可点而不是只有勾选框可点：手机上一行 56dp，让用户精确点中右侧那个
/// 24dp 的框是没必要的刁难。
class _PackageListItem extends StatelessWidget {
  const _PackageListItem({
    required this.package,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final MockPackage package;
  final bool selected;

  /// 总开关关闭时整行不可操作——与面板的 `DisabledMask` 同步。
  final bool enabled;

  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ListItem(
      leading: _packageLeading(package, selected: selected),
      title: Text(
        package.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        spacing: 6,
        children: [
          Flexible(
            child: Text(
              package.packageName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.listCaptionStyle.copyWith(
                fontFamily: 'JetBrainsMono',
              ),
            ),
          ),
          if (package.isSystem)
            Text(
              '系统',
              style: context.listCaptionStyle.copyWith(
                color: colorScheme.warning,
              ),
            ),
          if (!package.hasNetwork)
            Text(
              '无网络',
              style: context.listCaptionStyle.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: CommonCheckBox(
        value: selected,
        isCircle: true,
        onChanged: enabled ? (_) => onToggle() : null,
      ),
      onTap: enabled ? onToggle : null,
    );
  }
}

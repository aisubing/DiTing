import 'package:diting/state/installed_apps_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// Scroll body for the app pickers: same app-bar inset and dock clearance as [PageBody], but built
/// from slivers so the app section can stay lazy.
class AppListScrollView extends StatelessWidget {
  const AppListScrollView({super.key, required this.slivers});

  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: FloatingBarScope(
        inset: 0,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: context.appBarInset)),
            ...slivers,
            const SliverToBoxAdapter(child: DockSpacer()),
          ],
        ),
      ),
    );
  }
}

/// Lazily built app rows for a [CustomScrollView]. Building only the rows on screen (instead of a
/// `Column` inside a `ListView`, which constructed every app up front) is what removed the stalls
/// when scrolling a few hundred packages.
List<Widget> appListSlivers({
  String? title,
  List<IconButtonData> actions = const [],
  required int itemCount,
  required NullableIndexedWidgetBuilder itemBuilder,
  String? footer,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16),
}) {
  return [
    if (itemCount > 0 && title != null)
      SliverToBoxAdapter(
        child: ListHeader(title: title, actions: actions),
      ),
    SliverPadding(
      padding: padding,
      sliver: SliverList.builder(
        itemCount: itemCount,
        // No keep-alives: rows are cheap to rebuild and holding hundreds of them alive is what
        // made the list stutter on the way back up.
        addAutomaticKeepAlives: false,
        itemBuilder: (context, index) => ItemPositionProvider(
          position: ItemPosition.get(index, itemCount),
          child: itemBuilder(context, index)!,
        ),
      ),
    ),
    if (itemCount > 0 && footer != null)
      SliverToBoxAdapter(child: ListFooter(text: footer)),
  ];
}

/// The 1.4.3 `AppListOverflowMenu` in Flutter form: select-all / clear / invert, then the filter and
/// sort submenus. Callers pass the actions they support; a null callback drops that entry, which is
/// how the legacy `showSelectionActions` flag behaves.
List<CommonPopupMenuItem> appListMenuItems({
  required AppListFilter filter,
  required AppListSort sort,
  required ValueChanged<AppListFilter> onFilterChanged,
  required ValueChanged<AppListSort> onSortChanged,
  VoidCallback? onSelectAll,
  VoidCallback? onClear,
  VoidCallback? onInvert,
}) {
  return [
    if (onSelectAll != null)
      CommonPopupMenuItem(
        label: '全选',
        glyph: AppGlyphs.checkDouble,
        onPressed: onSelectAll,
      ),
    if (onClear != null)
      CommonPopupMenuItem(
        label: '清除',
        glyph: AppGlyphs.clearAll,
        onPressed: onClear,
      ),
    if (onInvert != null)
      CommonPopupMenuItem(
        label: '反选',
        glyph: AppGlyphs.sync,
        onPressed: onInvert,
      ),
    CommonPopupMenuItem(
      label: '过滤',
      glyph: AppGlyphs.filter,
      subItems: [
        for (final option in AppListFilter.values)
          CommonPopupMenuItem(
            label: option.label,
            checked: option == filter,
            onPressed: () => onFilterChanged(option),
          ),
      ],
    ),
    CommonPopupMenuItem(
      label: '排序',
      glyph: AppGlyphs.sort,
      subItems: [
        for (final option in AppListSort.values)
          CommonPopupMenuItem(
            label: option.label,
            checked: option == sort,
            onPressed: () => onSortChanged(option),
          ),
      ],
    ),
  ];
}

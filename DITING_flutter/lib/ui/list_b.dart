// Portions derived from DITING (https://github.com/chen08209/DITING), Copyright (c) the DITING authors, GPL-3.0-or-later.

part of 'list.dart';

class ListFooter extends StatelessWidget {
  final String text;

  const ListFooter({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding:
          const EdgeInsets.only(left: 16, right: 16, top: 8) * 1.mAp(context),
      child: Text(text, style: context.listCaptionStyle),
    );
  }
}

/// 一组「组头 + 卡片们 + 组脚」。
///
/// [padding] 只加在卡片列上，不加在整列外：`ListHeader`/`ListFooter` 自带 16
/// 的横向内边距，外层再套一次会让组头比别组缩进 32（`SectionBlock` 同口径）。
/// 卡片本身不带横向留白，所以必须由这里给——此前它一处都不给，全站 157 个
/// 分组的卡片于是直接贴住屏幕左右边沿（真机量到 `leftGap=0dp`）。
Widget generateSection({
  String? title,
  required Iterable<Widget> items,
  List<IconButtonData> actions = const [],
  String? footer,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16),
}) {
  final genItems = items.mapIndexed<Widget>(
    (index, item) => ItemPositionProvider(
      position: ItemPosition.get(index, items.length),
      child: item,
    ),
  );
  return Column(
    children: [
      if (items.isNotEmpty && title != null)
        ListHeader(title: title, actions: actions),
      Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [...genItems],
        ),
      ),
      if (items.isNotEmpty && footer != null) ListFooter(text: footer),
    ],
  );
}

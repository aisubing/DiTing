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

/// A group: header, cards, footer. [padding] reaches the cards only; header and footer carry 16 a
/// side already.
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

// Portions derived from FlClash (https://github.com/chen08209/FlClash), Copyright (c) the FlClash authors, GPL-3.0-or-later.

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

Widget generateSection({
  String? title,
  required Iterable<Widget> items,
  List<IconButtonData> actions = const [],
  String? footer,
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
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [...genItems],
      ),
      if (items.isNotEmpty && footer != null) ListFooter(text: footer),
    ],
  );
}

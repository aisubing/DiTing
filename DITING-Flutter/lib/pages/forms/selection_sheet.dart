library;

import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/empty_state.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

class SelectionSection<T> {
  const SelectionSection({
    required this.label,
    required this.items,
    this.subtitleBuilder,
  });

  final String label;
  final List<T> items;

  /// Row subtitle; `null` means this section has none.
  final String Function(T item)? subtitleBuilder;
}

/// Generic selection sheet. Single select uses [selected] + [onSelected], multi select
/// [selectedMany] + [onSelectedMany]; their closing behavior differs too much for one callback.
class SelectionSheet<T> extends StatefulWidget {
  const SelectionSheet({
    super.key,
    required this.title,
    required this.sections,
    required this.labelBuilder,
    this.titleBuilder,
    this.selected,
    this.onSelected,
    this.selectedMany,
    this.onSelectedMany,
    this.emptyLabel = '没有可选项',
    this.searchHint = '搜索',
    this.footer,
  });

  final String title;
  final List<SelectionSection<T>> sections;

  final String Function(T item) labelBuilder;

  /// Rich version of the row title; takes precedence when given.
  final Widget Function(T item)? titleBuilder;

  final T? selected;
  final ValueChanged<T>? onSelected;

  final Set<T>? selectedMany;
  final ValueChanged<Set<T>>? onSelectedMany;

  final String emptyLabel;
  final String searchHint;
  final String? footer;

  @override
  State<SelectionSheet<T>> createState() => _SelectionSheetState<T>();
}

class _SelectionSheetState<T> extends State<SelectionSheet<T>> {
  final _search = TextEditingController();
  var _query = '';

  /// Local copy for multi select: committed on confirm, discarded on cancel.
  late final Set<T> _multi = {...?widget.selectedMany};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _isMulti => widget.onSelectedMany != null;

  void _toggle(T item) {
    final onSelected = widget.onSelected;
    if (onSelected != null) {
      onSelected(item);
      return;
    }
    setState(() {
      if (!_multi.remove(item)) {
        _multi.add(item);
      }
    });
  }

  bool _isSelected(T item) =>
      _isMulti ? _multi.contains(item) : widget.selected == item;

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final sections = [
      for (final section in widget.sections)
        SelectionSection<T>(
          label: section.label,
          subtitleBuilder: section.subtitleBuilder,
          items: [
            for (final item in section.items)
              if (query.isEmpty ||
                  widget.labelBuilder(item).toLowerCase().contains(query))
                item,
          ],
        ),
    ];
    final total = sections.fold<int>(0, (sum, s) => sum + s.items.length);
    return CommonScaffold(
      title: widget.title,
      confirmationAction: _isMulti
          ? IconButtonData(
              glyph: AppGlyphs.check,
              tooltip: '确定',
              onPressed: () => Navigator.of(context).pop(_multi),
            )
          : null,
      isLoading: false,
      body: PageBody(
        dockSpacer: false,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchField(
              controller: _search,
              onChanged: (value) {
                setState(() => _query = value);
              },
            ),
          ),
          if (total == 0)
            EmptyStateBox(
              minHeight: 260,
              child: NullStatus(
                label: widget.emptyLabel,
                description: query.isEmpty ? null : '换个关键词再试',
                illustration: NullStatusIllustration.search,
              ),
            )
          else
            for (final section in sections)
              if (section.items.isNotEmpty)
                generateSection(
                  title: section.label,
                  items: [
                    for (final item in section.items)
                      DecorationListItem(
                        title:
                            widget.titleBuilder?.call(item) ??
                            Text(
                              widget.labelBuilder(item),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        subtitle: switch (section.subtitleBuilder) {
                          final builder? => Text(
                            builder(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          null => null,
                        },
                        isSelected: _isSelected(item),
                        trailing: _isSelected(item)
                            ? const SelectionCheck()
                            : null,
                        onPressed: () => _toggle(item),
                      ),
                  ],
                ),
          if (widget.footer case final footer?) ListFooter(text: footer),
          if (_isMulti)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                '已选 ${_multi.length} 项',
                style: context.listCaptionStyle,
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Open a single-select sheet and return the chosen entry, so the caller does not spell out
/// both `showFormSheet` and `SelectionSheet` generics.
Future<T?> showSelectionSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T item) labelBuilder,
  T? selected,
  String Function(T item)? subtitleBuilder,
  String emptyLabel = '没有可选项',
}) => showFormSheet<T>(
  context: context,
  props: const SheetProps(detents: [0.75]),
  builder: (_) => SelectionSheet<T>(
    title: title,
    sections: [
      SelectionSection<T>(
        label: title,
        items: items,
        subtitleBuilder: subtitleBuilder,
      ),
    ],
    labelBuilder: labelBuilder,
    selected: selected,
    onSelected: (item) => Navigator.of(context).pop(item),
    emptyLabel: emptyLabel,
  ),
);
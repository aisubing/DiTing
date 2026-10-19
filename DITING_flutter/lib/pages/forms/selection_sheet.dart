/// 带搜索的选择浮层（上游 `features/form/selection_sheet.dart`，346 行）。
///
/// 上游的 `SelectionSheet` 是「分段 + 搜索 + 可选揭示」的通用选择器：分段之间
/// 可以有不同数据源（比如「默认」+「已安装」），选中项会被打勾，支持单选与
/// 多选两种模式。这里是它的等价实现，但用泛型 + 回调而不是继承一个基类——
/// 演示层只需要一种行为，多一层继承只会让调用方多写一个子类。
library;

import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 一个分段：标题 + 若干条目。
class SelectionSection<T> {
  const SelectionSection({
    required this.label,
    required this.items,
    this.subtitleBuilder,
  });

  final String label;
  final List<T> items;

  /// 行副标题；`null` 表示该段的行不带副标题。
  final String Function(T item)? subtitleBuilder;
}

/// 通用选择浮层。
///
/// 单选用 [selected] + [onSelected]；多选用 [selectedMany] + [onSelectedMany]。
/// 两套回调而不是一个 `Set<T>`：单选时调用方往往要「选中即关闭」，多选要
/// 「勾完再确认」，语义差得太远，合成一个反而要每处都判断。
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

  /// 行标题。
  final String Function(T item) labelBuilder;

  /// 行标题的富文本版本；给了就优先用它。
  final Widget Function(T item)? titleBuilder;

  /// 单选模式的当前值。
  final T? selected;
  final ValueChanged<T>? onSelected;

  /// 多选模式的当前值。
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

  /// 多选模式的本地副本：点「确定」才提交，取消不影响外部状态。
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

  bool _isSelected(T item) => _isMulti
      ? _multi.contains(item)
      : widget.selected == item;

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
            child: SearchField(controller: _search, onChanged: (value) {
              setState(() => _query = value);
            }),
          ),
          if (total == 0)
            SizedBox(
              height: 260,
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
          if (widget.footer case final footer?)
            ListFooter(text: footer),
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

/// 打开一个单选浮层，返回选中的条目。
///
/// 调用点最常用的形态：给一组值、一个显示名，拿回结果。把它抽成函数是为了
/// 让调用方不必每次都写 `showFormSheet<...>` + `SelectionSheet<...>` 两层泛型。
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

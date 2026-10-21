/// 列表编辑页（上游 `features/form/list_editor_page.dart`，377 行）。
///
/// 一个「可搜索、可全选、可排序、可删除、可添加」的通用列表编辑页。上游把它
/// 做成泛型类 `ListEditorPage<T, K>` 让规则、节点、提供者共用；这里保留泛型，
/// 但把「行内编辑」简化为「点击回调」——演示层不需要每种类型各写一套编辑器。
library;

import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// 列表编辑页。
///
/// 排序用上下箭头而不是拖拽：拖拽在长列表里很难精确落点，而演示数据只有十来
/// 行，上下箭头反而更快。真实场景里拖拽更好，这里为了骨架可读性做了取舍。
class ListEditorPage<T> extends StatefulWidget {
  const ListEditorPage({
    super.key,
    required this.title,
    required this.items,
    required this.labelBuilder,
    this.subtitleBuilder,
    this.emptyLabel = '还没有任何条目',
    this.emptyDescription = '点右上角的加号添加第一条',
    this.addLabel = '添加',
    this.onAdd,
    this.onEdit,
    this.onSave,
    this.footer,
  });

  final String title;
  final List<T> items;
  final String Function(T item) labelBuilder;
  final String Function(T item)? subtitleBuilder;
  final String emptyLabel;
  final String emptyDescription;
  final String addLabel;
  final VoidCallback? onAdd;
  final ValueChanged<T>? onEdit;

  /// 返回 `null` 表示不提交（比如页面只是演示，没有真实保存动作）。
  final ValueChanged<List<T>>? onSave;

  final String? footer;

  @override
  State<ListEditorPage<T>> createState() => _ListEditorPageState<T>();
}

class _ListEditorPageState<T> extends State<ListEditorPage<T>> {
  final _search = TextEditingController();
  var _query = '';
  late List<T> _items = [...widget.items];
  final _selected = <int>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<int> get _visibleIndices => [
    for (var i = 0; i < _items.length; i++)
      if (_query.isEmpty ||
          widget.labelBuilder(_items[i]).toLowerCase().contains(_query))
        i,
  ];

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _items.length) {
      return;
    }
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(target, item);
    });
  }

  Future<void> _remove(int index) async {
    final label = widget.labelBuilder(_items[index]);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: CommonDialog(
        title: '删除条目',
        destructive: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
        child: Text('确定删除「$label」吗？该操作不可撤销。'),
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() {
      _items.removeAt(index);
      _selected.clear();
    });
    messenger?.showSnackBar(
      SnackBar(
        content: Text('已删除「$label」'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  void _deleteSelected() {
    setState(() {
      final indices = [..._selected]..sort((a, b) => b.compareTo(a));
      for (final index in indices) {
        if (index < _items.length) {
          _items.removeAt(index);
        }
      }
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final indices = _visibleIndices;
    return CommonScaffold(
      title: widget.title,
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.selectAll,
          tooltip: '全选当前结果',
          onPressed: indices.isEmpty
              ? null
              : () => setState(() {
                  if (_selected.length == indices.length) {
                    _selected.clear();
                  } else {
                    _selected
                      ..clear()
                      ..addAll(indices);
                  }
                }),
        ),
        IconButtonData(
          glyph: AppGlyphs.add,
          tooltip: widget.addLabel,
          onPressed: widget.onAdd,
        ),
      ],
      menuItems: [
        CommonPopupMenuItem(
          label: '删除选中项',
          glyph: AppGlyphs.delete,
          danger: true,
          onPressed: _selected.isEmpty ? null : _deleteSelected,
        ),
        CommonPopupMenuItem(
          label: '恢复默认顺序',
          glyph: AppGlyphs.reset,
          onPressed: () => setState(() => _items = [...widget.items]),
        ),
      ],
      body: PageBody(
        dockSpacer: false,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchField(
              controller: _search,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          if (indices.isEmpty)
            SizedBox(
              height: 300,
              child: NullStatus(
                label: _query.isEmpty ? widget.emptyLabel : '没有匹配的条目',
                description: _query.isEmpty
                    ? widget.emptyDescription
                    : '换个关键词再试',
                illustration: NullStatusIllustration.data,
                action: _query.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        child: const Text('清空搜索'),
                      ),
              ),
            )
          else
            generateSection(
              title: '共 ${_items.length} 条',
              items: [
                for (final index in indices)
                  _EditorRow<T>(
                    item: _items[index],
                    label: widget.labelBuilder(_items[index]),
                    subtitle: widget.subtitleBuilder?.call(_items[index]),
                    selected: _selected.contains(index),
                    position: indices.indexOf(index),
                    total: indices.length,
                    onToggle: () => setState(() {
                      if (!_selected.remove(index)) {
                        _selected.add(index);
                      }
                    }),
                    onEdit: widget.onEdit == null
                        ? null
                        : () => widget.onEdit!(_items[index]),
                    onMoveUp: () => _move(index, -1),
                    onMoveDown: () => _move(index, 1),
                    onRemove: () => _remove(index),
                  ),
              ],
              footer: widget.footer,
            ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                spacing: 6,
                children: [
                  Text(
                    '已选 ${_selected.length} 项',
                    style: context.listCaptionStyle,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _deleteSelected,
                    icon: GlyphIcon(
                      AppGlyphs.delete,
                      size: 16,
                      color: context.colorScheme.error,
                    ),
                    label: Text(
                      '删除',
                      style: AppTextStyle.subheadline
                          .of(context)
                          .copyWith(color: context.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 列表编辑行：勾选、标题、上移 / 下移 / 删除。
class _EditorRow<T> extends StatelessWidget {
  const _EditorRow({
    required this.item,
    required this.label,
    required this.selected,
    required this.position,
    required this.total,
    required this.onToggle,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    this.subtitle,
    this.onEdit,
  });

  final T item;
  final String label;
  final String? subtitle;
  final bool selected;
  final int position;
  final int total;
  final VoidCallback onToggle;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return DecorationListItem(
      isSelected: selected,
      onPressed: onToggle,
      leading: CommonCheckBox(
        value: selected,
        isCircle: true,
        onChanged: (_) => onToggle(),
      ),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          CommonMinIconButtonTheme(
            child: IconButton(
              tooltip: '上移',
              onPressed: position == 0 ? null : onMoveUp,
              icon: const GlyphIcon(AppGlyphs.arrowUp, size: 18),
            ),
          ),
          CommonMinIconButtonTheme(
            child: IconButton(
              tooltip: '下移',
              onPressed: position == total - 1 ? null : onMoveDown,
              icon: const GlyphIcon(AppGlyphs.arrowDown, size: 18),
            ),
          ),
          CommonMinIconButtonTheme(
            child: IconButton(
              tooltip: '删除',
              onPressed: onRemove,
              icon: GlyphIcon(
                AppGlyphs.removeCircle,
                size: 18,
                color: colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

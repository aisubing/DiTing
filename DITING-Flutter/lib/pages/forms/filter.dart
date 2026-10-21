/// 过滤器输入（上游 `features/form/filter.dart`，57 行）。
///
/// 上游的过滤器是一个反引号分隔的字符串，逐段拼成正则；输入框下面实时显示
/// 命中数，让用户边打边看结果。这里保留「反引号分隔 + 实时校验」的语义，
/// 但把正则从页面里抽出来单独做高亮渲染（`FilterRegexText`）。
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 把反引号分隔的过滤串拆成若干段，去掉空白段。
///
/// 为什么用反引号而不是逗号：域名与正则里都可能出现逗号，反引号在两者里都
/// 极少见，不需要转义。
List<String> parseFilterParts(String raw) => [
  for (final part in raw.split('`'))
    if (part.trim().isNotEmpty) part.trim(),
];

/// 一行的过滤器输入：左侧是放大镜字形，右侧是输入框。
class FilterField extends StatefulWidget {
  const FilterField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText = '用 ` 分隔多个条件',
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String hintText;
  final bool enabled;

  @override
  State<FilterField> createState() => _FilterFieldState();
}

class _FilterFieldState extends State<FilterField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FilterField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部重置（「清空筛选」按钮）时同步文本框，但不能在用户输入过程中
    // 覆盖光标，所以只在值真的不同且不是本次输入造成的时候写回。
    if (widget.value != _controller.text && widget.value != oldWidget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: ShapeDecoration(
          shape: AppShape.full,
          color: context.raisedSurfaceLevel.colorOf(colorScheme),
        ),
        child: Row(
          spacing: 8,
          children: [
            GlyphIcon(
              AppGlyphs.filter,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: widget.enabled,
                onChanged: widget.onChanged,
                style: context.listTitleStyle,
                decoration: InputDecoration.collapsed(
                  hintText: widget.hintText,
                  hintStyle: context.listCaptionStyle,
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _controller.clear();
                  widget.onChanged('');
                },
                child: GlyphIcon(
                  AppGlyphs.close,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 把过滤串按段渲染成小标签，让用户看清「现在有哪几个条件」。
///
/// 反引号在输入框里看不见边界，尤其是段里有空格时；单独渲染一遍比在输入框
/// 里加高亮简单，也更容易读。
class FilterRegexText extends StatelessWidget {
  const FilterRegexText({super.key, required this.raw, this.onRemove});

  final String raw;

  /// 点掉某一或多段后的回调；`null` 表示只读展示。
  final ValueChanged<String>? onRemove;

  @override
  Widget build(BuildContext context) {
    final parts = parseFilterParts(raw);
    if (parts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text('还没有条件', style: context.listCaptionStyle),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final part in parts)
            CommonChip(
              label: part,
              onDeleted: onRemove == null
                  ? null
                  : () => onRemove!(
                      [
                        for (final other in parts)
                          if (other != part) other,
                      ].join('`'),
                    ),
            ),
        ],
      ),
    );
  }
}

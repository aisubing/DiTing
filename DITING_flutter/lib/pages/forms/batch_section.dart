/// 批量输入区（上游 `features/form/batch_section.dart`，49 行）。
///
/// 一个多行输入框套在 `DecorationListItem` 里：标题在左、输入框在右。上游用它
/// 在「添加规则」「编辑键值对」这类场合一次粘进几十行，逐行敲没有意义。
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 批量输入行。
///
/// 与 `FormRow` 的区别是它占据整行高度：多行输入框不能和单行标题挤在同一
/// 行里，所以标题在上、输入框在下。
class BatchSection extends StatelessWidget {
  const BatchSection({
    super.key,
    required this.controller,
    required this.hintText,
    this.title = '批量输入',
    this.footer,
    this.minLines = 4,
    this.maxLines = 10,
    this.monospace = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final String title;

  /// 输入框下的提示；批量输入几乎都需要说明分隔符。
  final String? footer;

  final int minLines;
  final int maxLines;
  final bool monospace;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final footer = this.footer;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          CommonCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    GlyphIcon(
                      AppGlyphs.code,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    Expanded(
                      child: Text(title, style: context.listTitleStyle),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        final lines = value.text.isEmpty
                            ? 0
                            : value.text
                                  .split('\n')
                                  .where((line) => line.trim().isNotEmpty)
                                  .length;
                        return Text(
                          '$lines 行',
                          style: context.listCaptionStyle.copyWith(
                            fontFamily: 'JetBrainsMono',
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: ShapeDecoration(
                    shape: AppShape.md,
                    color: context.raisedSurfaceLevel.colorOf(colorScheme),
                  ),
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    minLines: minLines,
                    maxLines: maxLines,
                    keyboardType: TextInputType.multiline,
                    style: AppTextStyle.subheadline.of(context).copyWith(
                      fontFamily: monospace ? 'JetBrainsMono' : null,
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: hintText,
                      hintStyle: context.listCaptionStyle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (footer != null) ListFooter(text: footer),
        ],
      ),
    );
  }
}

/// 带缩略图的选择组：每一项左边是一张缩略图，右边是名称与选中标记。
///
/// 上游 `views/theme_preview.dart` 的 `PreviewChoiceGroup` / `PreviewChoice`。
/// 外观类的选项几乎都是「看效果才知道选什么」（浮条还是普通底栏、淡入还是
/// 滑动），所以这里不放纯文字的单选行。
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 一个候选项。
class PreviewChoice<T> {
  const PreviewChoice({
    required this.value,
    required this.label,
    required this.pictogram,
    this.description,
  });

  final T value;
  final String label;

  /// 左侧缩略图；调用方负责限制尺寸。
  final Widget pictogram;

  /// 可选的一行说明，只在文字标签不足以区分时给。
  final String? description;
}

/// 标题 + 一组候选项。
class PreviewChoiceGroup<T> extends StatelessWidget {
  const PreviewChoiceGroup({
    super.key,
    required this.info,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.footer,
  });

  final Info info;
  final List<PreviewChoice<T>> choices;
  final T value;
  final ValueChanged<T> onChanged;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoHeader(info: info),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              generateSection(
                items: [
                  for (final choice in choices)
                    DecorationListItem(
                      leading: ExcludeSemantics(child: choice.pictogram),
                      title: Text(choice.label),
                      subtitle: switch (choice.description) {
                        final description? => Text(description),
                        null => null,
                      },
                      isSelected: choice.value == value,
                      trailing: choice.value == value
                          ? const SelectionCheck()
                          : null,
                      onPressed: () => onChanged(choice.value),
                    ),
                ],
              ),
              if (footer case final footer?) ListFooter(text: footer),
            ],
          ),
        ),
      ],
    );
  }
}

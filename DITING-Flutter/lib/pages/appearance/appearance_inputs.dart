/// 外观子树共用的小控件：分组卡片里的输入框、滑杆行。
///
/// 这些页面（首页句子 / 通知栏 / 首页透明度 / 字号）此前要么用裸
/// `OutlineInputBorder` 的 `TextField`、要么把滑杆直接铺在页面底色上，与设计
/// 系统其它页面的「填充圆角输入框 + 卡片分组」完全不是一套视觉。这里统一收口：
///
/// - 输入框一律走 [FilledInputTheme]（填充圆角、聚焦时主色描边）；
/// - 一组输入框/滑杆用一张 [CommonCard] 承载，圆角取 `xl`，与列表分组一致；
/// - 滑杆行用 [DecorationListItem] 承载，自动获得卡片与行间分隔线。
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 一张承载若干「标签 + 输入框」的卡片。
class FieldGroupCard extends StatelessWidget {
  const FieldGroupCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CommonCard(
      shape: AppShape.all(AppCorner.xl),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: children,
      ),
    );
  }
}

/// 「上方标签 + 多行输入框」。
///
/// [FilledInputTheme] 默认会把浮动标签关掉，因此标签单独放在输入框上方，
/// 而不是塞进 `InputDecoration.labelText`（那样会和内容叠字）。
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hintText,
    this.minLines = 2,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text(label, style: context.listTitleStyle),
        FilledInputTheme(
          borderRadius: AppRadius.md,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            minLines: minLines,
            maxLines: null,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(hintText: hintText),
          ),
        ),
      ],
    );
  }
}

/// 一条「标签 · 百分比 + 滑杆」的卡片行。
///
/// 用 [DecorationListItem] 承载而不是裸 `Padding`：这样它和同组的其它行共享
/// 一张卡片、行间自动出分隔线，也不会在页面底色上「漂浮」。
class SliderCardRow extends StatelessWidget {
  const SliderCardRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0.1,
    this.max = 1,
    this.divisions,
    this.glyph,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int? divisions;
  final Glyph? glyph;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final percent = '${(value * 100).round()}%';
    return DecorationListItem(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      minVerticalPadding: 4,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          Row(
            spacing: 10,
            children: [
              if (glyph != null)
                GlyphIcon(glyph!, size: 20, color: colorScheme.onSurfaceVariant),
              Expanded(child: Text(label, style: context.listTitleStyle)),
              Text(
                percent,
                style: context.listSubtitleStyle.copyWith(
                  fontFamily: 'JetBrainsMono',
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: percent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

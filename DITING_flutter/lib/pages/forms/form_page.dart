/// 表单族的基础构件（上游 `features/form/form_page.dart` + `form_row.dart`）。
///
/// 这一族解决的是同一个问题：一页里有多行「标题 + 右侧值」，值可能是纯文本、
/// 输入框、密码、开关、选项或跳转。上游把它们拆成 `FormRow` 的三种派生
/// （`FormRowTextField` / `FormRowSecretTextField`）+ `FormPage` 容器；本仓照抄
/// 这个分层，只是把 `FormRow` 的内边距换成 `DecorationListItem`，与列表行同源。
///
/// 按 550 行上限拆成库根 + part：本文件是 `FormPage` 与 `FormRow`，
/// 输入框派生在 `form_row_fields.dart`。
library;

import 'package:diting/pages/forms/custom_issue.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

part 'form_row_fields.dart';

/// 表单页容器：一个标题 + 若干 `FormRow` + 顶部的错误条与保存动作。
///
/// 上游把「保存」放在 `CommonScaffold.confirmationAction` 里（一个对勾图标），
/// 保存中显示 loading、失败时在页首显示错误条。这里保持同样的语义，但把
/// 保存按钮做成可配置的文字按钮——演示页里它常常需要「测试连接」这类文案。
class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.children,
    this.onSave,
    this.saveLabel = '保存',
    this.error,
    this.saving = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.footer,
  });

  final String title;
  final List<Widget> children;

  /// `null` 表示只读表单，底部不给动作。
  final VoidCallback? onSave;

  final String saveLabel;

  /// 顶部错误条；非空时自动展开，不需要调用方再判断。
  final String? error;

  final bool saving;
  final EdgeInsets padding;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    final onSave = this.onSave;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (error != null) ErrorBanner(message: error),
        Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 4,
            children: [
              if (title.isNotEmpty) ListHeader(title: title),
              // 横向留白由外层 [padding] 统一给（组头、组脚和它对齐），
              // `generateSection` 再给一次会让卡片比标题缩进一倍。
              generateSection(padding: EdgeInsets.zero, items: children),
              if (footer case final footer?) ListFooter(text: footer),
            ],
          ),
        ),
        if (onSave != null)
          Padding(
            padding: padding.copyWith(top: 4, bottom: 16),
            child: TonalButton(
              label: saving ? '处理中…' : saveLabel,
              glyph: saving ? null : AppGlyphs.check,
              size: TonalButtonSize.section,
              onPressed: saving ? null : onSave,
            ),
          ),
      ],
    );
  }
}

/// 一行表单：左标题、右值。
///
/// 有 trailing 时标题最多占一半宽度——否则一个长标题会把值挤成省略号，
/// 而值往往才是用户要核对的内容。
class FormRow extends StatelessWidget {
  static const double _spacing = 16;
  static const double _titleMaxWidthFactor = 0.5;

  const FormRow({
    super.key,
    required this.title,
    this.titleStyle,
    this.leading,
    this.trailing,
    this.invalid = false,
    this.onPressed,
    this.description,
  });

  final String title;
  final TextStyle? titleStyle;
  final Widget? leading;
  final Widget? trailing;

  /// 校验失败：整行用错误色描边（上游 `invalid`）。
  final bool invalid;

  final VoidCallback? onPressed;

  /// 标题下的一行说明；`FormRow` 本身不伸进 `subtitle`，需要时用它。
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final trailing = this.trailing;
    final description = this.description;
    final titleText = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: titleStyle ?? context.listTitleStyle,
    );
    return DecorationListItem(
      invalid: invalid,
      onPressed: onPressed,
      minVerticalPadding: trailing == null ? null : 0,
      leading: leading,
      title: LayoutBuilder(
        builder: (context, constraints) {
          final label = description == null
              ? titleText
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    titleText,
                    Text(description, style: context.listCaptionStyle),
                  ],
                );
          final constrainedLabel = trailing == null
              ? label
              : ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        (constraints.maxWidth - _spacing) *
                        _titleMaxWidthFactor,
                  ),
                  child: label,
                );
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: _spacing,
            children: [
              Flexible(child: constrainedLabel),
              if (trailing != null)
                Flexible(
                  child: IconTheme(
                    data: IconThemeData(
                      size: 16,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: DefaultTextStyle.merge(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        child: trailing,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 「+ / −」圆形按钮（上游 `EntryButton`）。
class EntryButton extends StatelessWidget {
  const EntryButton.add({super.key, required this.onPressed}) : _add = true;

  const EntryButton.remove({super.key, required this.onPressed})
    : _add = false;

  final VoidCallback? onPressed;
  final bool _add;

  @override
  Widget build(BuildContext context) {
    return CommonMinIconButtonTheme(
      child: IconButton(
        tooltip: _add ? '添加' : '删除',
        onPressed: onPressed,
        icon: GlyphIcon(
          _add ? AppGlyphs.addCircle : AppGlyphs.removeCircle,
          size: 24,
        ),
      ),
    );
  }
}

/// 一个「这里有说明」的小图标按钮，点开弹消息（上游 `InfoMessageButton`）。
///
/// 用在「这一行看起来不对，但原因不方便一直显示」的场合：图标常驻，说明按需。
class InfoMessageButton extends StatelessWidget {
  const InfoMessageButton({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return CommonMinIconButtonTheme(
      child: IconButton(
        tooltip: '说明',
        onPressed: () => showMessageDialog(context, message),
        icon: GlyphIcon(
          AppGlyphs.info,
          fill: 1,
          size: 20,
          color: context.colorScheme.error,
        ),
      ),
    );
  }
}

/// 纯文本消息弹窗。
Future<void> showMessageDialog(BuildContext context, String message) =>
    showFloatingDialog<void>(
      context: context,
      child: CommonDialog(
        title: '说明',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
        child: Text(message),
      ),
    );

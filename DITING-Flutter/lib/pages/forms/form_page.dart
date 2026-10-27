/// Form building blocks (upstream `form_page.dart` / `form_row.dart`).
library;

import 'package:diting/pages/forms/custom_issue.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

part 'form_row_fields.dart';

/// Form page container: title, `FormRow`s, a top error bar and a save action. The save
/// label is configurable because demo pages need text such as "test connection".
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

  /// `null` renders a read-only form without a bottom action.
  final VoidCallback? onSave;

  final String saveLabel;

  /// Top error bar; it expands itself when non-empty.
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
              // Horizontal padding comes from the outer [padding] so the card aligns
              // with its header and footer.
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

/// With a trailing widget the title is capped at half width so the value is not ellipsized.
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

  final bool invalid;

  final VoidCallback? onPressed;

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

/// Round "+ / -" button (upstream `EntryButton`).
class EntryButton extends StatelessWidget {
  const EntryButton.add({super.key, required this.onPressed}) : _add = true;

  const EntryButton.remove({super.key, required this.onPressed}) : _add = false;

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

/// Small info button that opens a message (upstream `InfoMessageButton`), for rows
/// whose explanation should not be permanently visible.
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

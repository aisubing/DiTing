library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// Immediate feedback for a config change: these switches apply at once, so a rejection
/// would otherwise show only as the switch bouncing back.
void showConfigHint(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1600),
    ),
  );
}

Future<bool> confirmConfigAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '删除',
}) async {
  final confirmed = await showFloatingDialog<bool>(
    context: context,
    child: CommonDialog(
      title: title,
      destructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
      child: Text(message),
    ),
  );
  return confirmed ?? false;
}

/// Not `ListItem.input`, which opens a dialog on tap.
class ConfigFieldRow extends StatelessWidget {
  const ConfigFieldRow({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final Widget child;

  /// Note below the field, better than a placeholder for explaining the value.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 12,
            children: [
              SizedBox(
                width: 76,
                child: Text(label, style: context.listTitleStyle),
              ),
              Expanded(child: child),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 88),
              child: Text(hint, style: context.listCaptionStyle),
            ),
        ],
      ),
    );
  }
}

/// Explainer card for pages whose rules are not obvious.
class ConfigNoteCard extends StatelessWidget {
  const ConfigNoteCard({
    super.key,
    required this.text,
    this.glyph = AppGlyphs.info,
  });

  final String text;
  final Glyph glyph;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: CommonCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              GlyphIcon(glyph, size: 18, color: colorScheme.onSurfaceVariant),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trailing remove button, wrapped in `CommonMinIconButtonTheme`: a default IconButton tap
/// target would stretch the row height.
class ConfigRemoveButton extends StatelessWidget {
  const ConfigRemoveButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.glyph = AppGlyphs.removeCircle,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Glyph glyph;

  @override
  Widget build(BuildContext context) {
    return CommonMinIconButtonTheme(
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: GlyphIcon(
          glyph,
          size: 18,
          color: onPressed == null
              ? context.colorScheme.onSurface.withValues(alpha: 0.3)
              : context.colorScheme.error,
        ),
      ),
    );
  }
}

/// Subtitle for list entries: report the count, and explain an empty list.
String configListSummary(List<String> items, {String empty = '未设置'}) =>
    items.isEmpty ? empty : '共 ${items.length} 项';

/// Entry row that opens another page: icon, title, one-line subtitle and chevron,
/// identical across the override and resource pages.
class ConfigEntryRow extends StatelessWidget {
  const ConfigEntryRow({
    super.key,
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.enabled = true,
  });

  final Glyph glyph;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return ListItem(
      leading: GlyphIcon(
        glyph,
        size: 20,
        color: enabled ? null : colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: GlyphIcon(
        AppGlyphs.chevronForward,
        size: 16,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: enabled ? onPressed : null,
    );
  }
}
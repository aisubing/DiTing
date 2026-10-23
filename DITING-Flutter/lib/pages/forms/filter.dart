/// Filter input (upstream `features/form/filter.dart`).
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// Backticks rather than commas because domains and regexes can contain commas.
List<String> parseFilterParts(String raw) => [
  for (final part in raw.split('`'))
    if (part.trim().isNotEmpty) part.trim(),
];

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
    // Sync the field on an external reset, but never clobber the cursor mid-typing,
    // so write back only when the value really differs.
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

/// Render the filter as chips so the active conditions are visible; backtick
/// boundaries are invisible in the field, especially with spaces inside a segment.
class FilterRegexText extends StatelessWidget {
  const FilterRegexText({super.key, required this.raw, this.onRemove});

  final String raw;

  /// Called with the removed segments; `null` means read-only.
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
part of 'editor_page.dart';

/// Completion popup. Upstream anchors it below the caret; here it sits at the bottom of the
/// editor, keeping the candidates, their order and the insert behavior.
class _CompletionPopup extends StatelessWidget {
  const _CompletionPopup({
    required this.items,
    required this.onSelected,
    required this.onDismiss,
  });

  final List<MockCompletion> items;
  final ValueChanged<MockCompletion> onSelected;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: CommonCard(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 4, 4),
              child: Row(
                children: [
                  GlyphIcon(
                    AppGlyphs.sparkle,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('补全候选', style: context.listCaptionStyle),
                  ),
                  CommonMinIconButtonTheme(
                    child: IconButton(
                      tooltip: '收起',
                      onPressed: onDismiss,
                      icon: const GlyphIcon(AppGlyphs.close, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 168),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in items)
                      InkWell(
                        onTap: () => onSelected(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Row(
                            spacing: 10,
                            children: [
                              GlyphIcon(
                                item.isKey
                                    ? AppGlyphs.key
                                    : AppGlyphs.textShort,
                                size: 14,
                                color: item.isKey
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: _codeStyle.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                item.detail,
                                style: context.listCaptionStyle,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
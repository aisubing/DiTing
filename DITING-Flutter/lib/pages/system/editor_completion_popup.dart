part of 'editor_page.dart';

/// 补全浮层。
///
/// 上游把浮层定位到光标下方（`TextPainter` 量出光标矩形再 `CompositedTransform`
/// 过去）。演示层把浮层放在编辑器底部：位置差一点，但「哪些候选、按什么顺序、
/// 点了插什么」这些真正要验证的东西都还在，而定位代码是上游 216 行里最不
/// 可复用的部分。
///
/// 拆到这个 part 是因为 `editor_page.dart` 已到 550 行上限（AGENTS.md），
/// 而本轮还要给页面补「演示页」标注。
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

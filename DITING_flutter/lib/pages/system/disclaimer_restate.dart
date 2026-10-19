part of 'disclaimer_page.dart';

/// 逐字复述确认对话框（上游 `_RestateDialog`，第 400 行起）。
///
/// 每次输入都重新比较，只有完全一致才允许确认——所以这里不是「输入框 + 按钮」
/// 的简单组合，而是一个自带校验状态的组件。上游把三种状态做成
/// `_Restatement.complete / diverged`，这里用「是否为空 + 是否匹配」两个布尔
/// 推导：空的时候不该报「不一致」，那会让用户一进来就看到红字。
class _RestateDialog extends StatefulWidget {
  const _RestateDialog({
    required this.statement,
    required this.title,
    required this.description,
  });

  final String statement;
  final String title;
  final String description;

  @override
  State<_RestateDialog> createState() => _RestateDialogState();
}

class _RestateDialogState extends State<_RestateDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches => _controller.text.trim() == widget.statement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final typed = _controller.text.trim();
    final diverged = typed.isNotEmpty && !_matches;
    return CommonScaffold(
      title: widget.title,
      body: PageBody(
        dockSpacer: false,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(widget.description, style: context.listSubtitleStyle),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: ShapeDecoration(
                shape: AppShape.md,
                color: context.raisedSurfaceLevel.colorOf(colorScheme),
              ),
              child: Text(
                widget.statement,
                style: AppTextStyle.body.of(context, emphasized: true),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '在此逐字输入',
                errorText: diverged ? '与上面那句不一致' : null,
                border: AppShape.input,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              spacing: 8,
              children: [
                GlyphIcon(
                  _matches ? AppGlyphs.checkCircle : AppGlyphs.keyboard,
                  size: 16,
                  color: _matches
                      ? colorScheme.success
                      : colorScheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Text(
                    _matches
                        ? '一致，可以确认了'
                        : '还需要输入 ${widget.statement.length} 个字中的 '
                              '${widget.statement.length - typed.length} 个',
                    style: context.listCaptionStyle.copyWith(
                      color: _matches ? colorScheme.success : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 10,
              children: [
                Expanded(
                  child: TonalButton(
                    label: '取消',
                    size: TonalButtonSize.section,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: TonalButton(
                    label: '确认',
                    glyph: AppGlyphs.check,
                    size: TonalButtonSize.section,
                    onPressed: _matches
                        ? () => Navigator.of(context).pop(true)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 打开复述确认浮层；返回 `true` 表示已确认。
Future<bool?> showRestateDialog({
  required BuildContext context,
  required String statement,
  required String title,
  required String description,
}) => showFormSheet<bool>(
  context: context,
  props: const SheetProps(detents: [0.85]),
  builder: (_) => _RestateDialog(
    statement: statement,
    title: title,
    description: description,
  ),
);

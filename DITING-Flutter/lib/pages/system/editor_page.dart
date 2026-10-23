/// YAML editor skeleton (upstream `pages/editor.dart`): line numbers, static highlighting,
/// completion popup, save and format over mock YAML. Highlighting overrides
/// `buildTextSpan`, so IME stays native.
library;

import 'package:diting/data/mock_forms.dart';
import 'package:diting/pages/forms/nested_form_sheet.dart';
import 'package:diting/pages/system/demo_page_notice.dart';
import 'package:diting/pages/system/yaml_highlighter.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

part 'editor_completion_popup.dart';

/// Line height shared by the gutter and the text, which must match to stay aligned.
const _lineHeight = 19.5;
const _codeFontSize = 13.0;
const _codeStyle = TextStyle(
  fontFamily: 'JetBrainsMono',
  fontSize: _codeFontSize,
  height: _lineHeight / _codeFontSize,
);

class YamlEditingController extends TextEditingController {
  YamlEditingController({super.text, required this.palette});

  /// Highlight colors; the page rebuilds or mutates this on theme change.
  HighlightPalette palette;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    final lines = text.split('\n');
    final children = <TextSpan>[];
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) {
        children.add(const TextSpan(text: '\n'));
      }
      children.add(buildHighlightSpan(lines[i], palette, base));
    }
    return TextSpan(style: base, children: children);
  }
}

/// A true [readOnly] hides every edit entry, so the same view can display a config file.
class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    this.title = '编辑配置',
    this.initialContent = mockYamlDocument,
    this.readOnly = false,
  });

  final String title;
  final String initialContent;
  final bool readOnly;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final YamlEditingController _controller;
  final _scroll = ScrollController();
  final _focus = FocusNode();

  late String _saved;

  var _completions = const <MockCompletion>[];

  @override
  void initState() {
    super.initState();
    _saved = widget.initialContent;
    _controller = YamlEditingController(
      text: widget.initialContent,
      palette: HighlightPalette.of(_fallbackScheme),
    )..addListener(_onChanged);
  }

  /// `initState` cannot read `Theme`, so placeholders stand in until `build`.
  static const _fallbackScheme = ColorScheme.light();

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _dirty => _controller.text != _saved;

  void _onChanged() {
    setState(() => _completions = _suggestions());
  }

  List<MockCompletion> _suggestions() {
    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return const [];
    }
    final text = _controller.text;
    final offset = selection.baseOffset.clamp(0, text.length);
    var start = offset;
    while (start > 0 && _isWordChar(text[start - 1])) {
      start--;
    }
    final prefix = text.substring(start, offset).toLowerCase();
    if (prefix.length < 2) {
      return const [];
    }
    return [
      for (final item in mockCompletions)
        if (item.label.toLowerCase().startsWith(prefix)) item,
    ].take(6).toList();
  }

  static bool _isWordChar(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        char == '-' ||
        char == '_';
  }

  void _applyCompletion(MockCompletion item) {
    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return;
    }
    final text = _controller.text;
    final offset = selection.baseOffset.clamp(0, text.length);
    var start = offset;
    while (start > 0 && _isWordChar(text[start - 1])) {
      start--;
    }
    final next = text.replaceRange(start, offset, item.label);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + item.label.length),
    );
    _focus.requestFocus();
  }

  void _format() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final lines = _controller.text.split('\n');
    final formatted = <String>[];
    for (final line in lines) {
      final expanded = line.replaceAll('\t', '  ');
      final trimmedRight = expanded.replaceAll(RegExp(r'\s+$'), '');
      // Collapse extra spaces after a `- ` list marker into one.
      final neat = trimmedRight.replaceFirst(RegExp(r'^- +'), '- ');
      formatted.add(neat);
    }
    _controller.value = TextEditingValue(
      text: formatted.join('\n'),
      selection: TextSelection.collapsed(offset: 0),
    );
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('已格式化：去行尾空格、展开 tab、收敛列表前缀'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1800),
      ),
    );
  }

  void _save() {
    setState(() => _saved = _controller.text);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('已保存（演示：只写内存，不落盘）'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1600),
      ),
    );
  }

  void _restore() {
    _controller.value = TextEditingValue(
      text: _saved,
      selection: TextSelection.collapsed(offset: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    _controller.palette = HighlightPalette.of(colorScheme);
    final lines = _controller.text.split('\n').length;
    // A full-screen route still needs the dirty-value guard: the Android back gesture
    // would pop it and lose unsaved edits. Reuses `NestedFormSheet`'s `CommonPopScope`.
    return NestedFormSheet(
      title: widget.title,
      isDirty: () => _dirty,
      onSave: widget.readOnly ? null : _save,
      confirmMessage: 'YAML 有未保存的修改，确定要离开吗？',
      saveLabel: '保存并退出',
      iconActions: [
        IconButtonData(
          glyph: AppGlyphs.sparkle,
          tooltip: '格式化',
          onPressed: widget.readOnly ? null : _format,
        ),
        IconButtonData(
          glyph: AppGlyphs.undo,
          tooltip: '还原到上次保存',
          onPressed: widget.readOnly || !_dirty ? null : _restore,
        ),
      ],
      confirmationAction: widget.readOnly
          ? null
          : IconButtonData(
              glyph: AppGlyphs.check,
              tooltip: '保存',
              onPressed: _save,
            ),
      child: Column(
        children: [
          const DemoPageNotice(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: CommonCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LineGutter(lineCount: lines, scroll: _scroll),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(10, 0, 12, 16),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          readOnly: widget.readOnly,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          style: _codeStyle.copyWith(
                            color: colorScheme.onSurface,
                          ),
                          strutStyle: const StrutStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: _codeFontSize,
                            height: _lineHeight / _codeFontSize,
                            forceStrutHeight: true,
                          ),
                          cursorColor: colorScheme.primary,
                          decoration: InputDecoration.collapsed(
                            hintText: '在此输入 YAML…',
                            hintStyle: context.listCaptionStyle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_completions.isNotEmpty)
            _CompletionPopup(
              items: _completions,
              onSelected: _applyCompletion,
              onDismiss: () => setState(() => _completions = const []),
            ),
          _EditorStatusBar(
            lineCount: lines,
            charCount: _controller.text.length,
            dirty: _dirty,
            readOnly: widget.readOnly,
            onSave: widget.readOnly ? null : _save,
            onFormat: widget.readOnly ? null : _format,
          ),
        ],
      ),
    );
  }
}

/// Builds only visible numbers from `scroll.offset` and shares `_lineHeight` with the text.
class _LineGutter extends StatelessWidget {
  const _LineGutter({required this.lineCount, required this.scroll});

  final int lineCount;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final style = _codeStyle.copyWith(
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
    );
    return SizedBox(
      width: 42,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ClipRect(
            child: AnimatedBuilder(
              animation: scroll,
              builder: (context, _) {
                final offset = scroll.hasClients ? scroll.offset : 0.0;
                final first = (offset / _lineHeight).floor().clamp(
                  0,
                  lineCount,
                );
                final visible =
                    (constraints.maxHeight / _lineHeight).ceil() + 2;
                final last = (first + visible).clamp(0, lineCount);
                return Transform.translate(
                  offset: Offset(0, first * _lineHeight - offset),
                  // One padded line above and below; `OverflowBox` relaxes the height
                  // limit, otherwise the Column overflows the viewport by 63 pixels.
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = first + 1; i <= last; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text('$i', style: style),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}


/// Completion popup; lives in `editor_completion_popup.dart`, since this file is at the line cap.
class _EditorStatusBar extends StatelessWidget {
  const _EditorStatusBar({
    required this.lineCount,
    required this.charCount,
    required this.dirty,
    required this.readOnly,
    this.onSave,
    this.onFormat,
  });

  final int lineCount;
  final int charCount;
  final bool dirty;
  final bool readOnly;
  final VoidCallback? onSave;
  final VoidCallback? onFormat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: ShapeDecoration(
        color: SurfaceLevel.card.colorOf(colorScheme),
        shape: AppShape.top(AppCorner.lg),
      ),
      child: Row(
        spacing: 10,
        children: [
          GlyphIcon(
            dirty ? AppGlyphs.edit : AppGlyphs.checkCircle,
            size: 16,
            color: dirty ? colorScheme.warning : colorScheme.success,
          ),
          Expanded(
            child: Text(
              readOnly
                  ? '$lineCount 行 · $charCount 字符 · 只读'
                  : '$lineCount 行 · $charCount 字符 · ${dirty ? '有未保存的修改' : '已保存'}',
              style: context.listCaptionStyle.copyWith(
                fontFamily: 'JetBrainsMono',
              ),
            ),
          ),
          if (onFormat != null)
            TonalButton(
              label: '格式化',
              size: TonalButtonSize.compact,
              onPressed: onFormat,
            ),
          if (onSave != null)
            TonalButton(
              label: '保存',
              glyph: AppGlyphs.check,
              size: TonalButtonSize.compact,
              onPressed: onSave,
            ),
        ],
      ),
    );
  }
}

/// Page shell for the demo entry; the notice is drawn by `EditorPage` itself.
class EditorDemoPage extends StatelessWidget {
  const EditorDemoPage({super.key});

  @override
  Widget build(BuildContext context) => const EditorPage();
}
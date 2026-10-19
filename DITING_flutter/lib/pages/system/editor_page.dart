/// YAML 编辑器骨架（上游 `pages/editor.dart`，1260 行）。
///
/// 本轮只做骨架：行号栏、静态语法高亮、输入时的补全浮层、保存 / 格式化按钮，
/// 以及一段假 YAML。**不接真实解析器、不做错误检查、不落盘**——上游那一千多行
/// 里大半是增量解析与撤销栈，本阶段不做。
///
/// 高亮通过覆写 `TextEditingController.buildTextSpan` 实现：这样光标、选区、
/// 输入法组合都还是 Flutter 原生的行为，只需要把「一行文本」换成「一行的
/// 多个带色片段」。比在 `Text` 上叠一个透明 `TextField` 稳得多。
library;

import 'package:diting/data/mock_forms.dart';
import 'package:diting/pages/forms/nested_form_sheet.dart';
import 'package:diting/pages/system/yaml_highlighter.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 代码行的行高；行号栏与正文必须共用同一个值才对齐。
const _lineHeight = 19.5;
const _codeFontSize = 13.0;
const _codeStyle = TextStyle(
  fontFamily: 'JetBrainsMono',
  fontSize: _codeFontSize,
  height: _lineHeight / _codeFontSize,
);

/// 带高亮的文本控制器。
class YamlEditingController extends TextEditingController {
  YamlEditingController({super.text, required this.palette});

  /// 高亮配色；主题变化时由页面重建控制器或直接改这个字段再触发重绘。
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

/// 编辑器页。
///
/// [readOnly] 为真时隐藏所有改动入口——同一套视图也用来「查看」配置文件。
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

  /// 上次保存的内容，用来判断 dirty。
  late String _saved;

  /// 补全候选项；空表示浮层收起。
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

  /// `initState` 里拿不到 `Theme`，先给一套占位配色，`build` 时再换成当前主题。
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

  /// 根据光标前最后一个词给出补全候选。
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

  /// 用候选词替换光标前的那个词。
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

  /// 极简格式化：去掉行尾空格、把 tab 换成两个空格、统一列表缩进。
  void _format() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final lines = _controller.text.split('\n');
    final formatted = <String>[];
    for (final line in lines) {
      final expanded = line.replaceAll('\t', '  ');
      final trimmedRight = expanded.replaceAll(RegExp(r'\s+$'), '');
      // 列表项的 `- ` 后若有多余空格，收敛成一个。
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
    // 编辑器是「全屏路由」而不是浮层，但脏值保护的需求与浮层一致：Android 的
    // 返回手势会直接弹掉页面，未保存的改动就没了。`NestedFormSheet` 的
    // `CommonPopScope` 正是干这个的，复用它而不是再写一遍拦截逻辑。
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

/// 行号栏。
///
/// 只渲染视口内的行号，并用 `scroll.offset` 反推位移——这样长文件不会一次建
/// 出几千个 `Text`，滚动时行号也与正文严丝合缝。`_lineHeight` 必须与正文共享
/// 同一个常数，否则两边会越滚越偏。
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
                final visible = (constraints.maxHeight / _lineHeight).ceil() + 2;
                final last = (first + visible).clamp(0, lineCount);
                return Transform.translate(
                  offset: Offset(0, first * _lineHeight - offset),
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// 补全浮层。
///
/// 上游把浮层定位到光标下方（`TextPainter` 量出光标矩形再 `CompositedTransform`
/// 过去）。演示层把浮层放在编辑器底部：位置差一点，但「哪些候选、按什么顺序、
/// 点了插什么」这些真正要验证的东西都还在，而定位代码是上游 216 行里最不
/// 可复用的部分。
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

/// 底部状态栏：行列统计、保存 / 格式化按钮。
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

/// 页面外壳：演示入口用（`/editor` 路由直接建 `EditorPage`）。
class EditorDemoPage extends StatelessWidget {
  const EditorDemoPage({super.key});

  @override
  Widget build(BuildContext context) => const EditorPage();
}

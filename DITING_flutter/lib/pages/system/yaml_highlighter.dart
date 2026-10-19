/// YAML 静态高亮（演示层自己的极简分词器）。
///
/// 上游编辑器接的是真实语法树 + 补全引擎；本阶段只做骨架，所以这里用逐行的
/// 简单规则给三种东西上色：注释、键、值。它不追求正确性——`{{ }}` 模板、
/// 多行标量、锚点都会被当成普通文本，这在演示里可接受，而且规则简单到一眼
/// 能看不出意外。
///
/// 为什么不用 `flutter_highlight`：多一个依赖只为给十几行 YAML 上色不划算，
/// 而且那个包按语言注册语法，包体积比这段代码大两个数量级。
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 一段被着色的文本。
class HighlightSpan {
  const HighlightSpan({
    required this.text,
    required this.kind,
  });

  final String text;
  final TokenKind kind;
}

/// 词法分类。
enum TokenKind {
  comment,
  key,
  string,
  number,
  keyword,
  punctuation,
  plain,
}

/// 一组颜色：由调用方按当前主题给出，高亮器本身不碰 `Theme`。
class HighlightPalette {
  const HighlightPalette({
    required this.comment,
    required this.key,
    required this.string,
    required this.number,
    required this.keyword,
    required this.punctuation,
    required this.plain,
  });

  /// 从当前配色推导一套高亮色。
  ///
  /// 键用主色、字符串用成功色、数字用警告色，这三组在深浅两个主题下都能与
  /// 背景拉开距离；注释与标点用低对比度的 `onSurfaceVariant`。
  factory HighlightPalette.of(ColorScheme colorScheme) => HighlightPalette(
    comment: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
    key: colorScheme.primary,
    string: colorScheme.success,
    number: colorScheme.warning,
    keyword: colorScheme.tertiary,
    punctuation: colorScheme.onSurfaceVariant,
    plain: colorScheme.onSurface,
  );

  final Color comment;
  final Color key;
  final Color string;
  final Color number;
  final Color keyword;
  final Color punctuation;
  final Color plain;

  Color of(TokenKind kind) => switch (kind) {
    TokenKind.comment => comment,
    TokenKind.key => key,
    TokenKind.string => string,
    TokenKind.number => number,
    TokenKind.keyword => keyword,
    TokenKind.punctuation => punctuation,
    TokenKind.plain => plain,
  };
}

/// YAML 里需要单独上色的布尔 / 空值 / 常用枚举。
const _keywords = {
  'true',
  'false',
  'null',
  'yes',
  'no',
  'on',
  'off',
  'rule',
  'global',
  'direct',
  'info',
  'warning',
  'debug',
  'error',
};

/// 把一行 YAML 切成带分类的片段。
///
/// 规则（按优先级）：
/// 1. `#` 之后全是注释——YAML 的字符串里 `#` 不该被当注释，但演示数据没有
///    这种写法，为它加状态机会让代码翻倍；
/// 2. `键:` 的键部分用主色；
/// 3. 值里的引号串用成功色，纯数字用警告色，布尔/枚举用 tertiary，其余原色。
List<HighlightSpan> highlightYamlLine(String line) {
  if (line.trimLeft().startsWith('#')) {
    return [HighlightSpan(text: line, kind: TokenKind.comment)];
  }
  final spans = <HighlightSpan>[];
  final commentIndex = _commentIndex(line);
  final code = commentIndex < 0 ? line : line.substring(0, commentIndex);
  final indent = code.length - code.trimLeft().length;
  if (indent > 0) {
    spans.add(
      HighlightSpan(text: code.substring(0, indent), kind: TokenKind.plain),
    );
  }
  final body = code.substring(indent);
  if (body.isEmpty) {
    if (commentIndex >= 0) {
      spans.add(
        HighlightSpan(
          text: line.substring(commentIndex),
          kind: TokenKind.comment,
        ),
      );
    }
    return spans;
  }
  // 列表项前缀：`- ` 属于标点，单独上色。
  var rest = body;
  if (rest.startsWith('- ')) {
    spans.add(const HighlightSpan(text: '- ', kind: TokenKind.punctuation));
    rest = rest.substring(2);
  }
  final colonIndex = _keySeparatorIndex(rest);
  if (colonIndex > 0) {
    spans.add(
      HighlightSpan(text: rest.substring(0, colonIndex), kind: TokenKind.key),
    );
    spans.add(
      const HighlightSpan(text: ':', kind: TokenKind.punctuation),
    );
    rest = rest.substring(colonIndex + 1);
  }
  _appendValue(spans, rest);
  if (commentIndex >= 0) {
    spans.add(
      HighlightSpan(text: line.substring(commentIndex), kind: TokenKind.comment),
    );
  }
  return spans;
}

/// 找到行内注释的起点；引号里的 `#` 不算。
int _commentIndex(String line) {
  var quote = '';
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (quote.isNotEmpty) {
      if (char == quote) {
        quote = '';
      }
      continue;
    }
    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }
    if (char == '#' && (i == 0 || line[i - 1] == ' ')) {
      return i;
    }
  }
  return -1;
}

/// 找键后的冒号：必须是「冒号 + 空格或结尾」，避免把 `https://` 里的冒号当分隔。
int _keySeparatorIndex(String body) {
  for (var i = 0; i < body.length - 1; i++) {
    if (body[i] == ':' && (body[i + 1] == ' ' || i == body.length - 1)) {
      return i;
    }
  }
  if (body.endsWith(':')) {
    return body.length - 1;
  }
  return -1;
}

/// 给一段值上色（可能包含空格分隔的多个片段）。
void _appendValue(List<HighlightSpan> spans, String value) {
  if (value.isEmpty) {
    return;
  }
  final pattern = RegExp(r'''"[^"]*"|'[^']*'|[^\s]+|\s+''');
  for (final match in pattern.allMatches(value)) {
    final text = match.group(0)!;
    spans.add(HighlightSpan(text: text, kind: _kindOf(text)));
  }
}

TokenKind _kindOf(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return TokenKind.plain;
  }
  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
      (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
    return TokenKind.string;
  }
  if (num.tryParse(trimmed) != null) {
    return TokenKind.number;
  }
  if (_keywords.contains(trimmed.toLowerCase())) {
    return TokenKind.keyword;
  }
  if (trimmed.startsWith('[') ||
      trimmed.startsWith('{') ||
      trimmed.endsWith(',') ||
      trimmed.endsWith(']') ||
      trimmed.endsWith('}')) {
    return TokenKind.punctuation;
  }
  return TokenKind.plain;
}

/// 把整行渲染成 `TextSpan`。
TextSpan buildHighlightSpan(
  String line,
  HighlightPalette palette,
  TextStyle baseStyle,
) {
  final spans = highlightYamlLine(line);
  return TextSpan(
    style: baseStyle,
    children: [
      for (final span in spans)
        TextSpan(
          text: span.text,
          style: TextStyle(color: palette.of(span.kind)),
        ),
    ],
  );
}

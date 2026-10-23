/// Minimal static YAML highlighter; `flutter_highlight` is not worth its grammar payload here.
library;

import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

class HighlightSpan {
  const HighlightSpan({required this.text, required this.kind});

  final String text;
  final TokenKind kind;
}

enum TokenKind { comment, key, string, number, keyword, punctuation, plain }

/// A color set supplied by the caller; the highlighter never reads `Theme`.
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

  /// Derives a palette from the color scheme: keys primary, strings success, numbers
  /// warning, comments and punctuation the low-contrast `onSurfaceVariant`.
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

/// YAML booleans, nulls and common enums that get their own color.
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

/// Splits one YAML line into categorized spans. Everything after `#` is a comment (the demo
/// data never quotes a `#`); the key before `:` uses primary, quoted values success, plain
/// numbers warning, booleans and enums tertiary.
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
  // The `- ` list marker counts as punctuation and is colored separately.
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
    spans.add(const HighlightSpan(text: ':', kind: TokenKind.punctuation));
    rest = rest.substring(colonIndex + 1);
  }
  _appendValue(spans, rest);
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

/// Start of the inline comment; a `#` inside quotes does not count.
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

/// Finds the key separator: a colon followed by a space or end of line, so the one in
/// `https://` is not treated as a separator.
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

/// Renders the whole line as a `TextSpan`.
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
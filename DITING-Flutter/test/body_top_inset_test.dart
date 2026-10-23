import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards that `CommonScaffold.body` reserves the app bar inset itself: under
/// `extendBodyBehindAppBar` a bare `ListView` renders its first line under the app bar
void main() {
  const topAligned = <String>[
    'ListView',
    'CustomScrollView',
    'SingleChildScrollView',
    'Form(',
    'ReorderableListView',
  ];

  const clears = <String>[
    'contentTopPadding',
    'appBarInset',
    'PageBody',
    'AppBarClearance',
  ];

  /// Text of the `body:` expression up to its matching close paren. Counts parens, not
  /// lines: the expression spans a dozen lines and a line cut would miss the `padding:`
  String bodyExpression(List<String> lines, int startLine, int colonColumn) {
    final buffer = StringBuffer();
    var depth = 0;
    var started = false;
    for (var i = startLine; i < lines.length; i++) {
      final line = i == startLine ? lines[i].substring(colonColumn) : lines[i];
      for (var c = 0; c < line.length; c++) {
        final ch = line[c];
        buffer.write(ch);
        if (!started) {
          if (ch.trim().isEmpty) continue;
          started = true;
        }
        if (ch == '(' || ch == '[' || ch == '{') {
          depth++;
        } else if (ch == ')' || ch == ']' || ch == '}') {
          depth--;
          if (depth == 0 && i > startLine || depth < 0) return buffer.toString();
        }
      }
      final trimmed = buffer.toString().trimRight();
      if (started && depth == 0 && trimmed.isNotEmpty && !trimmed.endsWith(',')) {
        return trimmed;
      }
      if (started && depth <= 0) return buffer.toString();
    }
    return buffer.toString();
  }

  test('每个 CommonScaffold.body 都自己预留了顶栏浮位', () {
    final offenders = <String>[];

    final files =
        Directory('lib/pages')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final match = RegExp(r'^\s*body:\s*').firstMatch(line);
        if (match == null) continue;
        final expr = bodyExpression(lines, i, match.end);
        final head = expr.trimLeft();
        final needsClear = topAligned.any(head.startsWith);
        if (!needsClear) continue;
        if (clears.any(expr.contains)) continue;
        final where = '${file.path.replaceAll('\\', '/')}:${i + 1}';
        offenders.add('$where → ${head.split('\n').first.trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '这些 body 是顶对齐容器，却没预留顶栏浮位，真机上首行会被顶栏/浮层'
          '标题压住。修法：滚动件把自己的 padding 加上 '
          '`top: context.contentTopPadding`（页面用 `context.appBarInset`），'
          '非滚动件用 `AppBarClearance(...)` 包一层，或整体换成 `PageBody`。\n'
          '${offenders.join('\n')}',
    );
  });
}

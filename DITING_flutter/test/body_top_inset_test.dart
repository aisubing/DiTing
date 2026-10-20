import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 守住「`CommonScaffold.body` 必须自己预留顶栏浮位」这条不变量。
///
/// 背景：`CommonScaffold` 用 `extendBodyBehindAppBar` 语义——正文从屏幕 y=0
/// 起排，顶栏浮在正文之上。页面层唯一的「让位」途径是正文自己留出
/// `context.appBarInset`（页面）或 `context.contentTopPadding`（浮层），
/// 或者直接使用 `PageBody` / `AppBarClearance` 这两个已经封好留白的组件。
///
/// 这条规则**没有任何编译期或运行期约束**：把 `ListView` / `Column` /
/// `SingleChildScrollView` 直接塞给 `body:` 完全合法，analyze 不会报，widget
/// 测试也不会失败，只有真机上跑到那一屏才看得见——表现就是这一轮的
/// 「顶部内容高度不对、首行被顶栏/浮层标题压住」。本轮一次性修掉了几十处，
/// 所以用一条源码扫描把它钉住：**新增的任何一处漏留白都会立刻失败**，
/// 而不是等下一个用户截图来报。
///
/// 判定规则（按 body 的首个组件形态）：
/// - `ListView` / `CustomScrollView` / `SingleChildScrollView` / `Form` /
///   `ReorderableListView` / `Column` 这类**顶对齐**容器：必须在 body 表达式
///   里出现 `contentTopPadding` / `appBarInset` / `PageBody` /
///   `AppBarClearance` 之一。
/// - `Center` / `Align` 这类**居中**容器：居中件天然远离顶部，不要求留白。
/// - 其余形态（`PageBody`、`AppBarClearance`、`NullStatusSwitcher`、局部
///   widget 如 `_Body(...)`）不在这里判定：它们要么已经封装好留白，要么
///   留白在别处（例如 `NullStatusSwitcher` 的 `child:` 自己带 padding）。
void main() {
  /// 顶对齐、会把自己第一行画到屏幕最上方的容器。
  const topAligned = <String>[
    'ListView',
    'CustomScrollView',
    'SingleChildScrollView',
    'Form(',
    'ReorderableListView',
  ];

  /// 已经封装好顶栏留白的组件名。
  const clears = <String>[
    'contentTopPadding',
    'appBarInset',
    'PageBody',
    'AppBarClearance',
  ];

  /// 取 `body:` 之后到配对括号结束的表达式文本。
  ///
  /// 逐字符数括号而不是按行截取：`body:` 的表达式经常跨十几行，按行数取会
  /// 把后面的 `padding:`（留白真正写的地方）漏掉，那就成了「留白正确却报错」。
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
          // 表达式真正开始于第一个非空白字符。
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
      // 单行表达式（目录分隔符、`.` 结尾）在行尾收口。
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

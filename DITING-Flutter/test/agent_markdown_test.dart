import 'package:diting/data/agent/markdown/markdown_block.dart';
import 'package:diting/data/agent/markdown/markdown_inline.dart';
import 'package:diting/ui/font.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _colors = MarkdownColors(
  base: Color(0xFF000000),
  primary: Color(0xFF0000FF),
  codeBackground: Color(0xFFEEEEEE),
  error: Color(0xFFFF0000),
  tertiary: Color(0xFF00FF00),
);

void main() {
  group('块级解析', () {
    test('标题、段落与分隔线各归各类', () {
      final blocks = parseMarkdownBlocks('''
# 标题一

普通段落第一行
普通段落第二行

---

## 标题二
''');
      expect(blocks, hasLength(4));
      expect(blocks[0], isA<MarkdownHeading>().having((b) => b.level, 'level', 1));
      expect(
        blocks[1],
        isA<MarkdownParagraph>().having(
          (b) => b.text,
          'text',
          '普通段落第一行\n普通段落第二行',
        ),
      );
      expect(blocks[2], isA<MarkdownDivider>());
      expect(blocks[3], isA<MarkdownHeading>().having((b) => b.level, 'level', 2));
    });

    test('围栏代码块保留语言与内部井号行', () {
      final blocks = parseMarkdownBlocks([
        '```dart',
        '# 不是标题',
        'final a = 1;',
        '```',
      ].join('\n'));
      final code = blocks.single as MarkdownCodeBlock;
      expect(code.language, 'dart');
      expect(code.code, contains('# 不是标题'));
      expect(code.code, contains('final a = 1;'));
    });

    test('列表缩进折成层级，且有序列表保留序号', () {
      final blocks = parseMarkdownBlocks('''
- 一级
  - 二级
    - 三级
1. 第一
2. 第二
''');
      final bullets = blocks.whereType<MarkdownBulletItem>().toList();
      expect(bullets.map((b) => b.indent), [0, 1, 2]);
      final numbered = blocks.whereType<MarkdownNumberedItem>().toList();
      expect(numbered.map((b) => b.number), ['1.', '2.']);
    });

    test('表格只在有分隔行时成立，并去掉首尾空单元', () {
      final blocks = parseMarkdownBlocks('''
| 域名 | 次数 |
| --- | ---: |
| a.test | 3 |
''');
      final table = blocks.single as MarkdownTable;
      expect(table.headers, ['域名', '次数']);
      expect(table.rows, hasLength(1));
      expect(table.rows.single, ['a.test', '3']);
    });

    test('引用合并连续行', () {
      final blocks = parseMarkdownBlocks('''
> 第一行
> 第二行
''');
      expect(blocks.single, isA<MarkdownBlockquote>());
      expect((blocks.single as MarkdownBlockquote).text, contains('第二行'));
    });

    test('空文本与纯空白不产生块', () {
      expect(parseMarkdownBlocks(''), isEmpty);
      expect(parseMarkdownBlocks('   \n\n  '), isEmpty);
    });
  });

  group('内联标注', () {
    List<InlineSpan> spans(String source) =>
        buildMarkdownInlineSpans(source, _colors);

    test('粗体去掉星号并加粗', () {
      final result = spans('这是**重点**结论');
      final bold = result.whereType<TextSpan>().firstWhere(
        (span) => span.text == '重点',
      );
      expect(bold.style?.fontWeight, FontWeight.bold);
      expect(result.map((span) => (span as TextSpan).text).join(), '这是重点结论');
    });

    test('行内码用等宽字体与底色', () {
      final result = spans('执行 `dns.vpn` 检查');
      final code = result.whereType<TextSpan>().firstWhere(
        (span) => span.text?.trim() == 'dns.vpn',
      );
      expect(code.style?.fontFamily, appMonospaceFontFamily);
      expect(code.style?.backgroundColor, _colors.codeBackground);
    });

    test('链接只显示文字，不暴露地址', () {
      final text = spans(
        '见[官方文档](https://example.test/docs)',
      ).map((span) => (span as TextSpan).text).join();
      expect(text, contains('官方文档'));
      expect(text, isNot(contains('https://example.test')));
    });

    test('风险徽标按档位上色', () {
      final high = spans('结论：【高危】立即阻断')
          .whereType<TextSpan>()
          .firstWhere((span) => span.text == '【高危】');
      expect(high.style?.color, _colors.error);
      expect(badgeColorOf('【安全】', _colors), const Color(0xFF2E7D32));
      expect(badgeColorOf('【低风险】', _colors), const Color(0xFFF57F17));
      expect(badgeColorOf('普通文字', _colors), isNull);
    });
  });
}

import 'package:diting/data/agent/agent_api_text_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('剪贴板智能识别', () {
    test('JSON 一次给出地址、密钥与模型', () {
      final result = parseAgentApiText(
        '{"apiKey":"sk-abcdefghijklmnop","baseUrl":"https://api.test/v1","model":"m1"}',
      );
      expect(result.apiKey, 'sk-abcdefghijklmnop');
      expect(result.baseUrl, 'https://api.test/v1');
      expect(result.model, 'm1');
      expect(result.message, contains('JSON'));
    });

    test('地址加密钥的组合被拆开', () {
      final result = parseAgentApiText(
        'https://api.test/v1, sk-abcdefghijklmnopqrst',
      );
      expect(result.baseUrl, 'https://api.test/v1');
      expect(result.apiKey, 'sk-abcdefghijklmnopqrst');
    });

    test('只有地址时只填地址', () {
      final result = parseAgentApiText('https://api.test/v1');
      expect(result.baseUrl, 'https://api.test/v1');
      expect(result.apiKey, isNull);
      expect(result.message, '已填入服务地址');
    });

    test('裸密钥被当成密钥，换行与空格一并清掉', () {
      final result = parseAgentApiText('  sk-abcdefghijklmnopqrst\n ');
      expect(result.apiKey, 'sk-abcdefghijklmnopqrst');
      expect(result.baseUrl, isNull);
    });

    test('空剪贴板给出明确提示，不填任何字段', () {
      final result = parseAgentApiText('   ');
      expect(result.isEmpty, isTrue);
      expect(result.message, '剪贴板为空');
    });

    test('复合解析要求同时出现地址与剩余内容', () {
      expect(parseCompositeUrlAndKey('没有地址'), isNull);
      expect(parseCompositeUrlAndKey('https://api.test/v1'), isNull);
      expect(
        parseCompositeUrlAndKey('https://api.test/v1 sk-key')?.baseUrl,
        'https://api.test/v1',
      );
    });
  });
}

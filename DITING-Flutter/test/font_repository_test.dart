import 'package:diting/data/fonts/font_repository.dart';
import 'package:diting/data/native/platform_bridge.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Imported fonts are the only non-system faces now that the bundle ships none, so the bridge
/// contract and the stored shape both have to survive a round trip.
void main() {
  group('FontPickResult.fromMap', () {
    test('成功时带上路径、名称与大小', () {
      final result = FontPickResult.fromMap({
        'path': '/data/user/0/com.haoze.diting/files/fonts/abc.ttf',
        'name': 'Inter-Regular.ttf',
        'bytes': 20480,
        'cancelled': false,
      });
      expect(result.isOk, isTrue);
      expect(result.path, endsWith('abc.ttf'));
      expect(result.name, 'Inter-Regular.ttf');
      expect(result.bytes, 20480);
    });

    test('取消不算错误', () {
      final result = FontPickResult.fromMap({'cancelled': true});
      expect(result.cancelled, isTrue);
      expect(result.isOk, isTrue);
      expect(result.error, isNull);
    });

    test('原生报错时透传原因且不视为成功', () {
      final result = FontPickResult.fromMap({'error': '只支持 TTF / OTF 字体文件'});
      expect(result.isOk, isFalse);
      expect(result.error, '只支持 TTF / OTF 字体文件');
    });

    test('无通道的降级结果给出可读原因', () {
      const result = FontPickResult.unavailable();
      expect(result.isOk, isFalse);
      expect(result.error, isNotNull);
    });
  });

  group('已导入字体的存取', () {
    late MemoryLegacyPrefsStore store;

    setUp(() => store = MemoryLegacyPrefsStore());

    test('写入后按原样读回，路径与族名都不丢', () {
      final settings = LegacySettings(store);
      settings.setImportedFonts(const [
        ImportedFont(
          family: 'Inter-Regular',
          label: 'Inter-Regular',
          path: '/fonts/abc.ttf',
        ),
      ]);

      final restored = LegacySettings(store).importedFonts;
      expect(restored, hasLength(1));
      expect(restored.single.family, 'Inter-Regular');
      expect(restored.single.path, '/fonts/abc.ttf');
    });

    test('损坏的 JSON 与缺字段的条目都被忽略', () {
      store.putString('dns_vpn_prefs', 'app_imported_fonts', 'not json');
      expect(LegacySettings(store).importedFonts, isEmpty);

      store.putString(
        'dns_vpn_prefs',
        'app_imported_fonts',
        '[{"family":"","path":"/x.ttf"},{"label":"无路径"},'
            '{"family":"Ok","path":"/ok.ttf","label":"Ok"}]',
      );
      final fonts = LegacySettings(store).importedFonts;
      expect(fonts, hasLength(1));
      expect(fonts.single.family, 'Ok');
    });
  });
}

import 'package:diting/app/theme/colors.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards enums reach the screen through `.label`; a bare enum renders `ProviderProtocol.doh`
void main() {
  /// A source identifier like "EnumType.value" must never appear in user text.
  void expectNoRawEnumLiteral(String text, String what) {
    expect(
      RegExp(r'\b[A-Z][A-Za-z]*\.[a-z][A-Za-z]*\b').hasMatch(text),
      isFalse,
      reason: '$what 里出现了枚举源码标识符：$text',
    );
  }

  // 1.4.3's preset providers live under `preset_*` ids; the UI must use that catalog.
  final catalog = defaultProviderCatalog();

  group('providerEndpointOf', () {
    test('拼的是协议 label 而不是枚举名', () {
      for (final provider in catalog) {
        final text = providerEndpointOf(provider.id);
        expectNoRawEnumLiteral(text, '端点文案(${provider.id})');
        expect(
          text,
          startsWith(provider.protocol.label),
          reason: '应以协议 label 开头：$text',
        );
        expect(text, contains(provider.address));
      }
    });

    test('未知 id 回退到第一个服务商而不是抛异常', () {
      expect(providerEndpointOf('nope'), providerEndpointOf(catalog.first.id));
    });
  });

  group('raceProviderSummary', () {
    test('单选/多选都只出 label', () {
      expectNoRawEnumLiteral(raceProviderSummary({catalog.first.id}), '竞速单条');
      expectNoRawEnumLiteral(
        raceProviderSummary({catalog.first.id, catalog[1].id}),
        '竞速多条',
      );
    });

    test('空集合不崩', () {
      expect(raceProviderSummary(const {}), isA<String>());
    });
  });

  group('枚举展示字段', () {
    test('每个枚举的 label/title/summary 都不含源码标识符', () {
      for (final protocol in ProviderProtocol.values) {
        expectNoRawEnumLiteral(
          protocol.label,
          'ProviderProtocol.${protocol.name}',
        );
      }
      for (final kind in RuleKind.values) {
        expectNoRawEnumLiteral(kind.title, 'RuleKind.${kind.name}.title');
        expectNoRawEnumLiteral(kind.summary, 'RuleKind.${kind.name}.summary');
      }
      for (final mode in AppWorkMode.values) {
        expectNoRawEnumLiteral(mode.title, 'AppWorkMode.${mode.name}.title');
        expectNoRawEnumLiteral(mode.badge, 'AppWorkMode.${mode.name}.badge');
        expectNoRawEnumLiteral(
          mode.summary,
          'AppWorkMode.${mode.name}.summary',
        );
      }
      for (final state in PowerState.values) {
        expectNoRawEnumLiteral(state.label, 'PowerState.${state.name}.label');
      }
      for (final resolution in ResolutionMode.values) {
        expectNoRawEnumLiteral(
          resolution.label,
          'ResolutionMode.${resolution.name}',
        );
      }
      for (final layer in HomeLayer.values) {
        expectNoRawEnumLiteral(layer.label, 'HomeLayer.${layer.name}');
      }
      for (final destination in BottomBarDestination.values) {
        expectNoRawEnumLiteral(
          destination.label,
          'BottomBarDestination.${destination.name}',
        );
      }
      for (final palette in AppPalette.values) {
        expectNoRawEnumLiteral(palette.label, 'AppPalette.${palette.name}');
      }
      for (final themeMode in AppThemeMode.values) {
        expectNoRawEnumLiteral(
          themeMode.label,
          'AppThemeMode.${themeMode.name}',
        );
      }
      for (final source in RuleSource.values) {
        expectNoRawEnumLiteral(source.label, 'RuleSource.${source.name}');
      }
      for (final serverStatus in ServerStatus.values) {
        expectNoRawEnumLiteral(
          serverStatus.label,
          'ServerStatus.${serverStatus.name}',
        );
      }
    });
  });
}

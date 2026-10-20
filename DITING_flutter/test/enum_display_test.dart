import 'package:diting/app/theme/colors.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// 守住「枚举上屏必须取 `.label`」这条。
///
/// 背景：`ProviderProtocol` 是个裸枚举，插值进文案会渲染成
/// `ProviderProtocol.doh · 1.1.1.1`——analyze 和路由冒烟都拦不住，只有真跑
/// 到那一屏才看得见。两个页面各自踩过一次，所以这里对**所有**会产出用户可见
/// 文案的枚举做一次全量扫描。
void main() {
  /// 源码标识符「EnumType.value」不该出现在任何展示文案里。
  void expectNoRawEnumLiteral(String text, String what) {
    expect(
      RegExp(r'\b[A-Z][A-Za-z]*\.[a-z][A-Za-z]*\b').hasMatch(text),
      isFalse,
      reason: '$what 里出现了枚举源码标识符：$text',
    );
  }

  // 1.4.3 的预设服务商以 `preset_*` id 存在，展示层必须走同一份目录。
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
        expectNoRawEnumLiteral(protocol.label, 'ProviderProtocol.${protocol.name}');
      }
      for (final kind in RuleKind.values) {
        expectNoRawEnumLiteral(kind.title, 'RuleKind.${kind.name}.title');
        expectNoRawEnumLiteral(kind.summary, 'RuleKind.${kind.name}.summary');
      }
      for (final action in LogAction.values) {
        expectNoRawEnumLiteral(action.label, 'LogAction.${action.name}');
      }
      for (final mode in AppWorkMode.values) {
        expectNoRawEnumLiteral(mode.title, 'AppWorkMode.${mode.name}.title');
        expectNoRawEnumLiteral(mode.badge, 'AppWorkMode.${mode.name}.badge');
        expectNoRawEnumLiteral(mode.summary, 'AppWorkMode.${mode.name}.summary');
      }
      for (final state in PowerState.values) {
        expectNoRawEnumLiteral(state.label, 'PowerState.${state.name}.label');
      }
      for (final resolution in ResolutionMode.values) {
        expectNoRawEnumLiteral(resolution.label, 'ResolutionMode.${resolution.name}');
      }
      for (final layer in HomeLayer.values) {
        expectNoRawEnumLiteral(layer.label, 'HomeLayer.${layer.name}');
      }
      for (final destination in BottomBarDestination.values) {
        expectNoRawEnumLiteral(destination.label, 'BottomBarDestination.${destination.name}');
      }
      for (final palette in AppPalette.values) {
        expectNoRawEnumLiteral(palette.label, 'AppPalette.${palette.name}');
      }
      for (final themeMode in AppThemeMode.values) {
        expectNoRawEnumLiteral(themeMode.label, 'AppThemeMode.${themeMode.name}');
      }
      for (final importType in SubscriptionImportType.values) {
        expectNoRawEnumLiteral(importType.label, 'SubscriptionImportType.${importType.name}');
      }
      for (final source in RuleSource.values) {
        expectNoRawEnumLiteral(source.label, 'RuleSource.${source.name}');
      }
      for (final serverStatus in ServerStatus.values) {
        expectNoRawEnumLiteral(serverStatus.label, 'ServerStatus.${serverStatus.name}');
      }
    });
  });
}

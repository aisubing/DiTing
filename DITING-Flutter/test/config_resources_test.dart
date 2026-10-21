import 'dart:convert';

import 'package:diting/data/mock_config_resources.dart';
import 'package:diting/data/prefs/config_resource_store.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/config_providers_resources.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the persistence of the three config-resource tables.
///
/// They used to live only in memory: add an icon set, toggle on-demand, and the
/// next process start silently restored the demo values. Nothing said "this is
/// not saved", so the setting looked applied.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryLegacyPrefsStore store;

  setUp(() => store = MemoryLegacyPrefsStore());

  /// A fresh container reading the same store — i.e. what a cold start does.
  ProviderContainer container() {
    final instance = ProviderContainer(
      overrides: [legacyPrefsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(instance.dispose);
    return instance;
  }

  group('空 store 上回落到初始值', () {
    test('三组都是演示初始值', () {
      final state = container().read(configResourcesProvider);
      expect(state.iconSets, hasLength(mockIconSets.length));
      expect(state.userAgents, hasLength(mockUserAgents.length));
      expect(state.ssidRules, hasLength(mockSsidRules.length));
      expect(state.selectedUserAgent, isNull);
      expect(state.onDemand, isFalse);
    });
  });

  group('写入后能在新容器里读回', () {
    test('图标集', () {
      container().read(configResourcesProvider.notifier).putIconSet(
        null,
        const MockIconSet(
          name: '我的图标',
          url: 'https://x.test/i.json',
          icons: ['a', 'b'],
          fromUrl: false,
        ),
      );

      final reopened = container().read(configResourcesProvider);
      final added = reopened.iconSets.firstWhere((s) => s.name == '我的图标');
      expect(added.url, 'https://x.test/i.json');
      expect(added.icons, ['a', 'b']);
      expect(added.fromUrl, isFalse);
    });

    test('删除图标集后不会复活', () {
      final first = container();
      first.read(configResourcesProvider.notifier).removeIconSet('地区旗帜');
      expect(
        first.read(configResourcesProvider).iconSets.map((s) => s.name),
        isNot(contains('地区旗帜')),
      );

      // 冷启动：删掉的那条不能又冒出来。
      final reopened = container().read(configResourcesProvider);
      expect(reopened.iconSets.map((s) => s.name), isNot(contains('地区旗帜')));
      expect(
        reopened.iconSets,
        hasLength(mockIconSets.length - 1),
      );
    });

    test('User-Agent 与选中项', () {
      final notifier = container().read(configResourcesProvider.notifier);
      expect(notifier.addUserAgent('MyAgent/1.0'), isTrue);
      notifier.selectUserAgent('MyAgent/1.0');

      final reopened = container().read(configResourcesProvider);
      expect(reopened.userAgents.map((a) => a.value), contains('MyAgent/1.0'));
      expect(reopened.selectedUserAgent, 'MyAgent/1.0');
    });

    test('取消选中（不覆写）会被记住', () {
      final notifier = container().read(configResourcesProvider.notifier);
      notifier.selectUserAgent('curl/8.7.1');
      notifier.selectUserAgent(null);

      expect(container().read(configResourcesProvider).selectedUserAgent, isNull);
    });

    test('删掉选中的 UA 时选中态一起清掉', () {
      final notifier = container().read(configResourcesProvider.notifier);
      notifier.addUserAgent('Temp/1.0');
      notifier.selectUserAgent('Temp/1.0');
      notifier.removeUserAgent('Temp/1.0');

      final reopened = container().read(configResourcesProvider);
      expect(reopened.userAgents.map((a) => a.value), isNot(contains('Temp/1.0')));
      // 留下一个指向已删除值的选中项会让界面显示「已选中」但实际没有。
      expect(reopened.selectedUserAgent, isNull);
    });

    test('改 UA 时选中项跟着改', () {
      final notifier = container().read(configResourcesProvider.notifier);
      notifier.addUserAgent('Old/1.0');
      notifier.selectUserAgent('Old/1.0');
      notifier.updateUserAgent('Old/1.0', 'New/1.0');

      final reopened = container().read(configResourcesProvider);
      expect(reopened.userAgents.map((a) => a.value), contains('New/1.0'));
      expect(reopened.selectedUserAgent, 'New/1.0');
    });

    test('SSID 规则增删改与开关', () {
      final notifier = container().read(configResourcesProvider.notifier);
      expect(
        notifier.putSsid(
          null,
          const MockSsidRule(ssid: 'Cafe', delayMs: 1200, cellular: false),
        ),
        isTrue,
      );
      notifier.toggleSsid('Cafe', wifi: false);

      final reopened = container().read(configResourcesProvider);
      final rule = reopened.ssidRules.firstWhere((r) => r.ssid == 'Cafe');
      expect(rule.delayMs, 1200);
      expect(rule.wifi, isFalse);
      expect(rule.cellular, isFalse);
    });

    test('按需连接开关', () {
      container().read(configResourcesProvider.notifier).setOnDemand(true);
      expect(container().read(configResourcesProvider).onDemand, isTrue);
    });

    test('删光 UA 列表后不会回落到演示值', () {
      final notifier = container().read(configResourcesProvider.notifier);
      // 内置那条不许删，其余都能删。
      for (final agent in mockUserAgents) {
        if (!agent.isDefault) notifier.removeUserAgent(agent.value);
      }
      // 再加一条再删，验证「空列表」本身能被持久化。
      notifier.addUserAgent('Only/1.0');
      notifier.removeUserAgent('Only/1.0');

      final reopened = container().read(configResourcesProvider);
      // 空数组是合法结果：用户删光了，不该又冒出四条默认值。
      expect(reopened.userAgents, hasLength(1));
      expect(reopened.userAgents.single.isDefault, isTrue);
    });
  });

  group('损坏数据', () {
    test('坏 JSON 回落到初始值而不是崩溃', () {
      store.putString(
        ConfigResourceStore.container,
        'icon_sets_json',
        '{not json',
      );
      final state = container().read(configResourcesProvider);
      expect(state.iconSets, hasLength(mockIconSets.length));
    });

    test('一组坏掉不牵连另外两组', () {
      store.putString(
        ConfigResourceStore.container,
        'user_agents_json',
        'oops',
      );
      store.putString(
        ConfigResourceStore.container,
        'ssid_rules_json',
        jsonEncode([
          {'ssid': 'Kept', 'cellular': true, 'wifi': true, 'delayMs': 0},
        ]),
      );
      final state = container().read(configResourcesProvider);
      // 坏的 UA 组用初始值，好的 SSID 组照常读回。
      expect(state.userAgents, hasLength(mockUserAgents.length));
      expect(state.ssidRules, hasLength(1));
      expect(state.ssidRules.single.ssid, 'Kept');
    });

    test('单条坏记录只丢那一条', () {
      store.putString(
        ConfigResourceStore.container,
        'ssid_rules_json',
        jsonEncode([
          {'ssid': ''},
          {'ssid': 'Good'},
          {'nope': 1},
        ]),
      );
      final state = container().read(configResourcesProvider);
      expect(state.ssidRules.map((r) => r.ssid), ['Good']);
    });
  });
}

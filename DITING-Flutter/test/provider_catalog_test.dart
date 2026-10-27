import 'dart:convert';

import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/block_response_settings.dart';
import 'package:diting/data/vpn/cache_presets.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:diting/data/vpn/provider_store.dart';
import 'package:diting/state/appearance_providers.dart';
import 'package:diting/state/provider_catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks that the UI writes the fixed prefs keys the engine reads (providers, cache, app rules)
void main() {
  ProviderContainer container({Map<String, Object?> dns = const {}}) {
    final store = MemoryLegacyPrefsStore({
      'dns_vpn_prefs': dns,
      'diting_express_prefs': const {},
      'diting_settings': const {'app_work_mode': 'normal'},
    });
    final c = ProviderContainer(
      overrides: [legacyPrefsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('自定义服务商落盘', () {
    test('新增 DoH 写 user_providers_json 并回读', () {
      final settings = LegacySettings(MemoryLegacyPrefsStore());
      addUserProvider(
        settings,
        name: ' 自建 DoH ',
        protocol: DnsProtocol.doh,
        address: 'https://dns.example.com/query',
        id: 'user_1',
      );

      final records = readUserProviders(settings);
      expect(records, hasLength(1));
      expect(records.single.name, '自建 DoH');
      expect(records.single.url, 'https://dns.example.com/query');
      expect(records.single.address, 'https://dns.example.com/query');

      final json = jsonDecode(settings.userProvidersJson!) as List;
      expect((json.single as Map)['protocol'], 'DOH');
    });

    test('DoT 地址按 host:port 拆分，缺省端口 853', () {
      final settings = LegacySettings(MemoryLegacyPrefsStore());
      addUserProvider(
        settings,
        name: '自建 DoT',
        protocol: DnsProtocol.dot,
        address: 'dot.example.com:8853',
        id: 'user_2',
      );
      final record = readUserProviders(settings).single;
      expect(record.host, 'dot.example.com');
      expect(record.port, 8853);
      expect(record.address, 'dot.example.com:8853');
    });

    test('非法条目在读取时被丢弃，与旧版校验一致', () {
      final settings = LegacySettings(
        MemoryLegacyPrefsStore({
          'dns_vpn_prefs': {
            'user_providers_json': jsonEncode([
              {
                'id': 'a',
                'name': '无 https',
                'protocol': 'DOH',
                'url': 'http://x',
              },
              {
                'id': 'b',
                'name': '端口越界',
                'protocol': 'DOT',
                'host': 'x',
                'port': 70000,
              },
              {'id': 'c', 'name': '未知协议', 'protocol': 'QUIC', 'host': 'x'},
              {
                'id': 'd',
                'name': '可用',
                'protocol': 'DOT',
                'host': 'd.example',
                'port': 853,
              },
            ]),
          },
        }),
      );
      expect(readUserProviders(settings).map((item) => item.id), ['d']);
    });

    test('编辑保留 id，删除会清掉选中项与三种模式引用', () {
      final seed = jsonEncode([
        {
          'id': 'user_1',
          'name': '旧名',
          'protocol': 'DOT',
          'host': 'old',
          'port': 853,
        },
      ]);
      final settings = LegacySettings(
        MemoryLegacyPrefsStore({
          'dns_vpn_prefs': {
            'user_providers_json': seed,
            'selected_provider_id': 'user_1',
            'smart_prediction_provider_ids': '["user_1"]',
            'parallel_race_provider_ids': '["user_1","preset_alidns_dns"]',
            'primary_backup_provider_ids': '["preset_alidns_dns","user_1"]',
          },
        }),
      );

      updateUserProvider(
        settings,
        id: 'user_1',
        name: '新名',
        protocol: DnsProtocol.dot,
        address: 'new.example:853',
      );
      expect(readUserProviders(settings).single.name, '新名');
      expect(readUserProviders(settings).single.host, 'new.example');

      deleteUserProvider(settings, 'user_1');
      expect(readUserProviders(settings), isEmpty);
      expect(settings.selectedProviderId, 'preset_alidns_dns');
      expect(settings.smartPredictionProviderIds, isEmpty);
      expect(settings.parallelRaceProviderIds, ['preset_alidns_dns']);
      expect(settings.primaryBackupProviderIds, ['preset_alidns_dns']);
    });

    test('目录包含 18 个预设且延迟缺失时标为未测速', () {
      final c = container();
      final catalog = c.read(dnsProviderCatalogProvider);
      expect(catalog, hasLength(18));
      expect(catalog.every((provider) => provider.isPreset), isTrue);
      expect(providerLatencyLabel(catalog.first), '未测速');
    });
  });

  group('缓存预设', () {
    test('三档预设各自写满 9 个 v2 键，并可从引擎侧读回', () {
      final settings = LegacySettings(MemoryLegacyPrefsStore());
      DnsCachePreset.highHitRate.applyTo(settings, enabled: true);

      expect(settings.cachePresetRaw, 'high_hit_rate');
      expect(settings.cacheEnabled, isTrue);
      expect(settings.cacheModeRaw, 'limit_max_ttl');
      expect(settings.cacheMaxTtlSeconds, 21600);
      expect(settings.cacheMinTtlEnabled, isTrue);
      expect(settings.cacheMinTtlSeconds, 120);
      expect(settings.cacheStaleFallbackEnabled, isTrue);
      expect(settings.cacheStaleFallbackSeconds, 900);

      final config = buildDnsConfig(settings);
      final cache = config.toJson(settings)['cache'] as Map;
      expect(cache['maxTtlSeconds'], 21600);
      expect(cache['minTtlSeconds'], 120);
    });

    test('关闭缓存只改开关，不丢预设', () {
      final settings = LegacySettings(MemoryLegacyPrefsStore());
      DnsCachePreset.balanced.applyTo(settings, enabled: false);
      expect(settings.cacheEnabled, isFalse);
      expect(settings.cachePresetRaw, 'balanced');
      expect(cacheSummaryOf(settings), '已关闭 · 每次解析都会请求上游');
    });

    test('缺少 preset 键时按策略推断，旧安装不会显示空档位', () {
      final conservative = LegacySettings(
        MemoryLegacyPrefsStore({
          'dns_vpn_prefs': {
            'dns_cache_mode_v2': 'follow_dns_ttl',
            'dns_cache_min_ttl_enabled_v2': false,
            'dns_cache_stale_fallback_enabled_v2': false,
          },
        }),
      );
      expect(DnsCachePreset.current(conservative), DnsCachePreset.conservative);

      final legacyBalanced = LegacySettings(
        MemoryLegacyPrefsStore({
          'dns_vpn_prefs': {
            'dns_cache_mode_v2': 'limit_max_ttl',
            'dns_cache_max_ttl_seconds_v2': 1800,
            'dns_cache_min_ttl_enabled_v2': true,
            'dns_cache_min_ttl_seconds_v2': 30,
            'dns_cache_stale_fallback_enabled_v2': false,
          },
        }),
      );
      expect(DnsCachePreset.current(legacyBalanced), DnsCachePreset.balanced);
    });

    test('非法 preset 值回落到策略推断', () {
      final settings = LegacySettings(
        MemoryLegacyPrefsStore({
          'dns_vpn_prefs': {
            'dns_cache_preset_v3': 'bogus',
            'dns_cache_mode_v2': 'follow_dns_ttl',
          },
        }),
      );
      expect(DnsCachePreset.current(settings), DnsCachePreset.conservative);
    });
  });

  group('拦截响应', () {
    test('默认关闭动态策略，固定模式为 NXDOMAIN', () {
      final settings = LegacySettings(MemoryLegacyPrefsStore());
      expect(settings.blockResponseModeRaw, 'nxdomain');
      expect(DynamicBlockPolicy.read(settings).enabled, isFalse);
      expect(DynamicBlockPolicy.read(settings).requestThreshold, 5);
      expect(DynamicBlockPolicy.read(settings).windowSeconds, 60);
      expect(DynamicBlockPolicy.read(settings).nxDomainDurationSeconds, 300);
    });

    test('越界参数在落盘时被夹到旧版区间', () {
      final settings = LegacySettings(MemoryLegacyPrefsStore());
      DynamicBlockPolicy.defaults
          .copyWith(
            enabled: true,
            requestThreshold: 500,
            windowSeconds: 1,
            nxDomainDurationSeconds: 99999,
          )
          .write(settings);

      expect(settings.dynamicBlockEnabled, isTrue);
      expect(settings.dynamicBlockRequestThreshold, 100);
      expect(settings.dynamicBlockWindowSeconds, 10);
      expect(settings.dynamicBlockNxDomainDurationSeconds, 3600);

      final json =
          buildDnsConfig(settings).toJson(settings)['dynamicResponse'] as Map;
      expect(json['requestThreshold'], 100);
      expect(json['windowSeconds'], 10);
      expect(json['nxDomainDurationSeconds'], 3600);
    });

    test('未知存储值回落到 NXDOMAIN', () {
      expect(
        BlockResponseMode.fromStorage('bogus'),
        BlockResponseMode.nxdomain,
      );
      expect(
        BlockResponseMode.fromStorage('zero_address'),
        BlockResponseMode.zeroAddress,
      );
    });
  });

  group('服务显示过滤', () {
    test('协议关闭后只保留显式开启与当前选中项', () {
      final c = container(
        dns: {
          'home_visible_protocols': '["DOH"]',
          'home_hidden_provider_ids': '[]',
          'home_visible_provider_ids': '["preset_alidns_dot"]',
          'selected_provider_id': 'preset_google_dns',
        },
      );
      final visible = c.read(visibleProvidersProvider);
      final ids = visible.map((provider) => provider.id).toSet();
      expect(ids, contains('preset_alidns_dot'));
      // The current selection is always kept, so the user can see it.
      expect(ids, contains('preset_google_dns'));
      expect(ids, isNot(contains('preset_cloudflare_dns')));
    });

    test('协议开启时按隐藏列表剔除单项', () {
      final c = container(
        dns: {
          'home_visible_protocols': '["DNS","DOH","DOT"]',
          'home_hidden_provider_ids': '["preset_cloudflare_dns"]',
        },
      );
      final ids = c
          .read(visibleProvidersProvider)
          .map((provider) => provider.id)
          .toSet();
      expect(ids, isNot(contains('preset_cloudflare_dns')));
      expect(ids, contains('preset_alidns_dns'));
    });
  });

  group('竞速列表与单选', () {
    test('单选选择写入 selected_provider_id', () {
      final c = container();
      c.read(selectedProviderProvider.notifier).select('preset_cloudflare_doh');
      expect(
        c.read(legacySettingsProvider).selectedProviderId,
        'preset_cloudflare_doh',
      );
      expect(c.read(selectedProviderProvider), 'preset_cloudflare_doh');
    });

    test('未知 id 不会被写入，避免引擎解析不到', () {
      final c = container();
      final before = c.read(selectedProviderProvider);
      c.read(selectedProviderProvider.notifier).select('nope');
      expect(c.read(selectedProviderProvider), before);
      expect(c.read(legacySettingsProvider).selectedProviderId, isNot('nope'));
    });

    test('单选模式下竞速列表最少保留两项', () {
      final c = container();
      final notifier = c.read(raceProvidersProvider.notifier);
      expect(c.read(raceProvidersProvider), hasLength(2));
      expect(notifier.toggle('preset_alidns_dns'), isFalse);
      expect(c.read(raceProvidersProvider), hasLength(2));
    });

    test('主备模式的顺序在落盘后保持不变', () {
      final c = container(dns: {'dns_resolution_mode': 'primary_backup'});
      final notifier = c.read(raceProvidersProvider.notifier);
      notifier.reorder([
        'preset_dnspod_dns',
        'preset_alidns_dns',
        'preset_cloudflare_doh',
      ]);
      expect(c.read(legacySettingsProvider).primaryBackupProviderIds, [
        'preset_dnspod_dns',
        'preset_alidns_dns',
        'preset_cloudflare_doh',
      ]);
      expect(c.read(raceProvidersProvider), hasLength(3));
    });

    test('切换解析模式读取各自的列表键', () {
      final c = container(
        dns: {
          'smart_prediction_provider_ids': '["preset_google_doh"]',
          'parallel_race_provider_ids':
              '["preset_alidns_dns","preset_dnspod_dns"]',
        },
      );
      c.read(resolutionModeProvider.notifier).select(ResolutionMode.smart);
      expect(c.read(raceProvidersProvider), {'preset_google_doh'});
    });
  });

  group('prefs 版本号', () {
    test('写操作 bump 后可重建 settings 视图', () {
      final c = container();
      final revision = c.read(legacySettingsRevisionProvider);
      c.read(legacySettingsProvider).setDomainRulesEnabled(false);
      expect(c.read(legacySettingsProvider).domainRulesEnabled, isFalse);
      c.read(legacySettingsRevisionProvider.notifier).bump();
      expect(c.read(legacySettingsRevisionProvider), revision + 1);
      expect(c.read(legacySettingsProvider).domainRulesEnabled, isFalse);
    });
  });
}

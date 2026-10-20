import 'dart:convert';

import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/db/rule_providers.dart';
import 'package:diting/data/server/dns_server_bridge.dart';
import 'package:diting/data/server/dns_server_config.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_dns_server_controller.dart';

LegacySettings serverSettings(Map<String, Object?> values) => LegacySettings(
  MemoryLegacyPrefsStore({
    'diting_settings': {'app_work_mode': 'dns'},
    'diting_dns_mode_prefs': values,
  }),
);

void main() {
  group('服务器模式配置', () {
    test('默认值：1053 端口、阿里云 PLAIN、均衡缓存、无 bootstrap', () {
      final config = buildServerDnsConfig(serverSettings({}));
      final json = config.toJson();
      expect(json['mode'], 'single');
      expect(json['blockResponse'], 'NXDOMAIN');
      expect(json['bootstrap'], {'enabled': false, 'ips': <Object?>[]});
      expect((json['providers'] as List).single, {
        'id': 'preset_alidns_dns',
        'protocol': 'PLAIN',
        'server': '223.5.5.5:53',
        'url': '',
      });
      final cache = json['cache'] as Map;
      expect(cache['enabled'], true);
      expect(cache['mode'], 'limit_max_ttl');
      expect(cache['minTtlEnabled'], true);
      expect(cache['staleFallbackEnabled'], true);
      expect(cache['negativeTtlSeconds'], 30);
    });

    test('保守与高命中率预设逐字对齐', () {
      final conservative = buildServerDnsConfig(
        serverSettings({'cache_preset': 'conservative'}),
      ).toJson()['cache'] as Map;
      expect(conservative['mode'], 'follow_dns_ttl');
      expect(conservative['minTtlEnabled'], false);
      expect(conservative['negativeTtlSeconds'], 15);

      final high = buildServerDnsConfig(
        serverSettings({'cache_preset': 'high_hit_rate'}),
      ).toJson()['cache'] as Map;
      expect(high['maxTtlSeconds'], 21600);
      expect(high['minTtlSeconds'], 120);
      expect(high['staleFallbackSeconds'], 900);

      final unknown = buildServerDnsConfig(
        serverSettings({'cache_preset': 'nope'}),
      ).toJson()['cache'] as Map;
      expect(unknown['maxTtlSeconds'], 3600);
    });

    test('自定义上游解析、DOH 无 server、端口与协议校验', () {
      final settings = serverSettings({
        'selected_upstream_id': 'custom_doh',
        'custom_upstreams': jsonEncode([
          {
            'id': 'custom_doh',
            'name': '自定义 DoH',
            'address': 'https://dns.example/dns-query',
            'port': 443,
            'protocol': 'DOH',
          },
          {
            'id': 'custom_bad',
            'name': '坏地址',
            'address': 'http://x',
            'port': 443,
            'protocol': 'DOH',
          },
          {
            'id': 'custom_udp',
            'name': '自定义 UDP',
            'address': '9.9.9.9',
            'port': 5353,
            'protocol': 'DNS',
          },
        ]),
      });
      final config = buildServerDnsConfig(settings);
      expect(config.upstream.id, 'custom_doh');
      expect(
        (config.toJson()['providers'] as List).single,
        {
          'id': 'custom_doh',
          'protocol': 'DOH',
          'server': '',
          'url': 'https://dns.example/dns-query',
        },
      );
      final upstreams = serverUpstreams(settings);
      expect(upstreams.map((u) => u.id), contains('custom_udp'));
      expect(upstreams.map((u) => u.id), isNot(contains('custom_bad')));
    });

    test('DoT 自定义上游 hostPort 不带自造括号', () {
      final settings = serverSettings({
        'selected_upstream_id': 'custom_dot',
        'custom_upstreams': jsonEncode([
          {
            'id': 'custom_dot',
            'name': '自定义 DoT',
            'address': 'dot.example',
            'port': 853,
            'protocol': 'DOT',
          },
        ]),
      });
      final provider =
          (buildServerDnsConfig(settings).toJson()['providers'] as List).single
              as Map;
      expect(provider['server'], 'dot.example:853');
      expect(provider['protocol'], 'DOT');
    });

    test('阻断响应与动态升级键映射', () {
      final settings = serverSettings({
        'block_response_mode': 'zero_address',
        'block_response_dynamic_enabled': true,
        'block_response_dynamic_threshold': 999,
        'block_response_dynamic_window_seconds': 1,
        'block_response_dynamic_nxdomain_duration_seconds': 10,
      });
      final json = buildServerDnsConfig(settings).toJson();
      expect(json['blockResponse'], 'CUSTOM_IP');
      expect(json['dynamicResponse'], {
        'enabled': true,
        'requestThreshold': 100,
        'windowSeconds': 10,
        'nxDomainDurationSeconds': 60,
      });
    });
  });

  group('服务器状态机', () {
    ProviderContainer container(
      FakeDnsServerController controller, {
      Map<String, Object?> prefs = const {},
    }) {
      final c = ProviderContainer(
        overrides: [
          legacyPrefsStoreProvider.overrideWithValue(
            MemoryLegacyPrefsStore({
              'diting_settings': {'app_work_mode': 'dns'},
              'diting_dns_mode_prefs': prefs,
            }),
          ),
          dnsServerControllerProvider.overrideWithValue(controller),
          serverRuleRepositoryProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('启动使用旧版配置并写回 service_active', () async {
      final fake = FakeDnsServerController();
      final c = container(fake, prefs: {'local_listen_port': 2053});
      expect(c.read(serverStatusProvider), ServerStatus.stopped);

      await c.read(serverStatusProvider.notifier).toggle();
      expect(c.read(serverStatusProvider), ServerStatus.running);
      expect(fake.startCalls, 1);
      final request = fake.lastRequest!;
      expect(request.port, 2053);
      expect(request.dnsConfig, contains('"mode":"single"'));
      expect(request.dnsConfig, contains('"id":"preset_alidns_dns"'));
      expect(request.dnsConfig, contains('"bootstrap":{"enabled":false'));
      expect(request.adBlockEnabled, false);
      expect(
        c.read(legacySettingsProvider).serverServiceActive,
        true,
      );
    });

    test('非服务器模式拒绝启动', () async {
      final fake = FakeDnsServerController();
      final c = ProviderContainer(
        overrides: [
          legacyPrefsStoreProvider.overrideWithValue(MemoryLegacyPrefsStore()),
          dnsServerControllerProvider.overrideWithValue(fake),
          serverRuleRepositoryProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(c.dispose);
      await c.read(serverStatusProvider.notifier).toggle();
      expect(c.read(serverStatusProvider), ServerStatus.error);
      expect(fake.startCalls, 0);
    });

    test('残留 service_active 以原生状态纠正', () async {
      final fake = FakeDnsServerController();
      final c = container(fake, prefs: {'service_active': true});
      expect(c.read(serverStatusProvider), ServerStatus.starting);
      await c.read(serverStatusProvider.notifier).syncStatus();
      expect(c.read(serverStatusProvider), ServerStatus.stopped);
      expect(c.read(legacySettingsProvider).serverServiceActive, false);
    });

    test('停止清标志', () async {
      final fake = FakeDnsServerController(
        statusValue: const DnsServerStatus(
          running: true,
          persisted: true,
          port: 1053,
        ),
      );
      final c = container(fake, prefs: {'service_active': true});
      await c.read(serverStatusProvider.notifier).syncStatus();
      expect(c.read(serverStatusProvider), ServerStatus.running);

      await c.read(serverStatusProvider.notifier).toggle();
      expect(fake.stopCalls, 1);
      expect(c.read(serverStatusProvider), ServerStatus.stopped);
      expect(c.read(legacySettingsProvider).serverServiceActive, false);
    });
  });
}

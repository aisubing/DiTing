import 'dart:convert';

import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:diting/data/vpn/dns_config_builder.dart';
import 'package:flutter_test/flutter_test.dart';

LegacySettings settingsWith(Map<String, Object?> values) =>
    LegacySettings(MemoryLegacyPrefsStore({'dns_vpn_prefs': values}));

void main() {
  group('DNS 配置', () {
    test('默认单一模式选中阿里云 PLAIN，服务端带端口', () {
      final settings = settingsWith({});
      final config = buildDnsConfig(settings);
      final json = config.toJson(settings);

      expect(json['mode'], 'single');
      expect(json['blockResponse'], 'NXDOMAIN');
      final providers = json['providers'] as List;
      expect(providers, hasLength(1));
      expect(providers.single, {
        'id': 'preset_alidns_dns',
        'protocol': 'PLAIN',
        'server': '223.5.5.5:53',
        'url': '',
      });
    });

    test('DoH 服务商 server 为空，url 原样保留', () {
      final settings = settingsWith({
        'selected_provider_id': 'preset_cloudflare_doh',
      });
      final provider =
          (buildDnsConfig(settings).toJson(settings)['providers'] as List).single
              as Map;
      expect(provider['protocol'], 'DOH');
      expect(provider['server'], '');
      expect(provider['url'], 'https://cloudflare-dns.com/dns-query');
    });

    test('竞速模式使用竞速列表；不足两个时回落到选中项', () {
      final two = settingsWith({'dns_resolution_mode': 'parallel_race'});
      expect(buildDnsConfig(two).providers.map((p) => p.id), [
        'preset_alidns_dns',
        'preset_dnspod_dns',
      ]);

      final one = settingsWith({
        'dns_resolution_mode': 'parallel_race',
        'parallel_race_provider_ids': jsonEncode(['preset_google_dns']),
      });
      expect(buildDnsConfig(one).providers.single.id, 'preset_alidns_dns');
      expect(buildDnsConfig(one).mode, 'parallel_race');
    });

    test('主备模式保持配置顺序', () {
      final settings = settingsWith({
        'dns_resolution_mode': 'primary_backup',
        'primary_backup_provider_ids': jsonEncode([
          'preset_google_dns',
          'preset_cloudflare_dns',
        ]),
      });
      expect(buildDnsConfig(settings).providers.map((p) => p.id), [
        'preset_google_dns',
        'preset_cloudflare_dns',
      ]);
    });

    test('自定义服务商非法项被丢弃', () {
      final settings = settingsWith({
        'user_providers_json': jsonEncode([
          {
            'id': 'u1',
            'name': '自定义 DoH',
            'protocol': 'DOH',
            'url': 'https://dns.example/dns-query',
          },
          {'id': 'u2', 'name': '坏 DoH', 'protocol': 'DOH', 'url': 'http://x'},
          {'id': 'u3', 'name': '坏端口', 'protocol': 'DOT', 'host': 'x.y', 'port': 0},
          {'id': 'u4', 'name': '未知协议', 'protocol': 'DOQ', 'url': 'https://x'},
        ]),
        'selected_provider_id': 'u1',
      });
      final providers = buildDnsConfig(settings).providers;
      expect(providers.map((p) => p.id), ['u1']);
      expect(providers.single.url, 'https://dns.example/dns-query');
    });

    test('阻断响应与缓存默认值逐字对齐 1.4.3', () {
      final settings = settingsWith({'block_response_mode': 'zero_address'});
      final json = buildDnsConfig(settings).toJson(settings);
      expect(json['blockResponse'], 'CUSTOM_IP');
      expect(json['cache'], {
        'enabled': true,
        'mode': 'limit_max_ttl',
        'maxTtlSeconds': 3600,
        'fixedTtlSeconds': 3600,
        'minTtlEnabled': false,
        'minTtlSeconds': 60,
        'staleFallbackEnabled': false,
        'staleFallbackSeconds': 300,
        'negativeTtlEnabled': true,
        'negativeTtlSeconds': 30,
      });
    });

    test('bootstrap 只带选中的预置项', () {
      final settings = settingsWith({});
      final bootstrap =
          buildDnsConfig(settings).toJson(settings)['bootstrap'] as Map;
      expect(bootstrap['enabled'], true);
      expect(
        (bootstrap['ips'] as List).map((e) => (e as Map)['ip']),
        ['223.5.5.5', '119.29.29.29', '180.184.1.1'],
      );
    });

    test('关闭 bootstrap 后 ips 为空', () {
      final settings = settingsWith({'bootstrap_enabled': false});
      final bootstrap =
          buildDnsConfig(settings).toJson(settings)['bootstrap'] as Map;
      expect(bootstrap['enabled'], false);
      expect(bootstrap['ips'], isEmpty);
    });
  });
}

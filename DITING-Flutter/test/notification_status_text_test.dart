// The notification body must match the legacy wording: mode + provider summary, not a bare
// running/stopped status. The services cannot see the provider catalog, so these strings are the
// only source of the default text.

import 'package:diting/data/notifications/notification_status_text.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LegacySettings settings({
    Map<String, Object?> dns = const {},
    Map<String, Object?> server = const {},
  }) => LegacySettings(
    MemoryLegacyPrefsStore({
      'dns_vpn_prefs': dns,
      'diting_dns_mode_prefs': server,
    }),
  );

  group('运行中的通知文案', () {
    test('单一服务显示已连接与服务商名', () {
      expect(
        defaultRunningNotificationText(settings(), express: false),
        '已连接 · 阿里云',
      );
    });

    test('竞速模式显示解析模式与服务商数量', () {
      final text = defaultRunningNotificationText(
        settings(
          dns: const {
            'dns_resolution_mode': 'parallel_race',
            'parallel_race_provider_ids':
                '["preset_alidns_dns","preset_dnspod_dns"]',
          },
        ),
        express: false,
      );
      expect(text, '已连接 · [最快响应] 2 个服务商');
    });

    test('极速模式换前缀，保持旧版格式', () {
      final text = defaultRunningNotificationText(
        settings(
          dns: const {
            'dns_resolution_mode': 'smart_prediction',
            'smart_prediction_provider_ids':
                '["preset_alidns_doh","preset_dnspod_doh"]',
          },
        ),
        express: true,
      );
      expect(text, '极速模式运行中 · [智能选择] 2 个服务商');
    });

    test('自定义服务商使用其名称', () {
      final text = defaultRunningNotificationText(
        settings(
          dns: const {
            'selected_provider_id': 'user_1',
            'user_providers_json':
                '[{"id":"user_1","name":"自建 DoH","protocol":"DOH",'
                '"url":"https://dns.example.com/query","host":"","port":853}]',
          },
        ),
        express: false,
      );
      expect(text, '已连接 · 自建 DoH');
    });
  });

  group('服务器模式通知文案', () {
    test('显示当前上游与监听端口', () {
      expect(
        defaultServerNotificationText(settings()),
        '当前上游: 阿里云 (223.5.5.5) · 端口 1053',
      );
    });

    test('跟随所选上游与端口', () {
      final text = defaultServerNotificationText(
        settings(
          server: const {
            'selected_upstream_id': 'preset_cloudflare_doh',
            'local_listen_port': 5353,
          },
        ),
      );
      expect(
        text,
        '当前上游: Cloudflare (https://cloudflare-dns.com/dns-query) · 端口 5353',
      );
    });
  });
}

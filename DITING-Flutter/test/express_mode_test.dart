import 'dart:convert';

import 'package:diting/data/db/rule_providers.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_vpn_controller.dart';

LegacySettings expressSettings(Map<String, Object?> values) => LegacySettings(
  MemoryLegacyPrefsStore({
    'diting_settings': {'app_work_mode': 'express'},
    'diting_express_prefs': values,
  }),
);

void main() {
  group('极速模式 prefs 视图', () {
    test('DNS 键读 diting_express_prefs，UI 键仍读全局容器', () {
      final store = MemoryLegacyPrefsStore({
        'dns_vpn_prefs': {
          'selected_provider_id': 'preset_google_dns',
          'theme_color_style': 'moss',
          // 应用级规则在 1.4.3 里不进数据集容器。
          'excluded_app_packages': ['com.example.skip'],
        },
        'diting_express_prefs': {
          'selected_provider_id': 'preset_dnspod_dns',
          'ipv6_mode': 'disabled',
        },
        'express_vpn_prefs': {'express_vpn_running': true},
      });
      final normal = LegacySettings(store);
      final express = normal.forExpress();

      expect(express.selectedProviderId, 'preset_dnspod_dns');
      expect(express.ipv6ModeRaw, 'disabled');
      expect(express.excludedPackages, {'com.example.skip'});
      expect(express.expressVpnRunning, isTrue);
      expect(express.paletteRaw, 'moss');

      expect(normal.selectedProviderId, 'preset_google_dns');
      expect(normal.expressVpnRunning, isTrue);
    });

    test('缺失键回落到旧版默认值', () {
      final express = expressSettings({}).forExpress();
      expect(express.selectedProviderId, 'preset_alidns_dns');
      expect(express.resolutionModeRaw, 'single');
      expect(express.cacheEnabled, isTrue);
      expect(express.bootstrapEnabled, isTrue);
      expect(express.ipv6ModeRaw, 'auto');
      expect(express.expressVpnRunning, isFalse);
    });
  });

  group('极速模式电源状态机', () {
    ProviderContainer container({
      required FakeVpnController normal,
      required FakeVpnController express,
      Map<String, Object?> expressPrefs = const {},
      Map<String, Object?> expressRunning = const {},
    }) {
      final store = MemoryLegacyPrefsStore({
        'diting_settings': {'app_work_mode': 'express'},
        'diting_express_prefs': {
          'selected_provider_id': 'preset_dnspod_dns',
          'ipv6_mode': 'disabled',
          ...expressPrefs,
        },
        'express_vpn_prefs': expressRunning,
      });
      final c = ProviderContainer(
        overrides: [
          legacyPrefsStoreProvider.overrideWithValue(store),
          vpnControllerProvider.overrideWithValue(normal),
          expressVpnControllerProvider.overrideWithValue(express),
          expressRuleRepositoryProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('启动走极速通道并写 express_vpn_running', () async {
      final normal = FakeVpnController();
      final express = FakeVpnController();
      final c = container(normal: normal, express: express);
      expect(c.read(powerProvider), PowerState.stopped);

      await c.read(powerProvider.notifier).toggle();
      expect(c.read(powerProvider), PowerState.running);
      expect(express.startCalls, 1);
      expect(normal.startCalls, 0);

      final request = express.lastRequest!;
      expect(request.bypassLan, isFalse);
      expect(request.ipv6Mode, 'disabled');
      final json = jsonDecode(request.dnsConfig) as Map;
      final providers = json['providers'] as List;
      expect((providers.first as Map)['id'], 'preset_dnspod_dns');

      final settings = c.read(legacySettingsProvider);
      expect(settings.expressVpnRunning, isTrue);
      expect(settings.vpnRunning, isFalse);
    });

    test('停止清掉 express_vpn_running', () async {
      final express = FakeVpnController();
      final c = container(normal: FakeVpnController(), express: express);
      await c.read(powerProvider.notifier).toggle();
      await c.read(powerProvider.notifier).toggle();
      expect(c.read(powerProvider), PowerState.stopped);
      expect(express.stopCalls, 1);
      expect(c.read(legacySettingsProvider).expressVpnRunning, isFalse);
    });

    test('残留运行标志经原生状态回写为停止', () async {
      final express = FakeVpnController();
      final c = container(
        normal: FakeVpnController(),
        express: express,
        expressRunning: {'express_vpn_running': true},
      );
      expect(c.read(powerProvider), PowerState.starting);
      await c.read(powerProvider.notifier).syncStatus();
      expect(c.read(powerProvider), PowerState.stopped);
      expect(c.read(legacySettingsProvider).expressVpnRunning, isFalse);
    });

    test('切回普通模式会停止极速隧道', () async {
      final express = FakeVpnController();
      final c = container(normal: FakeVpnController(), express: express);
      await c.read(powerProvider.notifier).toggle();
      expect(c.read(powerProvider), PowerState.running);

      c.read(workModeProvider.notifier).select(AppWorkMode.normal);
      await Future<void>.delayed(Duration.zero);
      expect(express.stopCalls, 1);
      expect(c.read(powerProvider), PowerState.stopped);
    });

    test('原生启动失败进入 error 且不留下运行标志', () async {
      final express = FakeVpnController(started: false, error: 'no tun');
      final c = container(normal: FakeVpnController(), express: express);
      await c.read(powerProvider.notifier).toggle();
      expect(c.read(powerProvider), PowerState.error);
      expect(c.read(powerProvider.notifier).lastError, 'no tun');
      expect(c.read(legacySettingsProvider).expressVpnRunning, isFalse);
    });
  });
}

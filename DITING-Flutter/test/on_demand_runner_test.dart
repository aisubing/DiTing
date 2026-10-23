import 'dart:convert';

import 'package:diting/data/mock_config_resources.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/vpn_bridge.dart';
import 'package:diting/pages/config/on_demand_capabilities.dart';
import 'package:diting/state/on_demand_runner.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_vpn_controller.dart';

/// The on-demand switch and the SSID table were persisted but never applied, so the tunnel kept
/// running whatever network the device joined. These pin the rule that now drives it.
void main() {
  ProviderContainer container({
    required FakeVpnController vpn,
    String? ssid,
    bool onDemand = true,
    List<MockSsidRule> rules = const [MockSsidRule(ssid: 'Home-5G')],
    String workMode = 'normal',
    bool running = false,
  }) {
    final store = MemoryLegacyPrefsStore({
      'diting_settings': {'app_work_mode': workMode},
      'dns_vpn_prefs': {'vpn_running': running},
      'diting_config_resources': {
        'on_demand_enabled': onDemand,
        'ssid_rules_json': jsonEncode([
          for (final rule in rules)
            {
              'ssid': rule.ssid,
              'cellular': rule.cellular,
              'wifi': rule.wifi,
              'delayMs': rule.delayMs,
            },
        ]),
      },
    });
    vpn.statusValue = VpnStatus(running: running, persisted: running);
    final instance = ProviderContainer(
      overrides: [
        legacyPrefsStoreProvider.overrideWithValue(store),
        vpnControllerProvider.overrideWithValue(vpn),
        currentSsidReaderProvider.overrideWithValue(() async => ssid),
      ],
    );
    addTearDown(instance.dispose);
    return instance;
  }

  /// Settles the asynchronous status sync `PowerNotifier.build` starts for a persisted tunnel.
  Future<void> settle(ProviderContainer instance) async {
    instance.read(powerProvider);
    await Future<void>.delayed(Duration.zero);
  }

  group('按需连接判定', () {
    test('关闭时不动隧道', () async {
      final vpn = FakeVpnController();
      final c = container(vpn: vpn, ssid: 'Home-5G', onDemand: false);
      expect(
        await c.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.disabled,
      );
      expect(vpn.startCalls, 0);
      expect(vpn.stopCalls, 0);
    });

    test('无法读取 SSID 时不动隧道', () async {
      final vpn = FakeVpnController();
      final c = container(vpn: vpn, ssid: null);
      expect(
        await c.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.unknownSsid,
      );
      expect(vpn.startCalls, 0);
      expect(vpn.stopCalls, 0);
    });

    test('服务器模式不动隧道', () async {
      final vpn = FakeVpnController();
      final c = container(vpn: vpn, ssid: 'Home-5G', workMode: 'dns');
      expect(
        await c.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.serverMode,
      );
      expect(vpn.startCalls, 0);
    });

    test('匹配白名单时启动 VPN', () async {
      final vpn = FakeVpnController();
      final c = container(vpn: vpn, ssid: 'Home-5G');
      expect(
        await c.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.started,
      );
      expect(vpn.startCalls, 1);
      expect(c.read(powerProvider), PowerState.running);
    });

    test('已在运行时不重复启动', () async {
      final vpn = FakeVpnController();
      final c = container(vpn: vpn, ssid: 'Home-5G', running: true);
      await settle(c);
      expect(c.read(powerProvider), PowerState.running);
      expect(
        await c.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.alreadyRunning,
      );
      expect(vpn.startCalls, 0);
    });

    test('不在白名单时停止 VPN', () async {
      final vpn = FakeVpnController();
      final c = container(vpn: vpn, ssid: 'Cafe-WiFi', running: true);
      await settle(c);
      expect(c.read(powerProvider), PowerState.running);
      expect(
        await c.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.stopped,
      );
      expect(vpn.stopCalls, 1);
      expect(c.read(powerProvider), PowerState.stopped);
    });

    test('不在白名单且未运行时什么都不做', () async {
      final vpn = FakeVpnController();
      final c = container(vpn: vpn, ssid: 'Cafe-WiFi');
      expect(
        await c.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.alreadyStopped,
      );
      expect(vpn.stopCalls, 0);
    });

    test('未连 Wi-Fi 时按不匹配处理', () async {
      final vpn = FakeVpnController();
      final c = container(vpn: vpn, ssid: '');
      expect(
        await c.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.alreadyStopped,
      );
    });

    test('SSID 区分大小写', () async {
      final vpn = FakeVpnController();
      final c = container(vpn: vpn, ssid: 'home-5g');
      expect(
        await c.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.alreadyStopped,
      );
      expect(vpn.startCalls, 0);
    });

    test('未授权时报告等待系统授权', () async {
      final vpn = FakeVpnController(prepared: false);
      final c = container(vpn: vpn, ssid: 'Home-5G');
      expect(
        await c.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.needsConsent,
      );
      expect(c.read(powerProvider), PowerState.starting);
      expect(vpn.startCalls, 0);
    });
  });

  group('decideSsid 纯函数', () {
    test('任意状态都能给出结论', () {
      const rules = [MockSsidRule(ssid: 'Home-5G')];
      expect(
        decideSsid(enabled: false, rules: rules, currentSsid: 'Home-5G').state,
        SsidMatchState.disabled,
      );
      expect(
        decideSsid(enabled: true, rules: rules, currentSsid: null).state,
        SsidMatchState.unknown,
      );
      expect(
        decideSsid(enabled: true, rules: rules, currentSsid: '').state,
        SsidMatchState.noWifi,
      );
      expect(
        decideSsid(enabled: true, rules: rules, currentSsid: 'Home-5G').state,
        SsidMatchState.matched,
      );
      expect(
        decideSsid(enabled: true, rules: rules, currentSsid: 'Other').state,
        SsidMatchState.unmatched,
      );
    });
  });
}

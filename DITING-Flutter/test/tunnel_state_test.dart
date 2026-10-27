// The tunnel state machine: power transitions, the express channel, the startup
// watchdog, on-demand SSID matching and the engine counters the native side reports.

import 'dart:convert';

import 'package:diting/data/db/rule_providers.dart';
import 'package:diting/data/mock_config_resources.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/server/dns_server_bridge.dart';
import 'package:diting/data/vpn/vpn_bridge.dart';
import 'package:diting/pages/config/on_demand_capabilities.dart';
import 'package:diting/state/on_demand_runner.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_vpn_controller.dart';

void main() {
  group('启动看门狗', _powerGuard);
  group('极速模式', _expressMode);
  group('引擎计数', _engineStats);
  group('按需连接', _onDemand);
}

void _powerGuard() {
  test('未收到授权回调时不会永远停在启动中', () {
    fakeAsync((async) {
      // prepared: false -> the system shows the auth prompt, answered by MainActivity.
      final controller = FakeVpnController(prepared: false);
      final store = MemoryLegacyPrefsStore({
        'diting_settings': {'app_work_mode': 'normal'},
      });
      final c = ProviderContainer(
        overrides: [
          legacyPrefsStoreProvider.overrideWithValue(store),
          vpnControllerProvider.overrideWithValue(controller),
          ruleRepositoryProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);

      c.read(powerProvider.notifier).toggle();
      async.flushMicrotasks();
      expect(c.read(powerProvider), PowerState.starting);

      // A lost callback (activity recreated) must converge, or the power key stays dead.
      async.elapse(const Duration(seconds: 95));
      expect(c.read(powerProvider), PowerState.error);
      expect(c.read(powerProvider.notifier).lastError, '没有获得 VPN 授权');
      expect(c.read(legacySettingsProvider).vpnRunning, isFalse);

      // The error state allows another tap.
      expect(c.read(powerProvider).isBusy, isFalse);
    });
  });

  test('残留运行标志且原生状态不回应时收敛为失败', () {
    fakeAsync((async) {
      final controller = FakeVpnController(prepared: true)
        ..statusValue = const VpnStatus(running: false, persisted: true);
      final store = MemoryLegacyPrefsStore({
        'diting_settings': {'app_work_mode': 'normal'},
        'dns_vpn_prefs': {'vpn_running': true},
      });
      final c = ProviderContainer(
        overrides: [
          legacyPrefsStoreProvider.overrideWithValue(store),
          vpnControllerProvider.overrideWithValue(controller),
          ruleRepositoryProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);

      expect(c.read(powerProvider), PowerState.starting);
      async.elapse(const Duration(seconds: 1));
      // Native says it is not running: settle on stopped instead of error.
      expect(c.read(powerProvider), PowerState.stopped);
      expect(c.read(legacySettingsProvider).vpnRunning, isFalse);
    });
  });

  test('启动成功后 watchdog 不再触发', () {
    fakeAsync((async) {
      final controller = FakeVpnController(prepared: true);
      final store = MemoryLegacyPrefsStore({
        'diting_settings': {'app_work_mode': 'normal'},
      });
      final c = ProviderContainer(
        overrides: [
          legacyPrefsStoreProvider.overrideWithValue(store),
          vpnControllerProvider.overrideWithValue(controller),
          ruleRepositoryProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);

      c.read(powerProvider.notifier).toggle();
      async.flushMicrotasks();
      expect(c.read(powerProvider), PowerState.running);

      // `status()` keeps saying running, so an expired watchdog must not corrupt state.
      controller.statusValue = const VpnStatus(running: true, persisted: true);
      async.elapse(const Duration(seconds: 120));
      expect(c.read(powerProvider), PowerState.running);
    });
  });
}

void _expressMode() {
  group('极速模式 prefs 视图', () {
    test('DNS 键读 diting_express_prefs，UI 键仍读全局容器', () {
      final store = MemoryLegacyPrefsStore({
        'dns_vpn_prefs': {
          'selected_provider_id': 'preset_google_dns',
          'theme_color_style': 'moss',
          // App-level rules do not enter the dataset container in 1.4.3.
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

LegacySettings expressSettings(Map<String, Object?> values) => LegacySettings(
  MemoryLegacyPrefsStore({
    'diting_settings': {'app_work_mode': 'express'},
    'diting_express_prefs': values,
  }),
);

void _engineStats() {
  group('原生状态里的引擎计数', () {
    test('VpnStatus 解析 stats，缺失时为常量空表', () {
      final withStats = VpnStatus.fromMap({
        'running': true,
        'persisted': true,
        'stats': {'queries': 12, 'blocked': 3, 'cacheHits': 7},
      });
      expect(withStats.stats['queries'], 12);
      expect(withStats.stats['blocked'], 3);

      final empty = VpnStatus.fromMap({'running': false});
      expect(empty.stats, isEmpty);
    });

    test('解析原生启动时间戳，缺失或为零时为 null', () {
      final started = DateTime(2026, 10, 1, 8, 30);
      final vpn = VpnStatus.fromMap({
        'running': true,
        'startedAt': started.millisecondsSinceEpoch,
      });
      expect(vpn.startedAt, started);

      final server = DnsServerStatus.fromMap({
        'running': true,
        'startedAt': started.millisecondsSinceEpoch,
      });
      expect(server.startedAt, started);

      expect(VpnStatus.fromMap({'running': true}).startedAt, isNull);
      expect(
        VpnStatus.fromMap({'running': true, 'startedAt': 0}).startedAt,
        isNull,
      );
      expect(DnsServerStatus.fromMap({'running': false}).startedAt, isNull);
    });
  });

  group('ServiceStatsNotifier 接入真实计数', () {
    test('applyNative 覆盖 mock 值，停止时归零', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final stats = c.read(serviceStatsProvider.notifier);
      expect(c.read(serviceStatsProvider).queries, 0);

      stats.applyNative({
        'queries': 9,
        'blocked': 4,
        'cacheHits': 6,
      }, running: true);
      final running = c.read(serviceStatsProvider);
      expect(running.queries, 9);
      expect(running.blocked, 4);
      expect(running.cacheHits, 6);
      expect(running.cacheHitRate, closeTo(6 / 9, 0.0001));

      stats.applyNative(const {}, running: false);
      expect(c.read(serviceStatsProvider).queries, 0);
    });

    test('原生启动时间决定运行时长，进程重建后不会归零', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final stats = c.read(serviceStatsProvider.notifier);

      // The UI process was recreated: nothing local remembers the start, only the service does.
      stats.applyNative(
        {'queries': 1},
        running: true,
        startedAt: DateTime.now().subtract(
          const Duration(minutes: 7, seconds: 3),
        ),
      );
      final uptime = c.read(serviceStatsProvider).uptime;
      expect(uptime.inMinutes, 7);
      expect(uptime.inSeconds % 60, closeTo(3, 2));
    });

    test('非当前数据面的同步不清空计时', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final stats = c.read(serviceStatsProvider.notifier);

      stats.applyNative(
        {'queries': 5},
        running: true,
        startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );
      // The other plane always answers "not running"; acting on it flashed `0秒` for a second.
      stats.applyNative(const {}, running: false, ownsStats: false);

      final kept = c.read(serviceStatsProvider);
      expect(kept.queries, 5);
      expect(kept.uptime.inMinutes, 2);
    });

    test('syncStatus 将原生 stats 写进服务统计', () async {
      final fake = FakeVpnController()
        ..statusValue = const VpnStatus(
          running: true,
          persisted: true,
          stats: {'queries': 21, 'blocked': 2, 'cacheHits': 11},
        );
      final c = ProviderContainer(
        overrides: [
          legacyPrefsStoreProvider.overrideWithValue(MemoryLegacyPrefsStore()),
          vpnControllerProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(c.dispose);

      await c.read(powerProvider.notifier).syncStatus();
      expect(c.read(serviceStatsProvider).queries, 21);
      expect(c.read(serviceStatsProvider).cacheHits, 11);
    });
  });
}

/// The on-demand switch and the SSID table were persisted but never applied, so the tunnel kept
/// running whatever network the device joined. These pin the rule that now drives it.
void _onDemand() {
  ProviderContainer container({
    required FakeVpnController vpn,
    String? ssid,
    bool onDemand = true,
    List<MockSsidRule> rules = const [MockSsidRule(ssid: 'Home-5G')],
    String workMode = 'normal',
    bool running = false,
    String? lastSsid,
  }) {
    final store = MemoryLegacyPrefsStore({
      'diting_settings': {'app_work_mode': workMode},
      'dns_vpn_prefs': {'vpn_running': running},
      'diting_config_resources': {
        'on_demand_enabled': onDemand,
        'on_demand_last_ssid': ?lastSsid,
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

  /// The last network the whitelist was applied to; `null` means the key is absent.
  String? readLastSsid(ProviderContainer c) =>
      c
              .read(legacyPrefsStoreProvider)
              .read('diting_config_resources', 'on_demand_last_ssid')
          as String?;

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
        await c.read(onDemandRunnerProvider).apply(force: true),
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
        await c.read(onDemandRunnerProvider).apply(force: true),
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
        await c.read(onDemandRunnerProvider).apply(force: true),
        OnDemandOutcome.stopped,
      );
      expect(vpn.stopCalls, 1);
      expect(c.read(powerProvider), PowerState.stopped);
    });

    test('SSID 区分大小写', () async {
      final vpn = FakeVpnController();
      final c = container(vpn: vpn, ssid: 'home-5g');
      expect(
        await c.read(onDemandRunnerProvider).apply(force: true),
        OnDemandOutcome.alreadyStopped,
      );
      expect(vpn.startCalls, 0);
    });

    test('未授权时报告等待系统授权', () async {
      final vpn = FakeVpnController(prepared: false);
      final c = container(vpn: vpn, ssid: 'Home-5G');
      expect(
        await c.read(onDemandRunnerProvider).apply(force: true),
        OnDemandOutcome.needsConsent,
      );
      expect(c.read(powerProvider), PowerState.starting);
      expect(vpn.startCalls, 0);
    });
  });

  /// Start and resume re-evaluate the whitelist without force; these pin the "only act on a
  /// network change" rule that keeps a manual start/stop from being overridden on every launch.
  group('启动/回前台重估', () {
    test('首次评估只记录网络，不动隧道', () async {
      final vpn = FakeVpnController();
      final c = container(vpn: vpn, ssid: 'Home-5G');
      expect(
        await c.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.sameNetwork,
      );
      expect(vpn.startCalls, 0);
      expect(readLastSsid(c), 'Home-5G');
    });

    test('网络未变化时不覆盖手动状态', () async {
      final vpn = FakeVpnController();
      final stopped = container(vpn: vpn, ssid: 'Home-5G', lastSsid: 'Home-5G');
      expect(
        await stopped.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.sameNetwork,
      );
      expect(vpn.startCalls, 0);

      final running = container(
        vpn: vpn,
        ssid: 'Home-5G',
        lastSsid: 'Home-5G',
        running: true,
      );
      await settle(running);
      expect(
        await running.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.sameNetwork,
      );
      expect(vpn.stopCalls, 0);
    });

    test('网络切换到白名单内时启动并记录新网络', () async {
      final vpn = FakeVpnController();
      final c = container(vpn: vpn, ssid: 'Home-5G', lastSsid: 'Cafe-WiFi');
      expect(
        await c.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.started,
      );
      expect(vpn.startCalls, 1);
      expect(readLastSsid(c), 'Home-5G');
      expect(
        await c.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.sameNetwork,
      );
      expect(vpn.startCalls, 1);
    });

    test('网络切换到白名单外时停止', () async {
      final vpn = FakeVpnController();
      final c = container(
        vpn: vpn,
        ssid: 'Cafe-WiFi',
        lastSsid: 'Home-5G',
        running: true,
      );
      await settle(c);
      expect(
        await c.read(onDemandRunnerProvider).apply(),
        OnDemandOutcome.stopped,
      );
      expect(vpn.stopCalls, 1);
      expect(readLastSsid(c), 'Cafe-WiFi');
    });
  });
}

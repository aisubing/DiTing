import 'package:diting/data/db/rule_providers.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/vpn/vpn_bridge.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_vpn_controller.dart';

void main() {
  test('未收到授权回调时不会永远停在启动中', () {
    fakeAsync((async) {
      // prepared: false → 系统弹授权框，回调正常情况下由 MainActivity 送回。
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

      // 回调丢失（Activity 重建等）：必须自己收敛，否则电源键永久不可用。
      async.elapse(const Duration(seconds: 95));
      expect(c.read(powerProvider), PowerState.error);
      expect(c.read(powerProvider.notifier).lastError, '没有获得 VPN 授权');
      expect(c.read(legacySettingsProvider).vpnRunning, isFalse);

      // 错误态允许再次点击。
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
      // 原生说自己没在跑 → 直接收敛为已停止，不进入错误态。
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

      // status() 一直说 running，watchdog 过期也不能把状态改坏。
      controller.statusValue = const VpnStatus(running: true, persisted: true);
      async.elapse(const Duration(seconds: 120));
      expect(c.read(powerProvider), PowerState.running);
    });
  });
}

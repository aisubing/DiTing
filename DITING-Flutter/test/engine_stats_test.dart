import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/server/dns_server_bridge.dart';
import 'package:diting/data/vpn/vpn_bridge.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_vpn_controller.dart';

void main() {
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

    test('DnsServerStatus 解析 stats 与端口', () {
      final status = DnsServerStatus.fromMap({
        'running': true,
        'persisted': true,
        'port': 2053,
        'stats': {'queries': 5, 'cacheHits': 2},
      });
      expect(status.port, 2053);
      expect(status.stats['cacheHits'], 2);
    });
  });

  group('ServiceStatsNotifier 接入真实计数', () {
    test('applyNative 覆盖 mock 值，停止时归零', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final stats = c.read(serviceStatsProvider.notifier);
      expect(c.read(serviceStatsProvider).queries, 0);

      stats.applyNative(
        {'queries': 9, 'blocked': 4, 'cacheHits': 6},
        running: true,
      );
      final running = c.read(serviceStatsProvider);
      expect(running.queries, 9);
      expect(running.blocked, 4);
      expect(running.cacheHits, 6);
      expect(running.cacheHitRate, closeTo(6 / 9, 0.0001));

      stats.applyNative(const {}, running: false);
      expect(c.read(serviceStatsProvider).queries, 0);
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

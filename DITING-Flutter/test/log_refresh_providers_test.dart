import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/log_refresh_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The log cards read tables the native writers keep filling; the timer is what makes
/// `CacheHotspotsCard` / `BootstrapDnsCard` update without a manual refresh.
void main() {
  test('tick 递增共享 revision，日志 provider 随之重查', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(dnsLogRevisionProvider);
    container.read(logLiveRefreshProvider.notifier).tick();
    expect(container.read(dnsLogRevisionProvider), before + 1);
  });

  testWidgets('挂载后定时刷新一次，不依赖手动点刷新', (tester) async {
    debugDisableDashboardLiveUpdates = false;
    addTearDown(() => debugDisableDashboardLiveUpdates = false);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(dnsLogRevisionProvider);
    container.read(logLiveRefreshProvider.notifier).attachPolling();
    await tester.pump(logLiveRefreshInterval + const Duration(seconds: 1));

    expect(container.read(dnsLogRevisionProvider), before + 1);
    container.read(logLiveRefreshProvider.notifier).detachPolling();
  });

  testWidgets('测试开关关闭定时器，避免 pumpAndSettle 永不 settle', (tester) async {
    debugDisableDashboardLiveUpdates = true;
    addTearDown(() => debugDisableDashboardLiveUpdates = false);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(dnsLogRevisionProvider);
    container.read(logLiveRefreshProvider.notifier).attachPolling();
    await tester.pump(logLiveRefreshInterval * 3);

    expect(container.read(dnsLogRevisionProvider), before);
  });

  testWidgets('引用计数：多页共用定时器，最后一个 detach 才停', (tester) async {
    debugDisableDashboardLiveUpdates = false;
    addTearDown(() => debugDisableDashboardLiveUpdates = false);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(logLiveRefreshProvider.notifier);

    notifier.attachPolling();
    notifier.attachPolling();
    notifier.detachPolling();

    final before = container.read(dnsLogRevisionProvider);
    await tester.pump(logLiveRefreshInterval + const Duration(seconds: 1));
    expect(container.read(dnsLogRevisionProvider), before + 1);

    // Last detach stops the timer: no further bumps.
    notifier.detachPolling();
    final after = container.read(dnsLogRevisionProvider);
    await tester.pump(logLiveRefreshInterval * 3);
    expect(container.read(dnsLogRevisionProvider), after);
  });
}

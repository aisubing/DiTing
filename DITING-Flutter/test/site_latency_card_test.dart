import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/pages/home/dashboard/cards/site_latency_card.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_host.dart';
import 'support/test_hooks.dart';

/// The card probes on its own first frame, and its header must then report the tally for the
/// sites it actually drew — a mismatch between the chip and the cells is what the emulator showed.
class _FakeRunner implements DiagnosticsRunner {
  final List<String> pingCalls = [];

  @override
  Future<PingSummary> ping(
    String target, {
    int count = 4,
    int timeoutSeconds = 3,
  }) async {
    pingCalls.add(target);
    return PingSummary(
      target: target,
      transmitted: count,
      received: count,
      lossPercent: 0,
      success: true,
      minMs: 1,
      avgMs: 1,
      maxMs: 2,
      jitterMs: 0,
    );
  }

  @override
  Future<TraceResult> traceRoute(String target, {int maxHops = 30}) async =>
      const TraceResult(target: '', hops: [], success: false);

  @override
  Future<DnsLookupResult> lookupDns(
    String domain, {
    bool viaTunnel = false,
    bool ipv4 = true,
    String? server,
  }) async => DnsLookupResult(
    domain: domain,
    source: 'upstream',
    answers: const [],
    elapsedMs: 0,
  );

  @override
  Future<NetworkInfoSnapshot> networkInfo() async => const NetworkInfoSnapshot(
    interfaceName: 'wlan0',
    localIpv4: '192.168.1.2',
    privateDns: '',
    vpnActive: false,
  );
}

void main() {
  // The card's auto-probe is skipped while the global flag is set, so turn it back off here.
  installGlobalTestHooks();

  testWidgets('自定义的四个站点测完后表头显示计数', (tester) async {
    debugDisableDashboardLiveUpdates = false;
    final runner = _FakeRunner();
    final store = MemoryLegacyPrefsStore();
    LegacySettings(store).setDashboardSiteIds(const [
      'baidu',
      'douyin',
      'netease',
      'duckduckgo',
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diagnosticsRunnerProvider.overrideWithValue(runner),
          legacyPrefsStoreProvider.overrideWithValue(store),
        ],
        child: const AppHost(child: SiteLatencyCard()),
      ),
    );
    await tester.pumpAndSettle();

    expect(runner.pingCalls, [
      'www.baidu.com',
      'www.douyin.com',
      'music.163.com',
      'duckduckgo.com',
    ]);
    expect(find.text('4 / 4 通畅'), findsOneWidget);
    expect(find.text('尚未测速'), findsNothing);
  });
}

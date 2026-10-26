import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/data/site_latency_categories.dart';
import 'package:diting/data/site_latency_targets.dart';
import 'package:diting/pages/home/dashboard/detail/site_latency_detail_page.dart';
import 'package:diting/pages/home/dashboard/detail/site_latency_sites_page.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/app_host.dart';

/// Pins the two behaviours the detail page was rewritten for: nothing probes on open, and each
/// category has its own probe button that touches only its own sites.
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
      minMs: 20,
      avgMs: 30,
      maxMs: 40,
      jitterMs: 2,
      resolvedAddress: '2408:8756::1',
      addressFamily: 'IPv6',
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
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRunner runner;

  setUp(() => runner = _FakeRunner());

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diagnosticsRunnerProvider.overrideWithValue(runner),
          legacyPrefsStoreProvider.overrideWithValue(MemoryLegacyPrefsStore()),
        ],
        child: AppHost(child: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('进页面不会自动测速', (tester) async {
    await pumpPage(tester, const SiteLatencyDetailPage());

    expect(runner.pingCalls, isEmpty);
    expect(find.text('未测速'), findsOneWidget);
    expect(find.text('待测'), findsOneWidget);
    // The page lists every category, in enum order; the list is lazy, so walk it.
    for (final category in SiteCategory.values) {
      await tester.dragUntilVisible(
        find.text(category.label),
        find.byType(Scrollable).first,
        const Offset(0, -280),
      );
      expect(find.text(category.label), findsWidgets, reason: category.label);
    }
    expect(runner.pingCalls, isEmpty);
  });

  testWidgets('点某个分类的测速按钮只测该分类', (tester) async {
    await pumpPage(tester, const SiteLatencyDetailPage());

    final search = siteLatencyInCategory(SiteCategory.search);
    final button = find.byTooltip('测速${SiteCategory.search.label}');
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(runner.pingCalls, [for (final target in search) target.host]);
    expect(runner.pingCalls.length, lessThan(siteLatencyTargets.length));
    // The probed group reports its own tally, in the same '$alive / $total 通畅' shape the card
    // uses.
    expect(find.text('${search.length} / ${search.length} 通畅'), findsOneWidget);
  });

  testWidgets('「测全部」一次测完所有站点', (tester) async {
    await pumpPage(tester, const SiteLatencyDetailPage());

    await tester.tap(find.byTooltip('测全部'));
    await tester.pumpAndSettle();

    expect(runner.pingCalls.length, siteLatencyTargets.length);
    expect(find.text('${siteLatencyTargets.length} / ${siteLatencyTargets.length}'), findsOneWidget);
  });

  testWidgets('仪表盘站点页最多选四个', (tester) async {
    await pumpPage(tester, const SiteLatencySitesPage());

    expect(find.text('第 1 位'), findsOneWidget);
    expect(find.text('第 $dashboardSiteCount 位'), findsOneWidget);
    // Full card: adding a fifth site is refused with a hint instead of silently dropped.
    final steam = find.text('Steam');
    await tester.dragUntilVisible(
      steam,
      find.byType(Scrollable).first,
      const Offset(0, -280),
    );
    await tester.tap(steam);
    await tester.pumpAndSettle();
    expect(find.textContaining('最多放 $dashboardSiteCount 个站点'), findsOneWidget);
  });
}

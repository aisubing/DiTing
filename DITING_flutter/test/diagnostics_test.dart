import 'package:diting/data/native/diagnostics_bridge.dart';
import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/pages/tools/tools_page.dart';
import 'package:diting/state/diagnostics_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/app_host.dart';
import 'support/test_hooks.dart';

/// 网络工具的三类判据：
/// 1. host 清洗要逐条对上 `NetworkPingTool.sanitizeHost`（含 `[::1]:53` 与
///    `2001:db8::1` 的反例——端口规则最容易误伤 IPv6）；
/// 2. `fromMap` 缺字段时必须是「结构完整的空结果」，不能让 `null` 冒到 UI；
/// 3. 面板要能在成功 / 失败 / fallback 三态下渲染出对应文案。
void main() {
  installGlobalTestHooks();

  group('host 清洗', () {
    test('去 scheme / 路径 / userinfo / 端口', () {
      expect(
        sanitizeProbeHost('https://user:pass@example.com:8443/path?q=1'),
        'example.com',
      );
      expect(sanitizeProbeHost('http://example.com'), 'example.com');
      expect(sanitizeProbeHost('example.com/path'), 'example.com');
      expect(sanitizeProbeHost('example.com?q=1'), 'example.com');
      expect(sanitizeProbeHost('example.com#frag'), 'example.com');
      expect(sanitizeProbeHost('  example.com  '), 'example.com');
    });

    test('方括号 IPv6 取括注内容', () {
      expect(sanitizeProbeHost('[::1]:53'), '::1');
      expect(sanitizeProbeHost('[2001:db8::1]'), '2001:db8::1');
      expect(sanitizeProbeHost('https://[::1]:8080/x'), '::1');
      // 没有右括号时原样保留（与 Kotlin 一致：`endIndex > 0` 才剥），
      // 交给原生报错，而不是吐一个半截 host。
      expect(sanitizeProbeHost('[::1'), '[::1');
    });

    test('裸 IPv6 不被端口规则误伤', () {
      // 这条是守卫条件（不含 "::" 且恰好一个冒号）的反例：双冒号地址必须原样保留。
      expect(sanitizeProbeHost('2001:db8::1'), '2001:db8::1');
      expect(sanitizeProbeHost('::1'), '::1');
      expect(sanitizeProbeHost('fe80::1'), 'fe80::1');
    });

    test('单冒号 + 全数字才当端口剥', () {
      expect(sanitizeProbeHost('example.com:8080'), 'example.com');
      expect(sanitizeProbeHost('10.0.0.1:53'), '10.0.0.1');
      // 冒号后不是纯数字 → 保留（域名里不会出现，但别把 a:b 吃掉）。
      expect(sanitizeProbeHost('example.com:abc'), 'example.com:abc');
    });

    test('空串与纯空白', () {
      expect(sanitizeProbeHost(''), '');
      expect(sanitizeProbeHost('   '), '');
      expect(resolveProbeHost('').error, '请输入探测目标');
      expect(resolveProbeHost('  ').error, '请输入探测目标');
      expect(resolveProbeHost('a b').error, '目标不能包含空格');
      expect(resolveProbeHost('https://example.com').error, isNull);
    });
  });

  group('fromMap 缺字段容错', () {
    test('PingSummary 空 map 得到失败形态', () {
      final summary = PingSummary.fromMap(const {});

      expect(summary.target, '');
      expect(summary.transmitted, 0);
      expect(summary.received, 0);
      expect(summary.lossPercent, 100);
      expect(summary.success, isFalse);
      expect(summary.replies, isEmpty);
      expect(summary.measuredWithFallback, isFalse);
      expect(summary.minMs, isNull);
    });

    test('PingSummary 完整 map 逐字段还原，replies 非 Map 项被丢弃', () {
      final summary = PingSummary.fromMap({
        'target': 'example.com',
        'resolvedAddress': '93.184.216.34',
        'addressFamily': 'IPv4',
        'transmitted': 4,
        'received': 3,
        'lossPercent': 25.0,
        'minMs': 10,
        'avgMs': 12.5,
        'maxMs': 18,
        'jitterMs': 2.5,
        'success': true,
        'measuredWithFallback': true,
        'replies': [
          {'sequence': 1, 'elapsedMs': 10, 'ttl': 57},
          {'sequence': 2, 'elapsedMs': 12.5, 'error': null},
          'not-a-map',
        ],
      });

      expect(summary.transmitted, 4);
      expect(summary.received, 3);
      expect(summary.avgMs, 12.5);
      expect(summary.measuredWithFallback, isTrue);
      expect(summary.replies, hasLength(2));
      expect(summary.replies.first.ttl, 57);
      expect(summary.replies.first.ok, isTrue);
    });

    test('TraceResult / DnsLookupResult 空 map 不抛', () {
      final trace = TraceResult.fromMap(const {});
      expect(trace.hops, isEmpty);
      expect(trace.success, isFalse);
      expect(trace.cancelled, isFalse);

      final lookup = DnsLookupResult.fromMap(const {});
      expect(lookup.answers, isEmpty);
      // 缺 source 时回落 'error'：不能默认成 upstream（那是「真的打到了上游」）。
      expect(lookup.source, 'error');
      expect(lookup.success, isFalse);
      expect(lookup.elapsedMs, 0);
    });

    test('DnsLookupResult 有答案才算成功', () {
      final result = DnsLookupResult.fromMap({
        'domain': 'example.com',
        'source': 'cache',
        'elapsedMs': 1.5,
        'answers': [
          {'type': 'A', 'value': '1.2.3.4', 'ttl': 60},
        ],
      });

      expect(result.source, 'cache');
      expect(result.success, isTrue);
      expect(result.answers.single.value, '1.2.3.4');
    });

    test('NetworkInfoSnapshot 空 map 得到空快照', () {
      final snapshot = NetworkInfoSnapshot.fromMap(const {});

      expect(snapshot.interfaceName, '');
      expect(snapshot.localIpv4, '');
      expect(snapshot.dnsServers, isEmpty);
      expect(snapshot.vpnActive, isFalse);
      expect(snapshot.privateDns, 'off');
    });
  });

  group('source 文案', () {
    test('四个来源各有中文，未知值不暴露枚举/英文', () {
      expect(dnsSourceLabel('upstream'), '上游解析');
      expect(dnsSourceLabel('cache'), '缓存命中');
      expect(dnsSourceLabel('rewrite'), '覆写规则');
      expect(dnsSourceLabel('blocked'), '被规则拦截');
      expect(dnsSourceLabel('error'), '查询失败');
      expect(dnsSourceLabel('whatever'), '查询失败');
    });
  });

  group('runner 守卫', () {
    test('平台异常转成可读失败结果，不冒到调用方', () async {
      // EmptyUnavailable 走的是真实默认实现：四个方法都应返回失败形态。
      const runner = UnavailableDiagnosticsRunner();

      expect((await runner.ping('example.com')).success, isFalse);
      expect((await runner.traceRoute('example.com')).success, isFalse);
      expect((await runner.lookupDns('example.com')).error, isNotNull);
      expect((await runner.networkInfo()).interfaceName, '');
    });

    test('GuardedDiagnosticsRunner 包住抛异常的实现', () async {
      final guarded = GuardedDiagnosticsRunner(const _ThrowingRunner());

      final ping = await guarded.ping('example.com', count: 2);
      expect(ping.success, isFalse);
      expect(ping.message, contains('诊断执行失败'));

      final lookup = await guarded.lookupDns('example.com');
      expect(lookup.source, 'error');
      expect(lookup.error, contains('诊断执行失败'));
    });
  });

  group('Ping 面板', () {
    /// 打开 Ping 页签。
    ///
    /// 页签文案是「Ping 测试」而不是「Ping」：逐字照抄旧版
    /// `NetworkToolMode.PING("Ping 测试")`。默认页签本来就是 ping
    /// （`NetworkToolsViewModel._toolMode` 初值），点它只是为了让用例「先切走
    /// 再回来」这类扩展不需要改桩。
    Future<void> openPing(WidgetTester tester) async {
      await tester.tap(find.text('Ping 测试'));
      await tester.pumpAndSettle();
    }

    Future<void> pumpPanel(WidgetTester tester, DiagnosticsRunner runner) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [diagnosticsRunnerProvider.overrideWithValue(runner)],
          child: const AppHost(child: ToolsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await openPing(tester);
    }

    testWidgets('成功态渲染 min/avg/max、丢包与逐条 reply', (tester) async {
      await pumpPanel(tester, _FakeRunner(pingResult: _successfulPing));

      await tester.enterText(find.byType(TextField).first, 'https://example.com/x');
      await tester.pump();
      await tester.tap(find.text('开始 Ping'));
      await tester.pumpAndSettle();

      expect(find.text('example.com'), findsOneWidget);
      expect(find.text('93.184.216.34'), findsOneWidget);
      expect(find.text('4 / 4'), findsOneWidget);
      expect(find.text('0.0 %'), findsOneWidget);
      expect(find.text('10.0 ms / 12.5 ms / 18.0 ms'), findsOneWidget);
      // 逐条 reply 在首屏之外：`PageBody` 是懒构建的 ListView，
      // `jumpTo(maxScrollExtent)` 在内容刚追加的那一帧拿到的是旧上界，滚不到位，
      // 所以这里用多次拖拽把尾部滚进视口。
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.text('目标'), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(find.text('第 1 个包'), findsOneWidget);
      expect(find.text('第 4 个包'), findsOneWidget);
      // 成功态不出现 fallback 提示。
      expect(find.textContaining('TCP 回退测量'), findsNothing);
    });

    testWidgets('失败态给错误提示，不把 0/0 当成通过', (tester) async {
      await pumpPanel(tester, _FakeRunner(pingResult: _failedPing));

      await tester.enterText(find.byType(TextField).first, 'nonexistent.invalid');
      await tester.pump();
      await tester.tap(find.text('开始 Ping'));
      await tester.pumpAndSettle();

      expect(find.textContaining('未收到任何回复'), findsOneWidget);
      expect(find.text('0 / 0'), findsOneWidget);
    });

    testWidgets('measuredWithFallback 显示 ICMP 受限提示', (tester) async {
      await pumpPanel(tester, _FakeRunner(pingResult: _fallbackPing));

      await tester.enterText(find.byType(TextField).first, '1.1.1.1');
      await tester.pump();
      await tester.tap(find.text('开始 Ping'));
      await tester.pumpAndSettle();

      expect(find.textContaining('系统 ICMP 受限'), findsOneWidget);
      expect(find.textContaining('TCP 回退测量'), findsOneWidget);
    });

    testWidgets('空目标不发起探测，直接给输入校验文案', (tester) async {
      final runner = _FakeRunner(pingResult: _successfulPing);
      await pumpPanel(tester, runner);

      await tester.tap(find.text('开始 Ping'));
      await tester.pumpAndSettle();

      expect(find.text('请输入探测目标'), findsOneWidget);
      expect(runner.pingCalls, isEmpty);
    });
  });

  group('路由追踪面板', () {
    testWidgets('渲染逐跳地址、时延与无响应跳', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diagnosticsRunnerProvider.overrideWithValue(
              _FakeRunner(
                pingResult: _successfulPing,
                traceResult: const TraceResult(
                  target: 'cdn.example.com',
                  resolvedAddress: '93.184.216.34',
                  success: true,
                  hops: [
                    TraceHop(hop: 1, address: '10.0.0.1', elapsedMs: 3),
                    TraceHop(hop: 2),
                    TraceHop(
                      hop: 3,
                      address: '93.184.216.34',
                      elapsedMs: 18,
                      reachedTarget: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
          child: const AppHost(child: ToolsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('路由追踪'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'cdn.example.com');
      await tester.pump();
      await tester.tap(find.text('开始追踪'));
      await tester.pumpAndSettle();

      expect(find.text('93.184.216.34'), findsWidgets);
      expect(find.text('3 / 最多 15'), findsOneWidget);
      // 逐跳列表在首屏之外：`PageBody` 懒构建，滚动后再断言。
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.text('目标'), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      // 第 2 跳没有应答：显示占位而不是伪造地址。
      expect(find.text('* * *'), findsOneWidget);
      expect(find.text('无响应'), findsOneWidget);
    });
  });

  group('viaTunnel 开关落盘', () {
    testWidgets('写 network_tools_settings 的 ping_via_tunnel', (tester) async {
      final store = MemoryLegacyPrefsStore();
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            legacyPrefsStoreProvider.overrideWithValue(store),
            diagnosticsRunnerProvider.overrideWithValue(
              _FakeRunner(pingResult: _successfulPing),
            ),
          ],
          child: const AppHost(child: ToolsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ping 测试'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('通过 Go 隧道解析'));
      await tester.pumpAndSettle();

      expect(
        store.read(networkToolsContainer, pingViaTunnelKey),
        isTrue,
        reason: '开关必须落到 network_tools_settings 容器的 ping_via_tunnel 键',
      );
    });
  });

  group('DNS 解析的服务器模式', () {
    /// 打开「DNS 解析」页签。
    Future<void> openDns(
      WidgetTester tester,
      _FakeRunner runner, {
      LegacyPrefsStore? store,
    }) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            if (store != null) legacyPrefsStoreProvider.overrideWithValue(store),
            diagnosticsRunnerProvider.overrideWithValue(runner),
          ],
          child: const AppHost(child: ToolsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('DNS 解析'));
      await tester.pumpAndSettle();
    }

    testWidgets('默认跟随系统：不向通道传服务器', (tester) async {
      final runner = _FakeRunner(pingResult: _successfulPing);
      await openDns(tester, runner);

      await tester.enterText(find.byType(TextField).first, 'example.com');
      await tester.pump();
      await tester.tap(find.text('开始查询'));
      await tester.pumpAndSettle();

      // 1.4.3 的 `DnsServerMode.SYSTEM`：问本机解析器，没有指定服务器。
      expect(runner.dnsLookupServers, [null]);
      // 「跟随系统」在选择器和结果行里各出现一次：结果区必须写明本次问了谁，
      // 否则用户改过输入框后会以为结果来自新填的服务器。
      expect(find.text('跟随系统'), findsNWidgets(2));
    });

    testWidgets('切到自定义并填 IP 后，服务器被传给通道', (tester) async {
      final runner = _FakeRunner(pingResult: _successfulPing);
      await openDns(tester, runner);

      // 两档服务器选择器是旧版 `DnsServerMode` 的原样，上一轮迁移时丢了。
      expect(find.text('跟随系统'), findsOneWidget);
      await tester.tap(find.text('自定义'));
      await tester.pumpAndSettle();

      // 输入框顺序：域名 → 服务器 IP。
      await tester.enterText(find.byType(TextField).first, 'example.com');
      await tester.enterText(find.byType(TextField).at(1), '1.1.1.1');
      await tester.pump();
      await tester.tap(find.text('开始查询'));
      await tester.pumpAndSettle();

      expect(
        runner.dnsLookupServers,
        ['1.1.1.1'],
        reason: '自定义服务器必须原样传到原生侧，否则测的还是系统解析器',
      );
    });

    testWidgets('自定义档留空时拦在前端，不发请求', (tester) async {
      final runner = _FakeRunner(pingResult: _successfulPing);
      await openDns(tester, runner);

      await tester.tap(find.text('自定义'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'example.com');
      await tester.pump();
      await tester.tap(find.text('开始查询'));
      await tester.pumpAndSettle();

      // 空服务器若被放过去，原生侧会当成「系统」——用户在测 A、实际测的是 B。
      expect(find.text('请输入自定义 DNS 服务器 IP'), findsOneWidget);
      expect(runner.dnsLookupServers, isEmpty);
    });

    testWidgets('开启隧道后隐藏服务器选择器（此时由隧道决定）', (tester) async {
      final runner = _FakeRunner(pingResult: _successfulPing);
      await openDns(
        tester,
        runner,
        // `dnsLookupViaTunnel` 走 prefs，预置成已开启省去一次点击。
        store: MemoryLegacyPrefsStore({
          networkToolsContainer: {dnsLookupViaTunnelKey: true},
        }),
      );

      // 隧道模式下服务器不可选，两档控件应当不存在而不是灰掉——灰掉会让人以为
      // 「启用后就能选」，实际永远不会。
      expect(find.text('自定义'), findsNothing);
      expect(find.text('跟随系统'), findsNothing);
    });
  });
}

class _ThrowingRunner implements DiagnosticsRunner {
  const _ThrowingRunner();

  @override
  Future<PingSummary> ping(
    String target, {
    int count = 4,
    int timeoutSeconds = 3,
  }) async => throw PlatformException(code: 'ping_failed', message: '断网');

  @override
  Future<TraceResult> traceRoute(String target, {int maxHops = 30}) async =>
      throw PlatformException(code: 'trace_failed');

  @override
  Future<DnsLookupResult> lookupDns(
    String domain, {
    bool viaTunnel = false,
    bool ipv4 = true,
    String? server,
  }) async => throw PlatformException(code: 'dns_failed', message: '引擎未启动');

  @override
  Future<NetworkInfoSnapshot> networkInfo() async =>
      throw PlatformException(code: 'info_failed');
}

class _FakeRunner implements DiagnosticsRunner {
  _FakeRunner({
    required this.pingResult,
    this.traceResult = const TraceResult(
      target: '',
      hops: [],
      success: false,
    ),
  });

  final PingSummary pingResult;
  final TraceResult traceResult;
  final List<String> pingCalls = [];

  /// 每次 DNS 查询收到的服务器参数，用来验证「自定义服务器」真的传到了通道。
  final List<String?> dnsLookupServers = [];

  @override
  Future<PingSummary> ping(
    String target, {
    int count = 4,
    int timeoutSeconds = 3,
  }) async {
    pingCalls.add(target);
    return pingResult;
  }

  @override
  Future<TraceResult> traceRoute(String target, {int maxHops = 30}) async =>
      traceResult;

  @override
  Future<DnsLookupResult> lookupDns(
    String domain, {
    bool viaTunnel = false,
    bool ipv4 = true,
    String? server,
  }) async {
    dnsLookupServers.add(server);
    return DnsLookupResult(
      domain: domain,
      source: 'upstream',
      answers: const [DnsAnswer(recordType: 'A', value: '1.2.3.4', ttl: 60)],
      elapsedMs: 8,
    );
  }

  @override
  Future<NetworkInfoSnapshot> networkInfo() async => const NetworkInfoSnapshot(
    interfaceName: 'wlan0',
    localIpv4: '192.168.1.20',
    privateDns: 'off',
    vpnActive: false,
  );
}

const _successfulPing = PingSummary(
  target: 'example.com',
  resolvedAddress: '93.184.216.34',
  addressFamily: 'IPv4',
  transmitted: 4,
  received: 4,
  lossPercent: 0,
  minMs: 10,
  avgMs: 12.5,
  maxMs: 18,
  jitterMs: 2.5,
  success: true,
  replies: [
    PingReply(sequence: 1, elapsedMs: 10, ttl: 57),
    PingReply(sequence: 2, elapsedMs: 12.5, ttl: 57),
    PingReply(sequence: 3, elapsedMs: 12, ttl: 57),
    PingReply(sequence: 4, elapsedMs: 18, ttl: 57),
  ],
);

const _failedPing = PingSummary(
  target: 'nonexistent.invalid',
  transmitted: 0,
  received: 0,
  lossPercent: 100,
  success: false,
  message: '未收到任何回复',
);

const _fallbackPing = PingSummary(
  target: '1.1.1.1',
  resolvedAddress: '1.1.1.1',
  addressFamily: 'IPv4',
  transmitted: 4,
  received: 4,
  lossPercent: 0,
  minMs: 3,
  avgMs: 4,
  maxMs: 5,
  success: true,
  measuredWithFallback: true,
  message: '系统 ICMP 受阻，已用 TCP/Reachable 回退测量时延',
);

import 'package:diting/data/db/app_traffic_repository.dart';
import 'package:diting/data/db/dns_query_repository.dart';
import 'package:diting/data/db/http_request_repository.dart';
import 'package:diting/pages/observability/dns_queries_page.dart';
import 'package:diting/pages/observability/requests_page.dart';
import 'package:diting/pages/traffic/traffic_page.dart';
import 'package:diting/state/observability_providers.dart';
import 'package:diting/state/traffic_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` 不在 `flutter_riverpod.dart` 的公开导出里，只在 `misc.dart`：
// provider 覆盖列表的类型标注需要它（`List<Override>`）。
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/app_host.dart';

/// 观测域三页的「真实数据上屏」探针。
///
/// 查询口径由 `legacy_repository_test.dart` 守（真 SQL、真 schema）。这里守
/// 另一类缺陷：SQL 与模型都对，但页面拿到真实行时会崩或说谎——典型的是把
/// 可空的 `authority` / `packageName` 直接插值、把 `cached`（INTEGER 0/1）
/// 当 bool 用、把连接行（`queryType = 0`）当 A 记录渲染。
///
/// **为什么覆盖 provider 而不是挂真库**：`sqflite_common_ffi` 走真实异步
/// I/O，而 widget 测试跑在 fake async 下，`Future` 永远不会被推进——表现是
/// `pumpAndSettle` 一直等到 10 分钟超时（本轮实测过，不是猜测）。因此这里
/// 注入与仓储同形的真实模型（`DnsLogRow` / `ObservedRequest` /
/// `AppTrafficDaily`），而不是再造一份 mock 类型。
void main() {
  /// 与 `AppTrafficRepository` 的 `yyyy-MM-dd` 同形。
  const today = '2026-10-20';

  final dnsRows = <DnsLogRow>[
    DnsLogRow(
      id: 1,
      timestamp: DateTime(2026, 10, 20, 13, 40).millisecondsSinceEpoch,
      queryName: 'api.github.com',
      queryType: 1,
      result: 'PASSED',
      cached: false,
      message: 'app=com.example.browser, resolved=140.82.113.6, elapsed=28ms',
      packageName: 'com.example.browser',
    ),
    // 连接行：queryType 0 + `TCP ` 前缀，旧版归「旁路」，类型标签应是「连接」。
    DnsLogRow(
      id: 2,
      timestamp: DateTime(2026, 10, 20, 13, 39).millisecondsSinceEpoch,
      queryName: 'TCP 1.1.1.1:443',
      queryType: 0,
      result: 'PASSED',
      cached: false,
      message: 'blocked_by=connection',
    ),
    // packageName 与 message 之外的列都可能为空：旧库允许，页面不能崩。
    DnsLogRow(
      id: 3,
      timestamp: DateTime(2026, 10, 20, 13, 38).millisecondsSinceEpoch,
      queryName: 'broken.example',
      queryType: 1,
      result: 'ERROR',
      cached: false,
      message: 'error=timeout elapsed=2000ms',
    ),
  ];

  final httpRecords = <HttpRequestRecord>[
    HttpRequestRecord(
      id: 1,
      timestamp: DateTime(2026, 10, 20, 13, 42).millisecondsSinceEpoch,
      packageName: 'com.example.browser',
      protocol: 'h2',
      outcome: 'allowed',
      authority: 'api.github.com',
      matchedRule: 'DOMAIN-SUFFIX,github.com',
    ),
    // authority 为 null：1.4.3 在 TLS 早期失败时写 null，页面必须落成破折号。
    HttpRequestRecord(
      id: 2,
      timestamp: DateTime(2026, 10, 20, 13, 41).millisecondsSinceEpoch,
      packageName: 'com.example.ads',
      protocol: 'http/1.1',
      outcome: 'blocked',
      matchedRule: 'RULE-SET,广告拦截',
    ),
  ];

  final trafficRows = <AppTrafficDaily>[
    const AppTrafficDaily(
      date: today,
      packageName: 'com.example.browser',
      appName: '浏览器',
      txBytes: 1000,
      rxBytes: 9000,
      updatedAt: 1,
    ),
    // appName 为空：页面要回退到包名显示，不能渲染成空行。
    const AppTrafficDaily(
      date: today,
      packageName: 'com.example.ads',
      appName: '',
      txBytes: 200,
      rxBytes: 300,
      updatedAt: 1,
    ),
  ];

  /// 请求页的合并结果，与 `_loadRequestFeed` 做的事相同：两表合并后按时间倒序。
  RequestFeed buildFeed() {
    final items = <ObservedRequest>[
      for (final row in dnsRows) ObservedRequest.fromDns(row),
      for (final record in httpRecords) ObservedRequest.fromHttp(record),
    ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return RequestFeed(items: items, hasMore: false);
  }

  /// 默认覆盖：三个页面的数据源全部换成上面的夹具。
  ///
  /// 不给参数化：每个用例要么用这套夹具，要么自己传 `providerOverrides`
  /// （空库用例需要只覆盖一两个 provider 的写法，参数化的默认值反而更难读）。
  List<Override> defaultOverrides() => [
    requestFeedProvider.overrideWith((ref) async => buildFeed()),
    dnsQueryWindowProvider.overrideWith((ref) async => dnsRows),
    dnsQueriesProvider.overrideWith((ref) async => dnsRows),
    trafficSnapshotProvider.overrideWith(
      (ref) async => TrafficSnapshot(
        rows: trafficRows,
        startDate: today,
        endDate: today,
      ),
    ),
  ];

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    List<Override>? providerOverrides,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: providerOverrides ?? defaultOverrides(),
        child: AppHost(child: page),
      ),
    );
    // `FutureProvider` 的第一个 await 在首帧之后才完成，要再推一帧。
    await tester.pump();
    await tester.pumpAndSettle();
  }

  group('请求页', () {
    testWidgets('渲染 http_request_log 与 dns_log 的合并结果', (tester) async {
      await pumpPage(tester, const RequestsPage());
      expect(tester.takeException(), isNull);

      // 两行都叫 api.github.com：一条来自 `http_request_log`（HTTPS），一条
      // 来自 `dns_log`（DNS）。并集是本页的设计（旧版 `RequestLogBatch` 也是
      // 两表合并），所以这里断言 2 条而不是 1 条——写成 `findsOneWidget` 会
      // 把「合并生效」误判成失败。
      expect(find.text('api.github.com'), findsNWidgets(2));
      // 来源 chip 必须把两行区分开，否则用户看到两行同名记录会以为重复了。
      expect(find.text('DNS'), findsWidgets);
      expect(find.text('HTTPS'), findsWidgets);
      expect(find.textContaining('共 5 条'), findsOneWidget);
      expect(find.textContaining('1 条处理失败'), findsOneWidget);
    });

    testWidgets('null authority 渲染成破折号而不是空洞', (tester) async {
      await pumpPage(tester, const RequestsPage());
      // 被拦截的那条没有 authority；破折号让「没有值」和「空字符串」可分。
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('空列表进入空态而不是报错', (tester) async {
      await pumpPage(
        tester,
        const RequestsPage(),
        providerOverrides: [
          requestFeedProvider.overrideWith(
            (ref) async => const RequestFeed.empty(),
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text('还没有请求记录'), findsOneWidget);
    });

    testWidgets('读取失败给出重试入口，而不是空白或崩溃', (tester) async {
      await pumpPage(
        tester,
        const RequestsPage(),
        providerOverrides: [
          requestFeedProvider.overrideWith(
            (ref) async => throw StateError('legacy db is locked'),
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text('无法读取请求记录'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      // 错误串要露出来：只显示「失败」不看原因，用户没法判断该不该重试。
      expect(find.textContaining('legacy db is locked'), findsOneWidget);
    });
  });

  group('DNS 页', () {
    testWidgets('渲染真实行并区分连接记录的类型标签', (tester) async {
      await pumpPage(tester, const DnsQueriesPage());
      expect(tester.takeException(), isNull);

      expect(find.text('api.github.com'), findsOneWidget);
      expect(find.text('TCP 1.1.1.1:443'), findsOneWidget);
      // `queryType = 0` 显示为「连接」而不是「A」：挡住「把连接行当普通查询
      // 渲染」的回归。
      expect(find.text('连接'), findsOneWidget);
      expect(find.text('查询总数'), findsOneWidget);
    });

    testWidgets('失败行标出状态而不是被当成成功', (tester) async {
      await pumpPage(tester, const DnsQueriesPage());
      expect(find.text('broken.example'), findsOneWidget);
      // 「失败」既在概览卡标签上，也在这一行的状态文本上。
      expect(find.text('失败'), findsWidgets);
    });

    testWidgets('空列表进入空态而不是报错', (tester) async {
      await pumpPage(
        tester,
        const DnsQueriesPage(),
        providerOverrides: [
          dnsQueryWindowProvider.overrideWith(
            (ref) async => const <DnsLogRow>[],
          ),
          dnsQueriesProvider.overrideWith((ref) async => const <DnsLogRow>[]),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text('还没有 DNS 查询'), findsOneWidget);
    });
  });

  group('流量页', () {
    testWidgets('渲染 app_traffic_daily 排行并标注曲线是示意', (tester) async {
      await pumpPage(tester, const TrafficPage());
      expect(tester.takeException(), isNull);

      expect(find.text('浏览器'), findsOneWidget);
      // appName 为空时回退到包名。
      expect(find.text('com.example.ads'), findsWidgets);
      // 曲线区必须如实标注：不能让人以为那是真实网速。
      expect(find.textContaining('会话曲线（示意）'), findsOneWidget);
      expect(find.textContaining('不反映真实网速'), findsOneWidget);
    });

    testWidgets('空列表进入空态而不是报错', (tester) async {
      await pumpPage(
        tester,
        const TrafficPage(),
        providerOverrides: [
          trafficSnapshotProvider.overrideWith(
            (ref) async => const TrafficSnapshot.empty(),
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text('这个窗口还没有流量记录'), findsOneWidget);
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:diting/data/tools/ip_quality_checker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the IP-quality checker against real HTTP responses.
///
/// `IpQualityNotifier.detect()` used to be `await Future.delayed(1000ms)` with the
/// report hard-coded (`203.0.113.24` / `AS64500` / 「风险」). These tests decide each
/// branch from an actual response, including the "only one source answered" and
/// "nothing answered" cases.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `flutter_test` blocks real sockets by default; these tests use loopback.
  setUpAll(() => HttpOverrides.global = null);

  late HttpServer server;
  late String base;
  late Map<String, String> routes;
  late Map<String, int> statuses;

  setUp(() async {
    routes = {};
    statuses = {};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      // 请求路径带参数（`/ip-api/1.2.3.4`、`/ipinfo/1.2.3.4/json`），
      // 所以按 stub 键做前缀匹配，而不是精确相等。
      final path = request.uri.path;
      String? key;
      for (final candidate in routes.keys) {
        if (path == candidate || path.startsWith('$candidate/')) {
          key = candidate;
          break;
        }
      }
      final body = key == null ? null : routes[key];
      request.response.statusCode =
          (key == null ? null : statuses[key]) ?? (body == null ? 404 : 200);
      request.response.write(body ?? 'not found');
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  /// Checker pointed at the fake server.
  IpQualityChecker checker() => IpQualityChecker(
    probeUrls: ['$base/ip'],
    ipApiUrl: '$base/ip-api',
    ipWhoIsUrl: '$base/ipwho',
    ipInfoUrl: '$base/ipinfo',
  );

  void stubAll({
    String ip = '1.2.3.4',
    String ipApi = '{"status":"success","as":"AS15169 Google LLC","isp":"Google"}',
    String ipWho = '{"success":true,"connection":{"asn":15169,"isp":"Google LLC"}}',
    String ipInfo = '{"org":"AS15169 Google LLC"}',
  }) {
    routes['/ip'] = jsonEncode({'ip': ip});
    routes['/ip-api'] = ipApi;
    routes['/ipwho'] = ipWho;
    routes['/ipinfo'] = ipInfo;
  }

  group('出口 IP', () {
    test('先取出口 IP，再拿它去查各源', () async {
      stubAll(ip: '9.9.9.9');
      final outcome = await checker().detect();
      expect(outcome, isA<IpQualitySuccess>());
      expect((outcome as IpQualitySuccess).report.ip, '9.9.9.9');
    });

    test('探测端点不可用时报失败，而不是回落到某个固定 IP', () async {
      routes['/ip'] = 'nope';
      statuses['/ip'] = 500;
      final outcome = await checker().detect();
      expect(outcome, isA<IpQualityError>());
      expect(
        (outcome as IpQualityError).failure.message,
        contains('无法获取当前出口 IP'),
      );
    });

    test('第一个探测端点不通时用下一个，而不是整次检测失败', () async {
      // 实测（emulator-5554）：`api.ipify.org` 被重置（curl 000），同服务的
      // `api64.ipify.org` 是 200。单端点实现会把「一个域名不通」报成「网络不可达」。
      stubAll(ip: '9.9.9.9');
      statuses['/ip'] = 500;
      routes['/ip2'] = jsonEncode({'ip': '8.8.8.8'});
      final outcome = await IpQualityChecker(
        probeUrls: ['$base/ip', '$base/ip2'],
        ipApiUrl: '$base/ip-api',
        ipWhoIsUrl: '$base/ipwho',
        ipInfoUrl: '$base/ipinfo',
      ).detect();
      expect(outcome, isA<IpQualitySuccess>());
      expect((outcome as IpQualitySuccess).report.ip, '8.8.8.8');
    });

    test('探测端点回一段 HTML 时不把整段当成 IP', () async {
      // 门户劫持 / 运营商插播 / 限流页都会回 200 + HTML。把 HTML 当出口 IP
      // 拿去查三个源，结果是一屏「失败」而没有一句能读懂的原因。
      stubAll();
      routes['/ip'] = '<html><body>blocked</body></html>';
      final outcome = await checker().detect();
      expect(outcome, isA<IpQualityError>());
      expect(
        (outcome as IpQualityError).failure.message,
        contains('无法获取当前出口 IP'),
      );
    });
  });

  group('多源汇总', () {
    test('全部命中时类型与级别来自真实数据', () async {
      stubAll();
      final outcome = await checker().detect() as IpQualitySuccess;
      final report = outcome.report;
      // Google 属于机房：不能报成「住宅」，否则用户以为 IP 很干净。
      expect(report.ipType, '机房');
      expect(report.level, '风险');
      expect(report.asn, 'AS15169');
      // 组织取第一个命中的非空值；ip-api 给的 isp 是 `Google`。
      expect(report.organization, 'Google');
      expect(report.hitCount, 3);
    });

    test('移动运营商被判为移动', () async {
      stubAll(
        ipApi: '{"status":"success","as":"AS9808 China Mobile","isp":"China Mobile"}',
        ipWho: '{"success":true,"connection":{"asn":9808,"isp":"China Mobile"}}',
        ipInfo: '{"org":"AS9808 China Mobile"}',
      );
      final report = (await checker().detect() as IpQualitySuccess).report;
      expect(report.ipType, '移动');
      expect(report.level, '优秀');
    });

    test('一个源失败不影响其余源出结论', () async {
      stubAll();
      statuses['/ip-api'] = 429;
      final report = (await checker().detect() as IpQualitySuccess).report;
      final ipApi = report.sources.firstWhere((s) => s.name == 'ip-api.com');
      expect(ipApi.status, '限流');
      // 另外两个照常命中。
      expect(report.hitCount, 2);
      expect(report.level, '风险');
    });

    test('全部源失败时明确报错，而不是编一份「优秀」', () async {
      routes['/ip'] = jsonEncode({'ip': '1.2.3.4'});
      for (final path in ['/ip-api', '/ipwho', '/ipinfo']) {
        routes[path] = '{"status":"fail"}';
        statuses[path] = 500;
      }
      final outcome = await checker().detect();
      expect(outcome, isA<IpQualityError>());
      expect(
        (outcome as IpQualityError).failure.message,
        contains('均未返回结果'),
      );
    });

    test('ipinfo 额度用尽被标为限流而不是失败', () async {
      stubAll(ipInfo: '{"error":{"message":"rate limited"}}');
      final report = (await checker().detect() as IpQualitySuccess).report;
      final info = report.sources.firstWhere((s) => s.name == 'ipinfo.io');
      expect(info.status, '限流');
    });
  });

  group('分类规则', () {
    /// 用单源命中跑一次，避免三源互相稀释。
    Future<String> typeFor(String isp) async {
      stubAll(
        ipApi: jsonEncode({'status': 'success', 'as': 'AS1 $isp', 'isp': isp}),
        // 让另外两个源给同样的判断，确保汇总取到的就是被测文本的结论。
        ipWho: jsonEncode({
          'success': true,
          'connection': {'asn': 1, 'isp': isp},
        }),
        ipInfo: jsonEncode({'org': 'AS1 $isp'}),
      );
      return (await checker().detect() as IpQualitySuccess).report.ipType;
    }

    test('云厂商关键词判为机房', () async {
      expect(await typeFor('Amazon.com Inc.'), '机房');
      expect(await typeFor('Cloudflare Inc'), '机房');
      expect(await typeFor('DigitalOcean LLC'), '机房');
    });

    test('移动运营商判为移动', () async {
      expect(await typeFor('China Mobile'), '移动');
      expect(await typeFor('T-Mobile USA'), '移动');
    });

    test('未知组织兜底为商业，不默认成住宅', () async {
      // 把机房误标成住宅会让用户以为 IP 很干净，这是更危险的错误方向。
      expect(await typeFor('Some Random ISP'), '商业');
    });
  });
}

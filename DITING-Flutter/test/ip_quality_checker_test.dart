import 'dart:convert';
import 'dart:io';

import 'package:diting/data/tools/ip_quality_checker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the checker against real HTTP replies, including the partial and empty cases
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  IpQualityChecker checker() => IpQualityChecker(
    probeUrls: ['$base/ip'],
    ipApiUrl: '$base/ip-api',
    ipWhoIsUrl: '$base/ipwho',
    ipInfoUrl: '$base/ipinfo',
  );

  void stubAll({
    String ip = '1.2.3.4',
    String ipApi =
        '{"status":"success","as":"AS15169 Google LLC","isp":"Google"}',
    String ipWho =
        '{"success":true,"connection":{"asn":15169,"isp":"Google LLC"}}',
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
      // `api.ipify.org` was reset while `api64.ipify.org` answered 200: one endpoint would report
      // down
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
      // Captive portals answer 200 with HTML; reading that as the egress IP fails every source
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
      expect(report.ipType, '机房');
      expect(report.level, '风险');
      expect(report.asn, 'AS15169');
      expect(report.organization, 'Google');
      expect(report.hitCount, 3);
    });

    test('移动运营商被判为移动', () async {
      stubAll(
        ipApi: '{"status":"success","as":"AS9808 China Mobile","isp":"China Mobile"}',
        ipWho:
            '{"success":true,"connection":{"asn":9808,"isp":"China Mobile"}}',
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
      expect((outcome as IpQualityError).failure.message, contains('均未返回结果'));
    });

    test('ipinfo 额度用尽被标为限流而不是失败', () async {
      stubAll(ipInfo: '{"error":{"message":"rate limited"}}');
      final report = (await checker().detect() as IpQualitySuccess).report;
      final info = report.sources.firstWhere((s) => s.name == 'ipinfo.io');
      expect(info.status, '限流');
    });
  });

  group('分类规则', () {
    Future<String> typeFor(String isp) async {
      stubAll(
        ipApi: jsonEncode({'status': 'success', 'as': 'AS1 $isp', 'isp': isp}),
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
      expect(await typeFor('Some Random ISP'), '商业');
    });
  });
}

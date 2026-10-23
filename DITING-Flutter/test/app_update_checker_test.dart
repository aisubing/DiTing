import 'dart:convert';
import 'dart:io';

import 'package:diting/data/update/app_update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the update check against a real HTTP server and 1.4.3's parsing rules.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `flutter_test` installs an HttpOverrides answering 400; this file uses a loopback server
  setUpAll(() => HttpOverrides.global = null);

  late HttpServer server;
  late String url;

  /// Status and body the fake GitHub endpoint should return.
  late int status;
  late String body;
  late List<String?> seenUserAgents;

  setUp(() async {
    status = 200;
    body = '{}';
    seenUserAgents = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = 'http://127.0.0.1:${server.port}/releases/latest';
    server.listen((request) async {
      seenUserAgents.add(request.headers.value(HttpHeaders.userAgentHeader));
      await utf8.decoder.bind(request).join();
      request.response.statusCode = status;
      request.response.write(body);
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  AppUpdateChecker checker() => AppUpdateChecker(releaseUrl: url);

  String release({
    required String tag,
    String? assetName,
    String? downloadUrl,
    String notes = '',
    bool withAssets = true,
  }) => jsonEncode({
    'tag_name': tag,
    'body': notes,
    'assets': withAssets
        ? [
            {
              'name': assetName ?? 'diting-$tag-arm64-v8a.apk',
              'browser_download_url':
                  downloadUrl ?? 'https://example.test/diting-$tag.apk',
            },
          ]
        : <Object>[],
  });

  group('版本比较（旧版 isNewerVersion）', () {
    test('逐段整数比较，不是字符串比较', () {
      // String comparison puts "1.4.10" below "1.4.9".
      expect(AppUpdateChecker.isNewerVersion('1.4.10', '1.4.9'), isTrue);
      expect(AppUpdateChecker.isNewerVersion('1.4.9', '1.4.10'), isFalse);
    });

    test('v 前缀与 -suffix 都被忽略', () {
      expect(AppUpdateChecker.isNewerVersion('v1.5.0', '1.4.4'), isTrue);
      expect(AppUpdateChecker.isNewerVersion('v1.5.0-beta', '1.4.4'), isTrue);
    });

    test('段数不同时缺失段按 0 处理', () {
      expect(AppUpdateChecker.isNewerVersion('1.5', '1.4.4'), isTrue);
      expect(AppUpdateChecker.isNewerVersion('1.4.4.1', '1.4.4'), isTrue);
      expect(AppUpdateChecker.isNewerVersion('1.4', '1.4.0'), isFalse);
    });

    test('相同版本不算更新', () {
      expect(AppUpdateChecker.isNewerVersion('1.4.4', '1.4.4'), isFalse);
      expect(AppUpdateChecker.isNewerVersion('v1.4.4', '1.4.4'), isFalse);
    });

    test('看不懂的版本号不当作更新', () {
      // Better to report no update than to treat an unparseable tag as one.
      expect(AppUpdateChecker.isNewerVersion('latest', '1.4.4'), isFalse);
      expect(AppUpdateChecker.isNewerVersion('1.4.x', '1.4.4'), isFalse);
      expect(AppUpdateChecker.isNewerVersion('', '1.4.4'), isFalse);
    });
  });

  group('解析', () {
    test('更高版本返回 available，带版本/地址/说明', () {
      final result = AppUpdateChecker.parseLatestRelease(
        release(
          tag: 'v1.4.5',
          assetName: 'DITING-1.4.5-arm64-v8a.apk',
          downloadUrl: 'https://example.test/a.apk',
          notes: '- 修复若干问题',
        ),
        '1.4.4',
      );
      expect(result.hasUpdate, isTrue);
      final info = result.info!;
      expect(info.version, '1.4.5');
      expect(info.fileName, 'DITING-1.4.5-arm64-v8a.apk');
      expect(info.downloadUrl, 'https://example.test/a.apk');
      expect(info.releaseNotes, '- 修复若干问题');
    });

    test('相同或更低版本返回 upToDate', () {
      final same = AppUpdateChecker.parseLatestRelease(
        release(tag: 'v1.4.4'),
        '1.4.4',
      );
      expect(same.hasUpdate, isFalse);
      expect(same.failed, isFalse);
      expect(same.currentVersion, '1.4.4');

      final older = AppUpdateChecker.parseLatestRelease(
        release(tag: 'v1.4.3'),
        '1.4.4',
      );
      expect(older.hasUpdate, isFalse);
      expect(older.failed, isFalse);
    });

    test('优先挑 arm64-v8a 资产', () {
      final payload = jsonEncode({
        'tag_name': 'v2.0.0',
        'assets': [
          {
            'name': 'diting-universal.apk',
            'browser_download_url': 'https://example.test/u.apk',
          },
          {
            'name': 'diting-arm64-v8a.apk',
            'browser_download_url': 'https://example.test/a.apk',
          },
        ],
      });
      final result = AppUpdateChecker.parseLatestRelease(payload, '1.0.0');
      expect(result.info!.downloadUrl, 'https://example.test/a.apk');
    });

    test('没有 arm64 资产时回落到任意 apk', () {
      final payload = jsonEncode({
        'tag_name': 'v2.0.0',
        'assets': [
          {
            'name': 'notes.txt',
            'browser_download_url': 'https://example.test/n.txt',
          },
          {
            'name': 'diting-universal.apk',
            'browser_download_url': 'https://example.test/u.apk',
          },
        ],
      });
      final result = AppUpdateChecker.parseLatestRelease(payload, '1.0.0');
      expect(result.info!.fileName, 'diting-universal.apk');
    });

    test('没有 apk 资产时报错，而不是猜一个地址', () {
      final payload = jsonEncode({
        'tag_name': 'v2.0.0',
        'assets': [
          {
            'name': 'source.zip',
            'browser_download_url': 'https://example.test/s.zip',
          },
        ],
      });
      final result = AppUpdateChecker.parseLatestRelease(payload, '1.0.0');
      expect(result.hasUpdate, isFalse);
      expect(result.failed, isTrue);
      expect(result.error, contains('APK'));
    });

    test('缺 tag_name 时报错', () {
      final result = AppUpdateChecker.parseLatestRelease(
        jsonEncode({'assets': <Object>[]}),
        '1.0.0',
      );
      expect(result.failed, isTrue);
      expect(result.error, contains('tag_name'));
    });

    test('非法 JSON 报错而不是红屏', () {
      final result = AppUpdateChecker.parseLatestRelease('not json', '1.0.0');
      expect(result.failed, isTrue);
      expect(result.error, contains('JSON'));
    });

    test('download_url 为空时报错', () {
      final payload = jsonEncode({
        'tag_name': 'v2.0.0',
        'assets': [
          {'name': 'diting.apk', 'browser_download_url': '  '},
        ],
      });
      final result = AppUpdateChecker.parseLatestRelease(payload, '1.0.0');
      expect(result.failed, isTrue);
      expect(result.error, contains('下载地址'));
    });
  });

  group('HTTP 层', () {
    test('带 User-Agent（GitHub 对无 UA 的请求返回 403）', () async {
      body = release(tag: 'v1.4.5');
      await checker().check('1.4.4');
      expect(seenUserAgents.single, isNotNull);
      expect(seenUserAgents.single, contains('DITING'));
    });

    test('200 + 更高版本 → available', () async {
      body = release(tag: 'v9.9.9');
      final result = await checker().check('1.4.4');
      expect(result.hasUpdate, isTrue);
      expect(result.info!.version, '9.9.9');
    });

    test('200 + 同版本 → upToDate', () async {
      body = release(tag: 'v1.4.4');
      final result = await checker().check('1.4.4');
      expect(result.failed, isFalse);
      expect(result.hasUpdate, isFalse);
    });

    test('限流的 403 说清是限流，而不是笼统「返回 403」', () async {
      status = 403;
      body = '{"message":"API rate limit exceeded for 1.2.3.4."}';
      final result = await checker().check('1.4.4');
      expect(result.failed, isTrue);
      expect(result.error, contains('限流'));
    });

    test('非限流的 403 保留状态码', () async {
      status = 403;
      body = '{"message":"forbidden"}';
      final result = await checker().check('1.4.4');
      expect(result.failed, isTrue);
      expect(result.error, contains('403'));
    });

    test('404 指出版本库或发布页不存在', () async {
      status = 404;
      body = '{"message":"Not Found"}';
      final result = await checker().check('1.4.4');
      expect(result.failed, isTrue);
      expect(result.error, contains('404'));
    });

    test('服务器不可达时报告无法连接', () async {
      final result = await AppUpdateChecker(
        releaseUrl: 'http://127.0.0.1:1/releases/latest',
      ).check('1.4.4');
      expect(result.failed, isTrue);
      expect(result.error, contains('无法连接'));
    });
  });
}

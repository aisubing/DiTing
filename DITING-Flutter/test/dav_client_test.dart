import 'dart:convert';
import 'dart:io';

import 'package:diting/data/backup/dav_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the WebDAV client against a real HTTP server: every branch is decided by an actual reply
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `flutter_test` installs `HttpOverrides.global` answering 400; this file uses a loopback server
  setUpAll(() => HttpOverrides.global = null);

  late HttpServer server;
  late String baseUrl;

  const goodAuth = 'diting:secret';

  late List<({String method, String path, bool authorized})> requests;

  late Set<String> existingDirs;

  late Map<String, String> files;

  setUp(() async {
    requests = [];
    existingDirs = {};
    files = {};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';

    server.listen((request) async {
      final auth = request.headers.value(HttpHeaders.authorizationHeader);
      final expected = 'Basic ${base64Encode(utf8.encode(goodAuth))}';
      final authorized = auth == expected;
      requests.add((
        method: request.method,
        path: request.uri.path,
        authorized: authorized,
      ));
      // Drain the body before responding, or the unread body keeps the socket open forever
      final body = await utf8.decoder.bind(request).join();
      if (!authorized) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.headers.set(
          HttpHeaders.wwwAuthenticateHeader,
          'Basic realm="test"',
        );
        await request.response.close();
        return;
      }
      final path = request.uri.path;
      switch (request.method) {
        case 'PROPFIND':
          if (existingDirs.contains(path)) {
            request.response.statusCode = 207;
            request.response.write(
              '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:"/>',
            );
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
        case 'MKCOL':
          existingDirs.add(path);
          request.response.statusCode = HttpStatus.created;
        case 'PUT':
          files[path] = body;
          request.response.statusCode = HttpStatus.ok;
        case 'GET':
          final stored = files[path];
          if (stored == null) {
            request.response.statusCode = HttpStatus.notFound;
          } else {
            request.response.statusCode = HttpStatus.ok;
            request.response.write(stored);
          }
        default:
          request.response.statusCode = HttpStatus.methodNotAllowed;
      }
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  DavCredentials credentials({String password = 'secret', String? path}) =>
      DavCredentials(
        server: baseUrl,
        username: 'diting',
        password: password,
        path: path ?? '/diting/',
      );

  group('probe', () {
    test('目录已存在时报告未创建，且真的发了 PROPFIND', () async {
      existingDirs.add('/diting/');
      final result = await const DavClient().probe(credentials());

      expect(result.succeeded, isTrue);
      expect(result.created, isFalse);
      expect(requests.single.method, 'PROPFIND');
      expect(requests.single.authorized, isTrue);
    });

    test('目录不存在时自动 MKCOL 并报告已创建', () async {
      final result = await const DavClient().probe(credentials());

      expect(result.succeeded, isTrue);
      expect(result.created, isTrue);
      expect(requests.map((item) => item.method), ['PROPFIND', 'MKCOL']);
      expect(existingDirs, contains('/diting/'));
    });

    test('密码错误时报 401 而不是「连接成功」', () async {
      final result = await const DavClient().probe(
        credentials(password: 'wrong'),
      );

      expect(result.succeeded, isFalse);
      expect(result.statusCode, 401);
      expect(result.error, contains('认证失败'));
    });

    test('服务器不可达时报告无法连接', () async {
      // Nothing listens on port 1: the shape of a nonexistent address.
      final result = await const DavClient().probe(
        const DavCredentials(
          server: 'http://127.0.0.1:1',
          username: 'diting',
          password: 'secret',
          path: '/diting/',
        ),
      );
      expect(result.succeeded, isFalse);
      expect(result.error, contains('无法连接'));
    });

    test('远端路径缺前导/尾部斜杠会被补齐', () async {
      existingDirs.add('/dav/sub/');
      final result = await const DavClient().probe(
        credentials(path: 'dav/sub'),
      );

      expect(result.succeeded, isTrue);
      expect(requests.single.path, '/dav/sub/');
    });
  });

  group('上传与下载', () {
    test('PUT 写入真实内容，GET 取回同一份', () async {
      final client = const DavClient();
      final payload = '{"format":"diting-backup","version":1}';

      final uploaded = await client.putText(
        credentials(),
        name: 'diting-config.json',
        content: payload,
      );
      expect(uploaded.succeeded, isTrue);
      expect(files['/diting/diting-config.json'], payload);

      final downloaded = await client.getText(
        credentials(),
        name: 'diting-config.json',
      );
      expect(downloaded, payload);
    });

    test('云端文件不存在时返回 null 而不是抛错', () async {
      final result = await const DavClient().getText(
        credentials(),
        name: 'missing.json',
      );
      expect(result, isNull);
    });

    test('密码错误时 PUT 失败并带状态码', () async {
      final result = await const DavClient().putText(
        credentials(password: 'wrong'),
        name: 'x.json',
        content: '{}',
      );
      expect(result.succeeded, isFalse);
      expect(result.statusCode, 401);
    });
  });

  group('凭据', () {
    test('基本认证头按 username:password 编码', () {
      final header = credentials().basicAuthHeader;
      final decoded = utf8.decode(
        base64Decode(header.replaceFirst('Basic ', '')),
      );
      expect(decoded, 'diting:secret');
    });

    test('目录地址拼接带尾部斜杠，文件名在其下', () {
      final normalized = credentials(path: '/a/b').normalized();
      expect(normalized.directoryUrl, '$baseUrl/a/b/');
      expect(normalized.fileUrl('x.json'), '$baseUrl/a/b/x.json');
    });
  });
}

/// Minimal WebDAV client: PROPFIND probe, MKCOL create, PUT upload, GET download.
///
/// Credentials stay in memory and request headers only; they are never persisted.
library;

import 'dart:convert';
import 'dart:io';

class DavCredentials {
  const DavCredentials({
    required this.server,
    required this.username,
    required this.password,
    required this.path,
  });

  /// Server base URL, e.g. `https://dav.example.com`.
  final String server;
  final String username;
  final String password;

  /// Target directory, always starting and ending with `/`.
  final String path;

  DavCredentials normalized() => DavCredentials(
    server: server.trim().replaceAll(RegExp(r'/+$'), ''),
    username: username.trim(),
    password: password,
    path: _normalizePath(path),
  );

  /// A missing leading slash makes PROPFIND hit the parent, so normalize both ends.
  static String _normalizePath(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '/diting/';
    if (!value.startsWith('/')) value = '/$value';
    if (!value.endsWith('/')) value = '$value/';
    return value;
  }

  String get directoryUrl => '$server$path';

  String fileUrl(String name) => '$server$path$name';

  /// The password is never logged or persisted.
  String get basicAuthHeader {
    final raw = '$username:$password';
    return 'Basic ${base64Encode(utf8.encode(raw))}';
  }
}

class DavProbeResult {
  const DavProbeResult.ok({required this.created})
    : error = null,
      statusCode = null;

  const DavProbeResult.failed(String this.error, {this.statusCode})
    : created = false;

  final bool created;

  /// Failure reason; shown to the user verbatim.
  final String? error;

  /// HTTP status, surfaced in the message to make it actionable.
  final int? statusCode;

  bool get succeeded => error == null;
}

class DavClient {
  const DavClient({this.timeout = const Duration(seconds: 20)});

  /// Per-request timeout. Self-hosted WebDAV answers quickly on a LAN; past
  /// 20s the server is likely unreachable.
  final Duration timeout;

  /// PROPFIND the directory, creating it with MKCOL if missing.
  Future<DavProbeResult> probe(DavCredentials rawCredentials) async {
    final credentials = rawCredentials.normalized();
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final status = await _propfind(client, credentials);
      if (status == 207 || status == 200) {
        return const DavProbeResult.ok(created: false);
      }
      if (status == 404) {
        // A missing directory is normal on first use; failing to create it is not.
        final created = await _mkcol(client, credentials);
        if (created) return const DavProbeResult.ok(created: true);
        return const DavProbeResult.failed(
          '服务器可达但无法创建目录，请检查账号是否具备写入权限',
        );
      }
      return DavProbeResult.failed(
        _statusMessage(status),
        statusCode: status,
      );
    } on SocketException catch (error) {
      // Unreachable address, DNS failure and closed port look the same to users.
      return DavProbeResult.failed('无法连接到服务器：${error.message}');
    } on HandshakeException {
      return const DavProbeResult.failed(
        'TLS 握手失败：服务器证书不被信任（自签证书需在系统里安装）',
      );
    } on HttpException {
      return DavProbeResult.failed('HTTP 请求失败，请检查服务器是否支持 WebDAV');
    } finally {
      client.close(force: true);
    }
  }

  /// Upload a text file with `PUT`.
  Future<DavProbeResult> putText(
    DavCredentials rawCredentials, {
    required String name,
    required String content,
  }) async {
    final credentials = rawCredentials.normalized();
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client
          .putUrl(Uri.parse(credentials.fileUrl(name)))
          .timeout(timeout);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        credentials.basicAuthHeader,
      );
      request.headers.contentType = ContentType(
        'application',
        'json',
        charset: 'utf-8',
      );
      final bytes = utf8.encode(content);
      request.headers.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close().timeout(timeout);
      await response.drain<void>();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const DavProbeResult.ok(created: false);
      }
      return DavProbeResult.failed(
        _statusMessage(response.statusCode),
        statusCode: response.statusCode,
      );
    } on SocketException catch (error) {
      return DavProbeResult.failed('上传失败：无法连接服务器（${error.message}）');
    } on HandshakeException {
      return const DavProbeResult.failed('上传失败：TLS 证书不被信任');
    } finally {
      client.close(force: true);
    }
  }

  /// Download a text file; returns null when it does not exist.
  Future<String?> getText(
    DavCredentials rawCredentials, {
    required String name,
  }) async {
    final credentials = rawCredentials.normalized();
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client
          .getUrl(Uri.parse(credentials.fileUrl(name)))
          .timeout(timeout);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        credentials.basicAuthHeader,
      );
      final response = await request.close().timeout(timeout);
      if (response.statusCode == 404) {
        await response.drain<void>();
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw HttpException('下载失败（HTTP ${response.statusCode}）');
      }
      return await response.transform(utf8.decoder).join().timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }

  Future<int> _propfind(HttpClient client, DavCredentials credentials) async {
    final request = await client
        .openUrl('PROPFIND', Uri.parse(credentials.directoryUrl))
        .timeout(timeout);
    request.headers.set(
      HttpHeaders.authorizationHeader,
      credentials.basicAuthHeader,
    );
    // Depth 0 asks for this resource only; no child listing is needed.
    request.headers.set('Depth', '0');
    request.headers.contentType = ContentType('application', 'xml');
    final body = utf8.encode(
      '<?xml version="1.0" encoding="utf-8"?>'
      '<d:propfind xmlns:d="DAV:"><d:prop>'
      '<d:resourcetype/><d:getlastmodified/>'
      '</d:prop></d:propfind>',
    );
    request.headers.contentLength = body.length;
    request.add(body);
    final response = await request.close().timeout(timeout);
    await response.drain<void>();
    return response.statusCode;
  }

  Future<bool> _mkcol(HttpClient client, DavCredentials credentials) async {
    final request = await client
        .openUrl('MKCOL', Uri.parse(credentials.directoryUrl))
        .timeout(timeout);
    request.headers.set(
      HttpHeaders.authorizationHeader,
      credentials.basicAuthHeader,
    );
    request.headers.contentLength = 0;
    final response = await request.close().timeout(timeout);
    await response.drain<void>();
    // 201 means created; 405 means it already exists, which is fine under races.
    return response.statusCode == 201 || response.statusCode == 405;
  }

  /// Translate a status code into an actionable message.
  String _statusMessage(int status) => switch (status) {
    401 => '认证失败：用户名或密码不正确',
    403 => '服务器拒绝访问：该账号没有读写此目录的权限',
    404 => '服务器上找不到该目录',
    405 => '服务器不允许该操作（可能未启用 WebDAV）',
    409 => '目标目录不存在，无法写入',
    507 => '服务器存储空间不足',
    >= 500 => '服务器内部错误（HTTP $status）',
    _ => '服务器返回 HTTP $status',
  };
}

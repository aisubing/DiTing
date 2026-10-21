/// 一个够用的 WebDAV 客户端：PROPFIND 探测、MKCOL 建目录、PUT 上传、GET 下载。
///
/// ## 为什么自己写而不用包
///
/// 需要的只有四个动词，且必须在 Android 上跑通自签证书/明文 HTTP 的组合。引入一个
/// WebDAV 包会带来它自己的 XML 解析器、状态机和依赖树；而这里真正要处理的只有
/// 「基本认证 + 一条 XML + 四个状态码」。
///
/// ## 旧版没有这个功能
///
/// 1.4.3 里没有任何 WebDAV 代码（`config_transfer_webdav` 是本仓新加的能力，注释里
/// 写明「用户要求保留」）。所以这里没有可照抄的实现，行为按 RFC 4918 中真正用到的
/// 那一小部分定义，并在失败时如实说明是哪个环节失败。
///
/// ## 凭据处理
///
/// 密码只存在于 [DavCredentials] 的内存实例和单次请求头里，**不落盘**：备份文件本身
/// 已经明确不含凭据，把密码写进 prefs 会让「不含凭据」这个承诺失效。
library;

import 'dart:convert';
import 'dart:io';

/// 一次成功的连接需要的最小凭据集合。
class DavCredentials {
  const DavCredentials({
    required this.server,
    required this.username,
    required this.password,
    required this.path,
  });

  /// 形如 `https://dav.example.com` 或 `http://192.168.1.10:5005`。
  final String server;
  final String username;
  final String password;

  /// 目标目录，形如 `/diting/`；始终以 `/` 结尾。
  final String path;

  DavCredentials normalized() => DavCredentials(
    server: server.trim().replaceAll(RegExp(r'/+$'), ''),
    username: username.trim(),
    password: password,
    path: _normalizePath(path),
  );

  /// 目录缺前导斜杠、缺尾部斜杠都会让 PROPFIND 打到上一级，这里统一补齐。
  static String _normalizePath(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '/diting/';
    if (!value.startsWith('/')) value = '/$value';
    if (!value.endsWith('/')) value = '$value/';
    return value;
  }

  /// 目录的绝对地址。
  String get directoryUrl => '$server$path';

  /// 目录下一个文件的绝对地址。
  String fileUrl(String name) => '$server$path$name';

  /// 把基本认证头算出来。密码不写日志、不进预置。
  String get basicAuthHeader {
    final raw = '$username:$password';
    return 'Basic ${base64Encode(utf8.encode(raw))}';
  }
}

/// 连接测试的结果。
class DavProbeResult {
  const DavProbeResult.ok({required this.created})
    : error = null,
      statusCode = null;

  const DavProbeResult.failed(String this.error, {this.statusCode})
    : created = false;

  final bool created;

  /// 失败原因，直接作为用户可见文案。
  final String? error;

  /// HTTP 状态码，用于在提示里带上（「401 未授权」比「连接失败」有用得多）。
  final int? statusCode;

  bool get succeeded => error == null;
}

/// WebDAV 客户端。
class DavClient {
  const DavClient({this.timeout = const Duration(seconds: 20)});

  /// 单次请求超时。
  ///
  /// 20 秒是「服务器关机」与「服务器慢」之间的分界：自建 WebDAV 通常局域网内响应，
  /// 超过 20 秒基本可以断定不可达，而用户已经盯着屏幕等。
  final Duration timeout;

  /// 探测连接：先 PROPFIND 目录，不存在则 MKCOL 建一个。
  Future<DavProbeResult> probe(DavCredentials rawCredentials) async {
    final credentials = rawCredentials.normalized();
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final status = await _propfind(client, credentials);
      if (status == 207 || status == 200) {
        return const DavProbeResult.ok(created: false);
      }
      if (status == 404) {
        // 目录不存在是正常的首次使用。建不出来才是错误。
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
      // 地址不可达 / DNS 失败 / 端口没开，三者对用户是同一件事。
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

  /// 上传一份文本文件（`PUT`）。
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

  /// 下载一份文本文件；文件不存在返回 `null`（不是错误）。
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

  /// `PROPFIND`，返回状态码。
  Future<int> _propfind(HttpClient client, DavCredentials credentials) async {
    final request = await client
        .openUrl('PROPFIND', Uri.parse(credentials.directoryUrl))
        .timeout(timeout);
    request.headers.set(
      HttpHeaders.authorizationHeader,
      credentials.basicAuthHeader,
    );
    // Depth: 0 表示「只要这个资源本身」。要子项列表用 1，但连接测试不需要。
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

  /// `MKCOL`，返回是否建成。
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
    // 201 是建成；405 表示已存在（并发下不算失败）。
    return response.statusCode == 201 || response.statusCode == 405;
  }

  /// 把状态码翻成用户能采取行动的话。
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

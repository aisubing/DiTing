/// Checks GitHub Releases and parses the latest version: drop the `v`, cut at `-`, compare as
/// integers; APK assets prefer `arm64-v8a`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:diting/data/http/request_user_agent.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.fileName,
    required this.releaseNotes,
  });

  final String version;
  final String downloadUrl;
  final String fileName;

  final String releaseNotes;
}

class UpdateCheckResult {
  const UpdateCheckResult.upToDate({required this.currentVersion})
    : info = null,
      error = null;

  const UpdateCheckResult.available(
    UpdateInfo this.info, {
    required this.currentVersion,
  }) : error = null;

  const UpdateCheckResult.failed(String this.error)
    : info = null,
      currentVersion = null;

  final UpdateInfo? info;

  final String? currentVersion;

  final String? error;

  bool get failed => error != null;
  bool get hasUpdate => info != null;
}

class AppUpdateChecker {
  const AppUpdateChecker({
    this.releaseUrl = defaultReleaseUrl,
    this.timeout = const Duration(seconds: 15),
    this.userAgent = appFallbackUserAgent,
  });

  /// The legacy `AppUpdateManager.RELEASE_URL`; the compile-time override points at a mirror or a
  /// local fake server.
  static const defaultReleaseUrl = String.fromEnvironment(
    'DITING_RELEASE_URL',
    defaultValue:
        'https://api.github.com/repos/haoze-evoluling/DITING/releases/latest',
  );

  final String releaseUrl;
  final Duration timeout;

  /// `/config/user-agents` override; GitHub 403s a request without one.
  final String userAgent;

  Future<UpdateCheckResult> check(String currentVersion) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client
          .getUrl(Uri.parse(releaseUrl))
          .timeout(timeout);
      // GitHub 403s a request without a User-Agent; `Accept` selects the schema.
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      final response = await request.close().timeout(timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      if (response.statusCode != 200) {
        return UpdateCheckResult.failed(
          _statusMessage(response.statusCode, body),
        );
      }
      return parseLatestRelease(body, currentVersion);
    } on SocketException catch (error) {
      return UpdateCheckResult.failed('检查更新失败：无法连接（${error.message}）');
    } on HandshakeException {
      return const UpdateCheckResult.failed('检查更新失败：TLS 证书校验不通过');
    } on FormatException {
      return const UpdateCheckResult.failed('检查更新失败：服务器返回的内容不是合法 JSON');
    } finally {
      client.close(force: true);
    }
  }

  /// Turns a non-200 into something the user can act on. A GitHub 403 means rate limiting or a real
  /// refusal; the body `message` tells them apart.
  static String _statusMessage(int status, String body) {
    if (status == 403 && body.contains('rate limit')) {
      return '检查更新失败：GitHub 接口限流（未认证请求每小时 60 次），'
          '请稍后再试或直接访问项目发布页';
    }
    return switch (status) {
      403 => '检查更新失败：GitHub 拒绝访问（HTTP 403）',
      404 => '检查更新失败：仓库或发布页不存在（HTTP 404）',
      >= 500 => '检查更新失败：GitHub 服务异常（HTTP $status）',
      _ => '检查更新失败：GitHub 返回 $status',
    };
  }

  /// Parses a `releases/latest` body. Missing fields are tolerated, but a missing version is an
  /// explicit error rather than "already latest".
  static UpdateCheckResult parseLatestRelease(
    String payload,
    String currentVersion,
  ) {
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return const UpdateCheckResult.failed('检查更新失败：响应不是合法 JSON');
    }
    if (decoded is! Map) {
      return const UpdateCheckResult.failed('检查更新失败：响应格式不符合预期');
    }
    final remoteVersion = '${decoded['tag_name'] ?? ''}'.trim();
    if (remoteVersion.isEmpty) {
      return const UpdateCheckResult.failed('检查更新失败：最新版本缺少 tag_name');
    }
    if (!isNewerVersion(remoteVersion, currentVersion)) {
      return UpdateCheckResult.upToDate(currentVersion: currentVersion);
    }

    final asset = _pickAsset(decoded['assets']);
    if (asset == null) {
      return const UpdateCheckResult.failed('最新版本未提供 Android APK');
    }
    final downloadUrl = '${asset['browser_download_url'] ?? ''}'.trim();
    if (downloadUrl.isEmpty) {
      return const UpdateCheckResult.failed('更新包下载地址无效');
    }
    final name = '${asset['name'] ?? ''}'.trim();
    return UpdateCheckResult.available(
      UpdateInfo(
        version: remoteVersion.replaceFirst(RegExp(r'^v'), ''),
        downloadUrl: downloadUrl,
        fileName: name.isEmpty ? '谛听-$remoteVersion.apk' : name,
        releaseNotes: '${decoded['body'] ?? ''}'.trim(),
      ),
      currentVersion: currentVersion,
    );
  }

  static Map<Object?, Object?>? _pickAsset(Object? rawAssets) {
    if (rawAssets is! List) return null;
    final assets = [
      for (final item in rawAssets)
        if (item is Map) Map<Object?, Object?>.from(item),
    ];
    bool isApk(Map<Object?, Object?> asset) =>
        '${asset['name'] ?? ''}'.toLowerCase().endsWith('.apk');

    for (final asset in assets) {
      if (isApk(asset) &&
          '${asset['name'] ?? ''}'.toLowerCase().contains('arm64-v8a')) {
        return asset;
      }
    }
    for (final asset in assets) {
      if (isApk(asset)) return asset;
    }
    return null;
  }

  /// Compares versions component by component as integers. Anything unparseable counts as "not
  /// newer".
  static bool isNewerVersion(String remote, String current) {
    List<int>? components(String value) {
      final normalized = value
          .trim()
          .replaceFirst(RegExp(r'^v'), '')
          .split('-')
          .first;
      if (normalized.isEmpty) return null;
      final parts = <int>[];
      for (final part in normalized.split('.')) {
        final parsed = int.tryParse(part);
        if (parsed == null) return null;
        parts.add(parsed);
      }
      return parts;
    }

    final remoteParts = components(remote);
    final currentParts = components(current);
    if (remoteParts == null || currentParts == null) return false;
    final length = remoteParts.length > currentParts.length
        ? remoteParts.length
        : currentParts.length;
    for (var index = 0; index < length; index++) {
      final remoteValue = index < remoteParts.length ? remoteParts[index] : 0;
      final currentValue = index < currentParts.length
          ? currentParts[index]
          : 0;
      if (remoteValue != currentValue) return remoteValue > currentValue;
    }
    return false;
  }
}

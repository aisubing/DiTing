/// 应用更新：真实检查 GitHub Releases，并解析最新版本。
///
/// ## 上一轮是什么
///
/// `UpdateNotifier.check()` 是 `await Future.delayed(...)` 之后直接跳到
/// `UpdateStage.available`——**永远有更新**，与服务器无关。这类占位最坏的地方在于
/// 它会引导用户去下载一个不存在的包。
///
/// ## 端点与解析规则照抄 1.4.3
///
/// `AppUpdateManager.kt`：`https://api.github.com/repos/haoze-evoluling/DITING/releases/latest`，
/// 带 `Accept: application/vnd.github+json` 与 `User-Agent`（GitHub 对无 UA 的请求返回
/// 403）。版本比较、APK 资产挑选、错误文案全部沿用旧版：
///
/// - 版本号去掉 `v` 前缀、取 `-` 之前的部分，按 `.` 拆成整数逐段比较；
///   解析不出整数就当「不是更新」（旧版 `isNewerVersion` 返回 false）。
/// - 优先挑文件名同时含 `.apk` 与 `arm64-v8a` 的资产，其次任意 `.apk`。
///   挑不到就报错，**不猜**下载地址。
library;

import 'dart:convert';
import 'dart:io';

/// 一次检查的结果。
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.fileName,
    required this.releaseNotes,
  });

  /// 已去掉 `v` 前缀的版本号，例如 `1.4.5`。
  final String version;
  final String downloadUrl;
  final String fileName;

  /// Release 正文（Markdown 原文），页面按纯文本展示。
  final String releaseNotes;
}

/// 检查结果：要么有更新，要么明确「已是最新」，要么失败。
class UpdateCheckResult {
  const UpdateCheckResult.upToDate({required this.currentVersion})
    : info = null,
      error = null;

  const UpdateCheckResult.available(UpdateInfo this.info, {required this.currentVersion})
    : error = null;

  const UpdateCheckResult.failed(String this.error)
    : info = null,
      currentVersion = null;

  final UpdateInfo? info;

  /// 本机版本，用于「当前 2.0.0 → 最新 2.0.1」的展示。
  final String? currentVersion;

  final String? error;

  bool get failed => error != null;
  bool get hasUpdate => info != null;
}

/// GitHub Releases 检查器。
class AppUpdateChecker {
  const AppUpdateChecker({
    this.releaseUrl = defaultReleaseUrl,
    this.timeout = const Duration(seconds: 15),
  });

  /// 1.4.3 `AppUpdateManager.RELEASE_URL`。
  ///
  /// 默认值就是旧版那个地址；`String.fromEnvironment` 只提供编译期覆盖，用于
  /// 两种正当场景——指向自建/镜像的 release 源，以及在真机上对着本地假服务器
  /// 验证「发现新版本」这条分支（正常构建不传就是正式地址）。
  static const defaultReleaseUrl = String.fromEnvironment(
    'DITING_RELEASE_URL',
    defaultValue:
        'https://api.github.com/repos/haoze-evoluling/DITING/releases/latest',
  );

  final String releaseUrl;
  final Duration timeout;

  /// 查最新版本。[currentVersion] 是本机版本（来自 `app_version_name`）。
  Future<UpdateCheckResult> check(String currentVersion) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(Uri.parse(releaseUrl)).timeout(timeout);
      // GitHub 对没有 User-Agent 的请求直接 403；`Accept` 决定返回的 schema。
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'DITING-Android');
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join().timeout(timeout);
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

  /// 把非 200 翻成用户能理解的话。
  ///
  /// 403 在 GitHub 上有两种含义，而它们对用户完全不同：**限流**（未认证请求
  /// 每小时 60 次，网关后面很容易撞到）和**真的被拒**。旧版一律说
  /// 「GitHub 返回 403」，用户只能反复重试。这里读响应体的 `message` 判断：
  /// 限流就说限流并给出去处，其余保留状态码。
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

  /// 解析 `releases/latest` 的响应体。
  ///
  /// 与旧版 `parseLatestRelease` 等价；差异只有一处——旧版用 `optString` 容忍
  /// 缺字段，这里同样容忍，但**版本号缺失时明确报错**而不是静默当成最新版。
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

  /// 挑 APK：优先 arm64-v8a，其次任意 `.apk`。
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

  /// 版本号比较，逐段整数比较（旧版 `isNewerVersion`）。
  ///
  /// 任一侧解析不出整数就返回 false：宁可「没有更新」，也不要把一个看不懂的
  /// tag 当成更新去提示用户下载。
  static bool isNewerVersion(String remote, String current) {
    List<int>? components(String value) {
      final normalized = value.trim().replaceFirst(RegExp(r'^v'), '').split('-').first;
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
      final currentValue = index < currentParts.length ? currentParts[index] : 0;
      if (remoteValue != currentValue) return remoteValue > currentValue;
    }
    return false;
  }
}

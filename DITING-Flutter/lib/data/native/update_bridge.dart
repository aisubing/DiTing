/// Dart side of `com.haoze.diting/update`: 下载更新包 + 调起系统安装器。
///
/// 这两步没有 Dart 等价物：
///
/// | 能力 | 旧版实现 | 为什么必须在原生 |
/// |---|---|---|
/// | 下载 APK | `AppUpdateManager.download()` 写 `filesDir/app-update/` | Dart 拿不到应用私有目录的可写路径 |
/// | 安装 APK | `FileProvider` + `ACTION_VIEW` | 需要按包名拼 authority 并把 `content://` 交给系统 |
///
/// 与 [PlatformBridge] 一样，通道缺失（非 Android 宿主、单元测试）时所有方法
/// 都返回「不可用」而不是抛异常，页面据此降级。
library;

import 'package:flutter/services.dart';

const _updateChannelName = 'com.haoze.diting/update';

/// 下载进度（[total] 为 -1 表示服务器未给出总长度）。
class UpdateProgress {
  const UpdateProgress({required this.downloaded, required this.total});

  final int downloaded;
  final int total;

  /// 0–1 的进度；总长度未知时返回 null。
  double? get fraction =>
      total > 0 ? (downloaded / total).clamp(0.0, 1.0) : null;

  static UpdateProgress fromMap(Object? raw) {
    final map = raw is Map ? Map<Object?, Object?>.from(raw) : const {};
    return UpdateProgress(
      downloaded: (map['downloaded'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? -1,
    );
  }
}

/// 下载结果：成功给出安装包绝对路径，失败给出可读原因。
class UpdateDownloadResult {
  const UpdateDownloadResult.success(this.path)
    : error = null;

  const UpdateDownloadResult.failed(String this.error)
    : path = null;

  final String? path;
  final String? error;

  bool get ok => path != null;
}

/// 原生更新通道封装。
class UpdateBridge {
  UpdateBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_updateChannelName);

  final MethodChannel _channel;

  /// 下载 [url] 到应用私有目录，期间通过 [onProgress] 回推进度。
  ///
  /// 只有 Android 宿主会真正下载；其他环境返回失败，调用方据此展示
  /// 「本机不支持」而不是假装在下载。
  Future<UpdateDownloadResult> download({
    required String url,
    required String version,
    void Function(UpdateProgress progress)? onProgress,
  }) async {
    if (onProgress != null) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'progress') {
          onProgress(UpdateProgress.fromMap(call.arguments));
        }
        return null;
      });
    }
    try {
      final path = await _channel.invokeMethod<String>('download', {
        'url': url,
        'version': version,
      });
      if (path == null || path.isEmpty) {
        return const UpdateDownloadResult.failed('下载失败：未返回安装包路径');
      }
      return UpdateDownloadResult.success(path);
    } on MissingPluginException {
      return const UpdateDownloadResult.failed('当前设备不支持应用内下载，请用浏览器打开下载地址');
    } on PlatformException catch (error) {
      return UpdateDownloadResult.failed(
        error.message ?? '下载失败（${error.code}）',
      );
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }

  /// 调起系统安装器安装已下载的 APK。[path] 是 [download] 返回的绝对路径。
  Future<bool> install(String path) async {
    try {
      final result = await _channel.invokeMethod<bool>('install', {
        'path': path,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

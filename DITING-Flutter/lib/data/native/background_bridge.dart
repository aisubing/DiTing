/// Dart side of `com.haoze.diting/background`: 选图 + 解码成可渲染的本地文件。
///
/// 三步都在原生完成，原因见 [BackgroundBridge]（Kotlin）：
/// - `pick` 走系统图片选择器（`ACTION_OPEN_DOCUMENT`），返回原始 URI；
/// - `resolve` 把 URI 采样解码成 `filesDir/background/bg_<hash>.png` 并返回路径，
///   Dart 用 `Image.file` 渲染即可；
/// - `release` 在删除某张壁纸时删掉它的缓存副本。
///
/// 通道缺失（非 Android 宿主 / 单测）时全部返回「不可用」，页面据此降级。
library;

import 'package:flutter/services.dart';

const _backgroundChannelName = 'com.haoze.diting/background';

/// 选图结果。
class BackgroundPickResult {
  const BackgroundPickResult.picked({
    required this.uri,
    required this.path,
  }) : cancelled = false;

  const BackgroundPickResult.cancelled()
    : uri = null,
      path = null,
      cancelled = true;

  const BackgroundPickResult.failed()
    : uri = null,
      path = null,
      cancelled = false;

  final String? uri;

  /// 已解码的本地缓存路径；可能为 null（解码失败但 URI 有效）。
  final String? path;
  final bool cancelled;

  bool get ok => uri != null;

  static BackgroundPickResult fromMap(Object? raw) {
    final map = raw is Map ? Map<Object?, Object?>.from(raw) : const {};
    if (map['cancelled'] == true) return const BackgroundPickResult.cancelled();
    final uri = map['uri'] as String?;
    if (uri == null) return const BackgroundPickResult.failed();
    return BackgroundPickResult.picked(uri: uri, path: map['path'] as String?);
  }
}

/// 原生背景通道封装。
class BackgroundBridge {
  BackgroundBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_backgroundChannelName);

  final MethodChannel _channel;

  /// 打开系统图片选择器并缓存所选图片。用户取消时返回 cancelled。
  Future<BackgroundPickResult> pick() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('pick');
      return BackgroundPickResult.fromMap(raw);
    } on MissingPluginException {
      return const BackgroundPickResult.failed();
    } on PlatformException {
      return const BackgroundPickResult.failed();
    }
  }

  /// 把已记录的 URI 解析成本地缓存路径（不存在则现解）。
  Future<String?> resolve(String uri) async {
    try {
      return await _channel.invokeMethod<String>('resolve', {'uri': uri});
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 删除某个 URI 的本地缓存副本。
  Future<bool> release(String uri) async {
    try {
      final result = await _channel.invokeMethod<bool>('release', {'uri': uri});
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

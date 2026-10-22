/// Dart side of `com.haoze.diting/recognition`：名单头像的本地磁盘缓存。
///
/// 头像**不随 APK 发布**：名单与头像都以 GitHub 上的 `recognition_members.json`
/// + `avatars/` 为准，推送即生效。因此每张头像首次都要联网取，取回后必须落盘——
/// 否则每次冷启动都要重下十几张，弱网下名单页会长时间全是占位图。
///
/// 为什么缓存放在原生：本仓不引 `path_provider`，Dart 侧拿不到应用私有目录。
/// Kotlin 半边见 `RecognitionAvatarBridge.kt`，写入用 `.part` + `renameTo`，
/// 文件名按白名单正则校验。
///
/// 通道缺失（非 Android 宿主 / 单测）时 `read`/`write` 一律降级为「没有缓存」，
/// 页面继续走网络或默认头像，不会抛异常。
library;

import 'package:flutter/services.dart';

const _recognitionChannelName = 'com.haoze.diting/recognition';

/// 名单头像磁盘缓存通道封装。
class RecognitionAvatarBridge {
  const RecognitionAvatarBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_recognitionChannelName);

  final MethodChannel _channel;

  /// 读缓存；没有则返回 null。
  Future<Uint8List?> read(String name) async {
    try {
      return await _channel.invokeMethod<Uint8List>('read', {'name': name});
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 写入缓存；返回是否成功（失败不影响本次显示）。
  Future<bool> write(String name, Uint8List bytes) async {
    try {
      final path = await _channel.invokeMethod<String>('write', {
        'name': name,
        'bytes': bytes,
      });
      return path != null;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 清空全部头像缓存；返回删除的文件数。
  Future<int> clear() async {
    try {
      return await _channel.invokeMethod<int>('clear') ?? 0;
    } on MissingPluginException {
      return 0;
    } on PlatformException {
      return 0;
    }
  }
}

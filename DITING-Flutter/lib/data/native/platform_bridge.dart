/// Dart side of `com.haoze.diting/platform`: the four OS-level settings.
///
/// Everything here has **no Dart equivalent**, which is why it needs a channel:
///
/// | 能力 | 旧版实现 | 为什么必须在原生 |
/// |---|---|---|
/// | 后台隐藏 | `ui/RecentsPrivacyController.apply()` | `ActivityManager.appTasks` + `setExcludeFromRecents` |
/// | 忽略电池优化 | `PowerManager.isIgnoringBatteryOptimizations` | 系统服务 + 系统设置 Intent |
/// | 崩溃日志 | 崩溃处理器写 `filesDir/crash/` | 应用私有目录枚举 |
/// | 导出文本 | 写外部私有目录 | 文件系统路径 |
///
/// 上一轮这四项里，后台隐藏完全没有；电池优化只有一句 SnackBar；
/// 崩溃日志是写死的 `_crashLogCount = 3`；导出则不存在。本轮全部接上真实通道。
///
/// **通知栏不在这里**：它由 `notification_settings_prefs` 里的四个键驱动，前台
/// 服务直接读那份 prefs（与 1.4.3 一致）。加一层通道只会多一次往返。
library;

import 'package:flutter/services.dart';

const platformChannelName = 'com.haoze.diting/platform';

/// 原生平台能力封装。
///
/// 每个方法在通道缺失（非 Android 宿主、测试）时都**不抛异常**，而是返回
/// 「不可用」——页面据此显示禁用态。让异常穿透到 UI 会把一次能力探测变成一次
/// 崩溃，而所有调用点都有明确的降级表现。
class PlatformBridge {
  PlatformBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(platformChannelName);

  final MethodChannel _channel;

  /// 后台隐藏：立刻把 `excludeFromRecents` 应用到本应用的所有任务。
  ///
  /// 返回 false 表示当前没有可取到的任务列表（应用还没出现在最近任务里），
  /// 不算失败：值已落盘，下次 `onResume` 会重新应用。
  Future<bool> applyRecentsPrivacy({required bool hide}) async {
    try {
      final result = await _channel.invokeMethod<bool>('applyRecentsPrivacy', {
        'hide': hide,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 是否已在电池优化白名单里。
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 跳转系统设置请求忽略电池优化。返回是否成功唤起了设置页。
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'requestIgnoreBatteryOptimizations',
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 崩溃日志条数。旧版的假常量 `3` 已被这个真实计数取代。
  Future<int> crashLogCount() async {
    try {
      final result = await _channel.invokeMethod<int>('crashLogCount');
      return result ?? 0;
    } on MissingPluginException {
      return 0;
    } on PlatformException {
      return 0;
    }
  }

  /// 清空崩溃日志，返回删除的条数。
  Future<int> clearCrashLogs() async {
    try {
      final result = await _channel.invokeMethod<int>('clearCrashLogs');
      return result ?? 0;
    } on MissingPluginException {
      return 0;
    } on PlatformException {
      return 0;
    }
  }

  /// 把 [content] 写成 UTF-8 文本文件，返回绝对路径；失败返回 null。
  ///
  /// [name] 会被原生侧清洗成安全文件名（保留字母数字与 `._-`）。
  Future<String?> exportText({
    required String name,
    required String content,
  }) async {
    try {
      return await _channel.invokeMethod<String>('exportText', {
        'name': name,
        'content': content,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 删除已下载的更新安装包；[includeTemp] 为真时连临时缓存目录一起删。
  ///
  /// 返回删掉的条目数。**不能用 sqflite 做这件事**：它只认识应用私有目录下的
  /// `databases/`，删不到 `filesDir/app-update`（1.4.3 `AppUpdateManager` 的
  /// 真实下载目录）与 `cacheDir`。
  ///
  /// 通道缺失时返回 0 而不是抛异常：调用方据此提示「本机无可用下载缓存」，
  /// 与「删了 0 个」在语义上一致——两者都不该谎报成功。
  Future<int> clearUpdateCache({bool includeTemp = true}) async {
    try {
      final result = await _channel.invokeMethod<int>('clearUpdateCache', {
        'includeTemp': includeTemp,
      });
      return result ?? 0;
    } on MissingPluginException {
      return 0;
    } on PlatformException {
      return 0;
    }
  }

  /// 删除自定义壁纸的缓存位图与路径标记文件，返回删掉的文件数。
  Future<int> clearCustomBackgroundCache() async {
    try {
      final result = await _channel.invokeMethod<int>(
        'clearCustomBackgroundCache',
      );
      return result ?? 0;
    } on MissingPluginException {
      return 0;
    } on PlatformException {
      return 0;
    }
  }
}

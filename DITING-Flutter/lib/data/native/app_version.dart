/// 应用版本的唯一真源：`pubspec.yaml` 的 `version: <name>+<code>`。
///
/// 为什么不再手写常量：上一轮 `lib/pages/system/app_info.dart` 里有一份
/// `const appVersionName = '2.0.1'`，发版只改 pubspec 时关于页会一直显示旧版本，
/// 而版本号还渗进了三处「读不到就回落」的默认值。现在链路是一条：
///
/// ```
/// pubspec.yaml ──Gradle/Flutter 插件──> APK 包信息(versionName/versionCode)
///                                       └─> LegacyPrefsBridge.versionInfo
/// ```
///
/// 没有原生通道的宿主（`flutter test`、桌面）退化为直接读工作目录的
/// `pubspec.yaml`——测试进程的 cwd 就是工程根，所以显示的仍是真实版本。
library;

import 'dart:io';

import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 安装包版本：[name] 是展示名（不含 build 号），[code] 是 Android versionCode。
@immutable
class AppVersion {
  const AppVersion({required this.name, required this.code});

  /// 两个来源都拿不到时的占位。正常构建与测试不会走到这里；真的走到，
  /// 更新检查会把任何发布版都视为更新，比显示一个假的版本号更安全。
  static const unknown = AppVersion(name: '0.0.0', code: 0);

  /// 展示名，例如 `2.0.1`。
  final String name;

  /// `pubspec.yaml` 里 `+` 之后的 build 号，例如 `20001`。
  final int code;

  /// 解析 `version: 1.2.3+10203`；缺 build 号时与 Flutter 工具一致按 1 处理。
  ///
  /// 返回 null 表示这份文本里没有可用的 `version:` 行（文件被改坏或不是 pubspec）。
  static AppVersion? parse(String pubspec) {
    final match = RegExp(
      r'^version:\s*([^\s+#]+)(?:\+(\d+))?',
      multiLine: true,
    ).firstMatch(pubspec);
    if (match == null) return null;
    final name = match.group(1)!.trim();
    if (name.isEmpty) return null;
    final code = int.tryParse(match.group(2) ?? '') ?? 1;
    return AppVersion(name: name, code: code);
  }

  /// 读工作目录里的 `pubspec.yaml`；设备上没有这个文件时返回 null。
  static AppVersion? fromPubspec() {
    try {
      return parse(File('pubspec.yaml').readAsStringSync());
    } on FileSystemException {
      // 设备上本来就没有 pubspec.yaml，不是错误，不必刷日志。
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion && other.name == name && other.code == code;

  @override
  int get hashCode => Object.hash(name, code);

  @override
  String toString() => '$name+$code';
}

/// 读安装包信息（Android），拿不到时退回工作目录的 `pubspec.yaml`。
///
/// 通道缺失（测试 / 桌面 / 极早期启动）只降级、不抛异常：版本号读不到不该让
/// 首帧失败，[AppVersion.unknown] 足以让应用跑起来。
Future<AppVersion> loadAppVersion({
  MethodChannel channel = legacyPrefsChannel,
}) async {
  try {
    final raw = await channel.invokeMethod<Map<Object?, Object?>>(
      'versionInfo',
    );
    final name = '${raw?['name'] ?? ''}'.trim();
    final code = (raw?['code'] as num?)?.toInt();
    if (name.isNotEmpty && code != null) {
      return AppVersion(name: name, code: code);
    }
  } on MissingPluginException {
    // 非 Android 宿主：下面读 pubspec.yaml。
  } on PlatformException catch (error) {
    debugPrint('versionInfo read failed: $error');
  }
  return AppVersion.fromPubspec() ?? AppVersion.unknown;
}

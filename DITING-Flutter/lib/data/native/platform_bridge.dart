/// Dart side of `com.haoze.diting/platform`: recents hiding, battery-optimization allowlist, crash
/// logs and text export. Notification settings bypass this channel.
library;

import 'package:diting/data/native/process_memory.dart';
import 'package:flutter/services.dart';

const platformChannelName = 'com.haoze.diting/platform';

/// Every method returns "unavailable" instead of throwing when the channel is missing, and every
/// caller has a degraded state for it.
class PlatformBridge {
  PlatformBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(platformChannelName);

  final MethodChannel _channel;

  /// Applies `excludeFromRecents` to every task of this app. False means no task list yet, not a
  /// failure: the value is persisted and reapplied on the next `onResume`.
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

  Future<String> readCrashLogs() async {
    try {
      return await _channel.invokeMethod<String>('readCrashLogs') ?? '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

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

  /// Deletes downloaded update packages; [includeTemp] also clears the temp cache. Not doable
  /// through sqflite, which only sees `databases/`.
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

  /// Opens the system save picker and writes [content] into it; on Android 11+ the app-private
  /// external dir is hard to reach even from a file manager.
  Future<DocumentSaveResult> exportDocument({
    required String name,
    required String content,
  }) async {
    try {
      final raw = await _channel.invokeMethod<Object?>('exportDocument', {
        'name': name,
        'content': content,
      });
      return DocumentSaveResult.fromMap(raw);
    } on MissingPluginException {
      return const DocumentSaveResult.unavailable();
    } on PlatformException catch (error) {
      return DocumentSaveResult.failed('无法打开保存对话框：${error.message}');
    }
  }

  Future<DocumentOpenResult> importDocument() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('importDocument');
      return DocumentOpenResult.fromMap(raw);
    } on MissingPluginException {
      return const DocumentOpenResult.unavailable();
    } on PlatformException catch (error) {
      return DocumentOpenResult.failed('无法打开文件选择器：${error.message}');
    }
  }

  /// Memory used by this process and by the device; a missing channel yields
  /// [ProcessMemory.available] false so the card shows a dash.
  Future<ProcessMemory> memoryInfo() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('memoryInfo');
      return ProcessMemory.fromMap(raw);
    } on MissingPluginException {
      return const ProcessMemory();
    } on PlatformException {
      return const ProcessMemory();
    }
  }
}

class DocumentSaveResult {
  const DocumentSaveResult({
    required this.saved,
    this.name,
    this.cancelled = false,
    this.error,
  });

  const DocumentSaveResult.unavailable()
    : saved = false,
      name = null,
      cancelled = false,
      error = '当前环境不支持系统文件选择器';

  const DocumentSaveResult.failed(String this.error)
    : saved = false,
      name = null,
      cancelled = false;

  final bool saved;
  final String? name;
  final bool cancelled;
  final String? error;

  static DocumentSaveResult fromMap(Object? raw) {
    final map = raw is Map ? Map<Object?, Object?>.from(raw) : const {};
    return DocumentSaveResult(
      saved: map['saved'] == true,
      name: map['name'] as String?,
      cancelled: map['cancelled'] == true,
      error: map['error'] as String?,
    );
  }
}

class DocumentOpenResult {
  const DocumentOpenResult({
    this.text,
    this.name,
    this.cancelled = false,
    this.error,
  });

  const DocumentOpenResult.unavailable()
    : text = null,
      name = null,
      cancelled = false,
      error = '当前环境不支持系统文件选择器';

  const DocumentOpenResult.failed(String this.error)
    : text = null,
      name = null,
      cancelled = false;

  final String? text;
  final String? name;
  final bool cancelled;
  final String? error;

  static DocumentOpenResult fromMap(Object? raw) {
    final map = raw is Map ? Map<Object?, Object?>.from(raw) : const {};
    return DocumentOpenResult(
      text: map['text'] as String?,
      name: map['name'] as String?,
      cancelled: map['cancelled'] == true,
      error: map['error'] as String?,
    );
  }
}

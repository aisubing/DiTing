/// Access to the SharedPreferences files written by DITING 1.4.3.
///
/// The file names and keys are part of the upgrade contract: a DITING 1.4.3
/// user installing this build must find their settings where the old app left
/// them. Only the platform API can open those files (the `shared_preferences`
/// plugin uses its own container and prefix), so Android goes through
/// [LegacyPrefsBridge] and everything else falls back to memory.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Canonical channel implemented by `LegacyPrefsBridge.kt`.
const legacyPrefsChannel = MethodChannel('com.haoze.diting/legacy_prefs');

/// All containers that existed in 1.4.3. Keep in sync with the Kotlin allowlist.
/// 启动时一次性读入的容器清单，必须与原生 `LegacyPrefsBridge.CONTAINERS` 一致。
///
/// 少一个的表现很隐蔽：写入照样成功（文件落在磁盘上），但下次冷启动 `read` 拿不到，
/// 因为快照里没有这个容器——界面于是显示默认值，看起来像「设置没保存」。
const legacyPrefContainers = <String>[
  'dns_vpn_prefs',
  'diting_express_prefs',
  'diting_dns_mode_prefs',
  'express_vpn_prefs',
  'diting_settings',
  'permission_disclosures',
  'mode_permission_preferences',
  'notification_settings_prefs',
  'diting_crash_state',
  'network_tools_settings',
  'recognition_members',
  // 本仓自有容器（1.4.3 无对应功能）：图标集 / UA / 按需连接。
  'diting_config_resources',
];

/// Reads and writes the legacy preference containers.
abstract class LegacyPrefsStore {
  Map<String, Object?> readAll(String container);

  Object? read(String container, String key);

  void putString(String container, String key, String value);

  void putBool(String container, String key, bool value);

  void putInt(String container, String key, int value);

  void putLong(String container, String key, int value);

  void putFloat(String container, String key, double value);

  void putStringSet(String container, String key, Set<String> value);

  void remove(String container, String key);
}

/// Used on non-Android hosts, in tests, and when the channel is unavailable.
class MemoryLegacyPrefsStore implements LegacyPrefsStore {
  MemoryLegacyPrefsStore([Map<String, Map<String, Object?>>? seed])
    : _values = {
        for (final entry in (seed ?? const {}).entries)
          entry.key: {...entry.value},
      };

  final Map<String, Map<String, Object?>> _values;

  @override
  Map<String, Object?> readAll(String container) =>
      Map.unmodifiable(_values[container] ?? const {});

  @override
  Object? read(String container, String key) => _values[container]?[key];

  void _write(String container, String key, Object? value) {
    (_values[container] ??= {})[key] = value;
  }

  @override
  void putString(String container, String key, String value) =>
      _write(container, key, value);

  @override
  void putBool(String container, String key, bool value) =>
      _write(container, key, value);

  @override
  void putInt(String container, String key, int value) =>
      _write(container, key, value);

  @override
  void putLong(String container, String key, int value) =>
      _write(container, key, value);

  @override
  void putFloat(String container, String key, double value) =>
      _write(container, key, value);

  @override
  void putStringSet(String container, String key, Set<String> value) =>
      _write(container, key, value.toList());

  @override
  void remove(String container, String key) {
    _values[container]?.remove(key);
  }
}

/// Android implementation: a synchronous snapshot loaded once at startup,
/// with every mutation mirrored to the real file through the channel.
class MethodChannelLegacyPrefsStore implements LegacyPrefsStore {
  MethodChannelLegacyPrefsStore(
    this._snapshot, {
    this.channel = legacyPrefsChannel,
  });

  final Map<String, Map<String, Object?>> _snapshot;
  final MethodChannel channel;

  @override
  Map<String, Object?> readAll(String container) =>
      Map.unmodifiable(_snapshot[container] ?? const {});

  @override
  Object? read(String container, String key) => _snapshot[container]?[key];

  void _write(String container, String key, String type, Object? value) {
    (_snapshot[container] ??= {})[key] = value;
    unawaited(
      channel
          .invokeMethod<void>('put', {
            'container': container,
            'key': key,
            'type': type,
            'value': value,
          })
          .catchError((Object error) {
            // A dropped write is a data-loss bug; keep it visible in logs.
            // 这条日志曾经是唯一线索：新增的容器不在原生白名单里时，界面照常
            // 反映「已保存」，磁盘上却没有文件。排查靠的就是这句话，所以它必须
            // 说清是哪一对 container/key。
            debugPrint('legacy prefs write failed: $container/$key ($error)');
          }),
    );
  }

  @override
  void putString(String container, String key, String value) =>
      _write(container, key, 'string', value);

  @override
  void putBool(String container, String key, bool value) =>
      _write(container, key, 'bool', value);

  @override
  void putInt(String container, String key, int value) =>
      _write(container, key, 'int', value);

  @override
  void putLong(String container, String key, int value) =>
      _write(container, key, 'long', value);

  @override
  void putFloat(String container, String key, double value) =>
      _write(container, key, 'float', value);

  @override
  void putStringSet(String container, String key, Set<String> value) =>
      _write(container, key, 'string_set', value.toList());

  @override
  void remove(String container, String key) {
    _snapshot[container]?.remove(key);
    unawaited(
      channel
          .invokeMethod<void>('remove', {'container': container, 'key': key})
          .catchError((Object error) {
            debugPrint('legacy prefs remove failed: $container/$key ($error)');
          }),
    );
  }
}

/// Loads every legacy container once, before the first frame.
///
/// On platforms without the Android bridge the app still starts, with defaults.
Future<LegacyPrefsStore> loadLegacyPrefsStore({
  MethodChannel channel = legacyPrefsChannel,
}) async {
  final snapshot = <String, Map<String, Object?>>{};
  try {
    for (final container in legacyPrefContainers) {
      final values = await channel.invokeMethod<Map<Object?, Object?>>(
        'readAll',
        {'container': container},
      );
      snapshot[container] = {
        for (final entry in (values ?? const {}).entries)
          entry.key.toString(): entry.value,
      };
    }
  } on MissingPluginException {
    return MemoryLegacyPrefsStore();
  } on PlatformException catch (error) {
    debugPrint('legacy prefs load failed: $error');
    return MemoryLegacyPrefsStore();
  }
  return MethodChannelLegacyPrefsStore(snapshot, channel: channel);
}

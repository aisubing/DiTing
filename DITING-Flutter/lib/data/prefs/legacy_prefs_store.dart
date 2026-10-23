/// Access to the SharedPreferences files written by the legacy DITING app. File names and keys are
/// part of the upgrade contract, and only the platform API can open them.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const legacyPrefsChannel = MethodChannel('com.haoze.diting/legacy_prefs');

/// Loaded once at startup; keep in sync with the native `LegacyPrefsBridge.CONTAINERS` allowlist,
/// or writes are accepted here and lost on the next cold start.
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
  // Own container, no legacy counterpart: icon sets, UA, on-demand.
  'diting_config_resources',
];

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

/// Used on non-Android hosts, in tests and when the channel is unavailable.
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

/// Snapshot loaded at startup; every mutation is mirrored to the real file through the channel.
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
            // A dropped write is data loss: this log is the only trace, so it must name the
            // container and key.
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

/// Loads every legacy container once before the first frame; without the bridge the app starts with
/// defaults.
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

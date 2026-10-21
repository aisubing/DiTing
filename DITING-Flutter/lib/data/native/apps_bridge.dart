/// Dart side of `com.haoze.diting/apps`: the *real* installed-app inventory.
///
/// 1.4.3 enumerated applications through `PackageManager` with
/// `QUERY_ALL_PACKAGES` (`Android/app/src/main/AndroidManifest.xml`); the
/// migrated Manifest dropped the permission, so every picker page fell back to
/// `mockInstalledApps` / `mockPackages` constants. This channel restores the
/// real list.
///
/// The channel is deliberately read-only: selection state stays in
/// `SharedPreferences` (`blocked_app_packages`, `excluded_app_packages`,
/// `http_inspection_app_packages`, `app_allowlist_rules_json`), which the
/// existing `LegacyPrefsBridge` already writes.
library;

import 'package:flutter/services.dart';

const appsChannelName = 'com.haoze.diting/apps';

/// One installed application, in the shape `InstalledAppPickerComponents`
/// consumed in 1.4.3.
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.label,
    required this.isSystem,
    required this.uid,
  });

  final String packageName;
  final String label;

  /// `AppListFilter.SYSTEM` in 1.4.3 was `(applicationInfo.flags and
  /// FLAG_SYSTEM) != 0`; the picker offered USER / SYSTEM / ALL / SELECTED.
  final bool isSystem;

  /// Resolved with `PackageManager.getPackageUid(packageName, 0)`. The engine
  /// needs UIDs, not package names (`setBlockedUIDs`, `setMitmAllowedUIDs`,
  /// `setAppAllowlist`), so resolving them once here avoids a second round trip
  /// per toggle.
  final int uid;

  /// 1.4.3 matched the debounced query against both fields, lowercased.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final needle = query.toLowerCase();
    return label.toLowerCase().contains(needle) ||
        packageName.toLowerCase().contains(needle);
  }

  static InstalledApp fromMap(Map<Object?, Object?> map) => InstalledApp(
    packageName: map['packageName'] as String? ?? '',
    label: map['label'] as String? ?? '',
    isSystem: map['isSystem'] == true,
    uid: (map['uid'] as num?)?.toInt() ?? -1,
  );
}

/// Source of truth for "which apps exist on this device".
abstract class InstalledAppsSource {
  /// Sorted by label, exactly like `AppListSort.LABEL_ASC` (the 1.4.3 default).
  Future<List<InstalledApp>> list();

  /// Package name → UID. Missing packages are absent from the map rather than
  /// mapped to -1, so callers can drop uninstalled selections instead of
  /// handing the engine an invalid UID.
  Future<Map<String, int>> resolveUids(Iterable<String> packages);

  /// True when [packageName] is this app. 1.4.3 refuses to let the user block,
  /// exclude, inspect or proxy the app itself — blocking 谛听's own UID would
  /// cut the tunnel's control plane.
  Future<bool> isSelf(String packageName);
}

class MethodChannelInstalledAppsSource implements InstalledAppsSource {
  MethodChannelInstalledAppsSource({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(appsChannelName);

  final MethodChannel _channel;

  @override
  Future<List<InstalledApp>> list() async {
    final raw = await _channel.invokeMethod<Object?>('listInstalled');
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) InstalledApp.fromMap(Map<Object?, Object?>.from(item)),
    ]..sort((a, b) => a.label.compareTo(b.label));
  }

  @override
  Future<Map<String, int>> resolveUids(Iterable<String> packages) async {
    final values = packages.toList();
    if (values.isEmpty) return const {};
    final raw = await _channel.invokeMethod<Object?>('resolveUids', {
      'packages': values,
    });
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is num)
          entry.key as String: (entry.value as num).toInt(),
    };
  }

  @override
  Future<bool> isSelf(String packageName) async =>
      await _channel.invokeMethod<bool>('isSelf', {
        'packageName': packageName,
      }) ??
      false;
}

/// Used by widget tests and any non-Android host: an empty device.
///
/// Returning an empty list (not throwing) keeps every picker page in its
/// documented "no apps" state instead of crashing inside `FutureProvider`.
class EmptyInstalledAppsSource implements InstalledAppsSource {
  const EmptyInstalledAppsSource();

  @override
  Future<List<InstalledApp>> list() async => const [];

  @override
  Future<Map<String, int>> resolveUids(Iterable<String> packages) async =>
      const {};

  @override
  Future<bool> isSelf(String packageName) async => false;
}

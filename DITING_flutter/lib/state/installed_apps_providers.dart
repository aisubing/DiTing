/// The real installed-app inventory, shared by every picker screen.
///
/// 1.4.3 enumerated applications through `PackageManager`
/// (`InstalledAppPickerComponents.loadInstalledApps`); the migrated Manifest
/// dropped `QUERY_ALL_PACKAGES`, so the Flutter port hardcoded `mockInstalledApps`
/// / `mockPackages` and every picker offered apps that are not on the device.
/// This layer puts the native list back behind one provider so the four picker
/// screens cannot drift apart.
///
/// Failure policy: a missing plugin (widget tests, desktop hosts, a build without
/// the bridge) or a platform error must degrade to an **empty list plus a
/// readable message**. Throwing out of a `FutureProvider` would put every picker
/// page into Riverpod's error state, whose default rendering is a red box — the
/// user would see a crash instead of "no apps found".
library;

import 'package:diting/data/native/apps_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden in `main()` with [MethodChannelInstalledAppsSource].
///
/// The default is [EmptyInstalledAppsSource] so tests and non-Android hosts get
/// an honest "no apps" page instead of a `MissingPluginException`.
final installedAppsSourceProvider = Provider<InstalledAppsSource>(
  (ref) => const EmptyInstalledAppsSource(),
);

/// Result of listing the device's apps: the list plus why it may be empty.
class InstalledAppsSnapshot {
  const InstalledAppsSnapshot({required this.apps, this.error});

  const InstalledAppsSnapshot.empty([this.error]) : apps = const [];

  /// Sorted by label (`AppListSort.LABEL_ASC`, the 1.4.3 default).
  final List<InstalledApp> apps;

  /// Non-null when enumeration failed. The list is then empty, and the picker
  /// must show the reason instead of "no apps installed".
  final String? error;

  /// Fast membership test used by the outbound-proxy validator: "selected but
  /// not installed" is a hard error there, and it must not scan the list per key
  /// stroke.
  Set<String> get packageNames => {for (final app in apps) app.packageName};
}

/// The device's installed apps, with a bumpable revision for manual refresh.
///
/// A fresh install of an app while a picker is open is rare enough that the page
/// only reloads on demand (`installedAppsRevisionProvider`), not on a timer.
class InstalledAppsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final installedAppsRevisionProvider =
    NotifierProvider<InstalledAppsRevision, int>(InstalledAppsRevision.new);

final installedAppsProvider = FutureProvider<InstalledAppsSnapshot>((
  ref,
) async {
  ref.watch(installedAppsRevisionProvider);
  final source = ref.watch(installedAppsSourceProvider);
  try {
    final apps = await source.list();
    // `MethodChannelInstalledAppsSource` already sorts by label, but the
    // contract in `InstalledAppsSnapshot` belongs to this provider: any other
    // source (a fake, a future Room-backed one) must not be able to hand the
    // pages a differently-ordered list.
    return InstalledAppsSnapshot(
      apps: [...apps]..sort(AppListSort.labelAsc.compare),
    );
  } on MissingPluginException catch (error) {
    return InstalledAppsSnapshot.empty('应用列表通道不可用：${error.message ?? '未注册'}');
  } on PlatformException catch (error) {
    return InstalledAppsSnapshot.empty(_describe(error));
  }
});

/// Convenience for pages that only need the list (null while loading).
final installedAppListProvider = Provider<List<InstalledApp>?>((ref) {
  return ref.watch(installedAppsProvider).value?.apps;
});

/// Resolves package names to UIDs for whatever the engine needs to be handed.
///
/// The engine takes UIDs (`setBlockedUIDs`, `setMitmAllowedUIDs`), and an
/// uninstalled package is **absent** from the result rather than mapped to -1,
/// so callers drop it instead of feeding the engine an invalid UID. A missing
/// channel yields an empty map — the same "nothing to apply" state as a device
/// with no matching apps, and never an exception on a page-build path.
Future<Map<String, int>> resolveInstalledUids(
  InstalledAppsSource source,
  Iterable<String> packages,
) async {
  try {
    return await source.resolveUids(packages);
  } on MissingPluginException {
    return const {};
  } on PlatformException {
    return const {};
  }
}

String _describe(PlatformException error) {
  final message = (error.message ?? '').trim();
  return message.isEmpty ? '读取应用列表失败（${error.code}）' : '读取应用列表失败：$message';
}

/// The `AppListFilter` of 1.4.3, in the enum's own declaration order.
///
/// `name` is the persisted form (`excluded_apps_filter` etc.), so a value that
/// does not match any member must fall back to [user] — that is what
/// `AppListFilter.entries.firstOrNull { it.name == stored } ?: USER` did.
enum AppListFilter {
  all('ALL', '全部应用'),
  system('SYSTEM', '系统应用'),
  user('USER', '用户应用'),
  selected('SELECTED', '已勾选应用');

  const AppListFilter(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static AppListFilter fromStorageValue(String? value) => values.firstWhere(
    (item) => item.storageValue == value,
    orElse: () => AppListFilter.user,
  );

  bool accept(InstalledApp app, Set<String> selected) => switch (this) {
    AppListFilter.all => true,
    AppListFilter.system => app.isSystem,
    AppListFilter.user => !app.isSystem,
    AppListFilter.selected => selected.contains(app.packageName),
  };
}

/// The `AppListSort` of 1.4.3 (`InstalledAppPickerComponents.kt`), same numerals.
///
/// Label comparisons use the lowercased label and then the package name, exactly
/// like `compareBy { normalizedLabel }.thenBy { packageName }`.
enum AppListSort {
  labelAsc('LABEL_ASC', '应用名称 A-Z'),
  labelDesc('LABEL_DESC', '应用名称 Z-A'),
  packageAsc('PACKAGE_ASC', '包名 A-Z'),
  packageDesc('PACKAGE_DESC', '包名 Z-A');

  const AppListSort(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static AppListSort fromStorageValue(String? value) => values.firstWhere(
    (item) => item.storageValue == value,
    orElse: () => AppListSort.labelAsc,
  );

  int compare(InstalledApp a, InstalledApp b) {
    return switch (this) {
      AppListSort.labelAsc => _labelAsc(a, b, false),
      AppListSort.labelDesc => _labelAsc(a, b, true),
      AppListSort.packageAsc => _packageAsc(a, b, false),
      AppListSort.packageDesc => _packageAsc(a, b, true),
    };
  }

  static int _labelAsc(InstalledApp a, InstalledApp b, bool descending) {
    final verdict = a.label.toLowerCase().compareTo(b.label.toLowerCase());
    if (verdict != 0) {
      return descending ? -verdict : verdict;
    }
    // The tie-break stays ascending in both directions, matching 1.4.3's
    // `compareByDescending { normalizedLabel }.thenBy { packageName }`.
    return a.packageName.compareTo(b.packageName);
  }

  static int _packageAsc(InstalledApp a, InstalledApp b, bool descending) {
    final verdict = a.packageName.toLowerCase().compareTo(
      b.packageName.toLowerCase(),
    );
    return descending ? -verdict : verdict;
  }
}

/// Query + filter + sort in one place, so every picker filters identically.
List<InstalledApp> visibleInstalledApps({
  required List<InstalledApp> apps,
  required String query,
  required AppListFilter filter,
  required AppListSort sort,
  required Set<String> selected,
}) {
  final needle = query.trim().toLowerCase();
  return [
    for (final app in apps)
      if (filter.accept(app, selected) && app.matches(needle)) app,
  ]..sort(sort.compare);
}

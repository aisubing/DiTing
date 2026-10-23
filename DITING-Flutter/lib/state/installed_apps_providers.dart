/// The installed-app inventory every picker shares; a platform error degrades to an empty list,
/// never a throw.
library;

import 'package:diting/data/native/apps_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden in `main()`; the default gives an honest "no apps" page on non-Android hosts.
final installedAppsSourceProvider = Provider<InstalledAppsSource>(
  (ref) => const EmptyInstalledAppsSource(),
);

class InstalledAppsSnapshot {
  const InstalledAppsSnapshot({required this.apps, this.error});

  const InstalledAppsSnapshot.empty([this.error]) : apps = const [];

  /// Sorted by label (`AppListSort.LABEL_ASC`, the 1.4.3 default).
  final List<InstalledApp> apps;

  /// Non-null when enumeration failed; the picker shows the reason instead of "no apps".
  final String? error;

  /// Fast membership test for the outbound-proxy validator, which runs on every key stroke.
  Set<String> get packageNames => {for (final app in apps) app.packageName};
}

/// Bumpable revision for manual refresh; an app installed while a picker is open is rare enough.
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
    // Sort here: ordering belongs to `InstalledAppsSnapshot`, so no source can hand pages an
    // unordered list.
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

/// Resolves package names to engine UIDs; uninstalled packages are absent rather than -1, so
/// callers drop them.
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

/// 1.4.3 `AppListFilter` in declaration order; an unknown `storageValue` falls back to [user].
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

/// 1.4.3 `AppListSort` with the same storage values; labels compare lowercased, then by package.
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
    // The tie-break stays ascending in both directions, as in 1.4.3.
    return a.packageName.compareTo(b.packageName);
  }

  static int _packageAsc(InstalledApp a, InstalledApp b, bool descending) {
    final verdict = a.packageName.toLowerCase().compareTo(
      b.packageName.toLowerCase(),
    );
    return descending ? -verdict : verdict;
  }
}

/// Query, filter and sort in one place so every picker filters identically.
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

/// The installed-app inventory every picker shares; a platform error degrades to an empty list,
/// never a throw.
library;

import 'package:diting/app/l10n/l10n.dart';
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
    return InstalledAppsSnapshot.empty(
      currentL10n.appListChannelUnavailable(
        error.message ?? currentL10n.appListNotRegistered,
      ),
    );
  } on PlatformException catch (error) {
    return InstalledAppsSnapshot.empty(_describe(error));
  }
});

/// Convenience for pages that only need the list (null while loading).
final installedAppListProvider = Provider<List<InstalledApp>?>((ref) {
  return ref.watch(installedAppsProvider).value?.apps;
});

/// Package name to encoded launcher icon, fetched once per inventory revision so list rows can
/// look icons up synchronously while scrolling. A missing entry renders as a placeholder glyph.
final appIconsProvider = FutureProvider<Map<String, Uint8List>>((ref) async {
  final apps = ref.watch(installedAppsProvider).value?.apps ?? const [];
  if (apps.isEmpty) return const {};
  final source = ref.watch(installedAppsSourceProvider);
  try {
    return await source.loadIcons([for (final app in apps) app.packageName]);
  } on MissingPluginException {
    return const {};
  } on PlatformException {
    return const {};
  }
});

/// The icon map if it has already loaded; pages call this from a `select` so a row rebuild never
/// awaits the channel.
final appIconsOrEmptyProvider = Provider<Map<String, Uint8List>>((ref) {
  return ref.watch(appIconsProvider).value ?? const {};
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
  return message.isEmpty
      ? currentL10n.appListReadFailedCode(error.code)
      : currentL10n.appListReadFailed(message);
}

/// 1.4.3 `AppListFilter` in declaration order; an unknown `storageValue` falls back to [user].
enum AppListFilter {
  all('ALL'),
  system('SYSTEM'),
  user('USER'),
  selected('SELECTED');

  const AppListFilter(this.storageValue);

  final String storageValue;

  String label(AppL10n l10n) => switch (this) {
    AppListFilter.all => l10n.appListFilterAll,
    AppListFilter.system => l10n.appListFilterSystem,
    AppListFilter.user => l10n.appListFilterUser,
    AppListFilter.selected => l10n.appListFilterSelected,
  };

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
  labelAsc('LABEL_ASC'),
  labelDesc('LABEL_DESC'),
  packageAsc('PACKAGE_ASC'),
  packageDesc('PACKAGE_DESC');

  const AppListSort(this.storageValue);

  final String storageValue;

  String label(AppL10n l10n) => switch (this) {
    AppListSort.labelAsc => l10n.appListSortLabelAsc,
    AppListSort.labelDesc => l10n.appListSortLabelDesc,
    AppListSort.packageAsc => l10n.appListSortPackageAsc,
    AppListSort.packageDesc => l10n.appListSortPackageDesc,
  };

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

import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Re-exported so a page reading [legacySettingsProvider] gets the type and its extensions at once.
export 'package:diting/data/prefs/legacy_settings.dart';

/// Overridden with the Android snapshot in `main()`; the memory default lets tests and non-Android
/// hosts start with the documented defaults.
final legacyPrefsStoreProvider = Provider<LegacyPrefsStore>(
  (ref) => MemoryLegacyPrefsStore(),
);

/// Bumped after any write through [LegacySettings]; writes are fire-and-forget, so pages must
/// depend on it.
class LegacySettingsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final legacySettingsRevisionProvider =
    NotifierProvider<LegacySettingsRevision, int>(LegacySettingsRevision.new);

final legacySettingsProvider = Provider<LegacySettings>((ref) {
  ref.watch(legacySettingsRevisionProvider);
  return LegacySettings(ref.watch(legacyPrefsStoreProvider));
});

extension LegacySettingsWrite on WidgetRef {
  void writeSettings(void Function(LegacySettings settings) write) {
    write(read(legacySettingsProvider));
    read(legacySettingsRevisionProvider.notifier).bump();
  }
}

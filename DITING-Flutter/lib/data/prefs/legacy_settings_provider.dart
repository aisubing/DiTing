import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Re-exported so a page that reads [legacySettingsProvider] also gets the type
/// and its extension accessors from one import.
export 'package:diting/data/prefs/legacy_settings.dart';

/// Loaded once in `main()` and overridden with the Android snapshot. The
/// default memory store lets tests and non-Android hosts start with the
/// documented defaults instead of crashing on a missing plugin.
final legacyPrefsStoreProvider = Provider<LegacyPrefsStore>(
  (ref) => MemoryLegacyPrefsStore(),
);

/// Bumped after any write through [LegacySettings].
///
/// Writes are fire-and-forget and nothing is observable, so pages reading a
/// setting must depend on this counter to see edits made on other screens.
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

/// Convenience for `ref.read(legacySettingsProvider) + write + bump()`.
extension LegacySettingsWrite on WidgetRef {
  /// Runs [write] against the current settings and notifies every reader.
  void writeSettings(void Function(LegacySettings settings) write) {
    write(read(legacySettingsProvider));
    read(legacySettingsRevisionProvider.notifier).bump();
  }
}

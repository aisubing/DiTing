import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Most call sites read settings through [legacySettingsProvider]; re-exporting
/// the type keeps the extension accessors (a separate part of that library) in
/// scope without every page importing two files.
export 'package:diting/data/prefs/legacy_settings.dart';

/// Loaded once in `main()` and overridden with the Android snapshot.
///
/// The default is an empty memory store, so tests and non-Android hosts start
/// with the documented defaults instead of crashing on a missing plugin.
final legacyPrefsStoreProvider = Provider<LegacyPrefsStore>(
  (ref) => MemoryLegacyPrefsStore(),
);

/// Bumped after any write through [LegacySettings].
///
/// `LegacySettings` is a thin view over SharedPreferences: writes are fire-and-
/// forget and nothing is observable. Pages that read a setting must depend on
/// this counter (directly or via [legacySettingsProvider]) so an edit on one
/// screen is reflected on the others, exactly like 1.4.3's preference listeners.
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

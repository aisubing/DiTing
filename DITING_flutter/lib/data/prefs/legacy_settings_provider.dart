import 'package:diting/data/prefs/legacy_prefs_store.dart';
import 'package:diting/data/prefs/legacy_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Loaded once in `main()` and overridden with the Android snapshot.
///
/// The default is an empty memory store, so tests and non-Android hosts start
/// with the documented defaults instead of crashing on a missing plugin.
final legacyPrefsStoreProvider = Provider<LegacyPrefsStore>(
  (ref) => MemoryLegacyPrefsStore(),
);

final legacySettingsProvider = Provider<LegacySettings>(
  (ref) => LegacySettings(ref.watch(legacyPrefsStoreProvider)),
);

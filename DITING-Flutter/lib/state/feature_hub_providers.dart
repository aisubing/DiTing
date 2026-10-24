/// Hidden card set and the log long-press hint; keys must match `featureKey` in
/// `lib/data/mock_feature_hub.dart`.
library;

import 'package:diting/data/mock_data.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `HiddenFeaturesStore.PREFS_NAME` (global UI container).
const hiddenFeaturesContainer = LegacySettings.uiContainer;

/// `HiddenFeaturesStore.KEY_HIDDEN_FEATURES`.
const hiddenFeaturesKey = 'hidden_features_set';

/// The same key list in source order, pinned against `mock_feature_hub.dart` by the tests.
const hiddenFeatureKeysInFile = <String>[
  'provider_management',
  'bootstrap_settings',
  'resolution_mode',
  'cache_settings',
  'rule_control',
  'blacklist',
  'whitelist',
  'rewrite_list',
  'traffic_stats',
  'app_rules',
  'blocked_apps',
  'excluded_apps',
  'https_inspection',
  'outbound_proxy',
  'network_tools',
  'agent_api',
  'appearance',
  'service_display',
  'other_settings',
  'logs',
  'data_management',
  'data_cleanup',
  'app_info',
  'sponsor',
  'sponsor_list',
  'contributors',
];

/// Currently hidden feature keys, persisted. Readers watch the revision, or the hub keeps stale
/// cards.
class HiddenFeatureKeysNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(legacySettingsRevisionProvider);
    final store = ref.watch(legacyPrefsStoreProvider);
    final value = store.read(hiddenFeaturesContainer, hiddenFeaturesKey);
    // The bridge delivers a List, and old installs may hold a JSON string.
    if (value is List) {
      return {
        for (final item in value)
          if (item is String && item.isNotEmpty) item,
      };
    }
    return const {};
  }

  void setVisible(String key, bool visible) {
    final next = {...state};
    if (visible) {
      next.remove(key);
    } else {
      next.add(key);
    }
    _write(next);
  }

  void toggle(String key) => setVisible(key, !state.contains(key));

  void resetAll() => _write(const {});

  void _write(Set<String> next) {
    ref
        .read(legacyPrefsStoreProvider)
        .putStringSet(hiddenFeaturesContainer, hiddenFeaturesKey, next);
    ref.read(legacySettingsRevisionProvider.notifier).bump();
  }
}

final hiddenFeatureKeysProvider =
    NotifierProvider<HiddenFeatureKeysNotifier, Set<String>>(
      HiddenFeatureKeysNotifier.new,
    );

/// Visible hub categories for the current mode; both pages read it so the filtering cannot drift.
final visibleFeatureCategoriesProvider = Provider<List<MockFeatureCategory>>((
  ref,
) {
  final express = ref.watch(workModeProvider) == AppWorkMode.express;
  final hidden = ref.watch(hiddenFeatureKeysProvider);
  return visibleFeatureCategories(express: express, hiddenKeys: hidden);
});

/// Whether the log card's long-press hint was acknowledged. Session-only, 1.4.3 has no storage key.
class LogLongPressHintNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void acknowledge() => state = false;
}

final logLongPressHintProvider =
    NotifierProvider<LogLongPressHintNotifier, bool>(
      LogLongPressHintNotifier.new,
    );

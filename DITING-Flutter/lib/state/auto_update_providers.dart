/// Subscription auto-update settings: master switch, interval and per-group switches; nothing is
/// rescheduled.
library;

import 'package:diting/data/db/subscription_models.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AutoUpdateSettings {
  const AutoUpdateSettings({
    required this.enabled,
    required this.intervalHours,
  });

  final bool enabled;
  final int intervalHours;

  /// Whether the interval is a preset; drives the custom-interval row highlight.
  bool get isCustom =>
      !LegacySettings.subscriptionAutoUpdatePresetHours.contains(intervalHours);
}

final autoUpdateSettingsProvider = Provider<AutoUpdateSettings>((ref) {
  final settings = ref.watch(legacySettingsProvider);
  return AutoUpdateSettings(
    enabled: settings.subscriptionAutoUpdateEnabled,
    intervalHours: settings.subscriptionAutoUpdateIntervalHours,
  );
});

/// Settings writer; bumps the revision so `autoUpdateSettingsProvider` rebuilds.
class AutoUpdateActions {
  AutoUpdateActions(this._ref);

  final Ref _ref;

  void setEnabled(bool enabled) {
    final settings = _ref.read(legacySettingsProvider);
    settings.setSubscriptionAutoUpdateEnabled(enabled);
    // 1.4.3 keeps the chosen interval when the master switch is turned off.
    _ref.read(legacySettingsRevisionProvider.notifier).bump();
  }

  /// Rejects intervals outside 1-168 and returns false so the caller can warn.
  bool setIntervalHours(int hours) {
    if (hours < LegacySettings.minSubscriptionAutoUpdateIntervalHours ||
        hours > LegacySettings.maxSubscriptionAutoUpdateIntervalHours) {
      return false;
    }
    final settings = _ref.read(legacySettingsProvider);
    settings.setSubscriptionAutoUpdateIntervalHours(hours);
    _ref.read(legacySettingsRevisionProvider.notifier).bump();
    return true;
  }

  /// Group switch, stored in the `subscription_group.autoUpdateEnabled` column.
  Future<void> setGroupEnabled(int groupId, bool enabled) async {
    final repository = await _ref.read(subscriptionRepositoryProvider.future);
    await repository?.setGroupAutoUpdateEnabled(groupId, enabled);
  }
}

final autoUpdateActionsProvider = Provider<AutoUpdateActions>(
  AutoUpdateActions.new,
);

/// Groups with their auto-update switch, straight from `subscription_group` rows.
final autoUpdateGroupsProvider = FutureProvider<List<SubscriptionGroupRecord>>(
  (ref) => ref.watch(subscriptionGroupsProvider.future),
);

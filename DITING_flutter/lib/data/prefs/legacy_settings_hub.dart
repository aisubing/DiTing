part of 'legacy_settings.dart';

/// Keys owned by the app-list / CA screens that the DNS part does not cover.
///
/// Every name below is copied verbatim from
/// `Android/app/src/main/java/com/haoze/diting/ui/settings/AppRulesSettingsStore.kt`;
/// one renamed key silently resets that setting for an upgraded install.
///
/// All five live in the **global** container (`dns_vpn_prefs`), not in a dataset
/// container: 1.4.3 reads them through `SettingsPreferencesExtensions.PREFS_NAME`
/// regardless of the active work mode, so an express-mode instance must still
/// see the same values.
extension LegacyHubSettings on LegacySettings {
  /// `excluded_apps_filter`. The four values are `AppListFilter` enum names:
  /// `ALL` / `SYSTEM` / `USER` / `SELECTED`; an unknown value falls back to
  /// `USER` exactly like `AppListFilter.entries.firstOrNull { it.name == ... }`.
  String get excludedAppsFilterRaw =>
      _string(LegacySettings.uiContainer, 'excluded_apps_filter') ?? 'USER';

  void setExcludedAppsFilterRaw(String value) => _store.putString(
    LegacySettings.uiContainer,
    'excluded_apps_filter',
    value,
  );

  /// `excluded_apps_sort`. Values are `AppListSort` enum names:
  /// `LABEL_ASC` / `LABEL_DESC` / `PACKAGE_ASC` / `PACKAGE_DESC`.
  String get excludedAppsSortRaw =>
      _string(LegacySettings.uiContainer, 'excluded_apps_sort') ?? 'LABEL_ASC';

  void setExcludedAppsSortRaw(String value) =>
      _store.putString(LegacySettings.uiContainer, 'excluded_apps_sort', value);

  /// `app_allowlist_filter` — same enum as [excludedAppsFilterRaw] but its own
  /// key, and its default is `USER` rather than inheriting the excluded filter.
  String get appAllowlistFilterRaw =>
      _string(LegacySettings.uiContainer, 'app_allowlist_filter') ?? 'USER';

  void setAppAllowlistFilterRaw(String value) => _store.putString(
    LegacySettings.uiContainer,
    'app_allowlist_filter',
    value,
  );

  /// `app_allowlist_sort` — default `LABEL_ASC` (`AppListSort.LABEL_ASC`).
  String get appAllowlistSortRaw =>
      _string(LegacySettings.uiContainer, 'app_allowlist_sort') ?? 'LABEL_ASC';

  void setAppAllowlistSortRaw(String value) =>
      _store.putString(LegacySettings.uiContainer, 'app_allowlist_sort', value);

  /// `https_bypass_rules`: the **custom** half of the MITM bypass list.
  ///
  /// `GoTunnelRuleManager.updatePassthroughRules` unions this set with the
  /// preset whitelist parsed from `assets/https_passthrough.txt` and hands the
  /// result to `Engine.setExtraPassthroughSuffixes`. Storing the presets here
  /// would duplicate them on every push, so this getter stays custom-only.
  Set<String> get httpsBypassRules =>
      _stringSet('https_bypass_rules', container: LegacySettings.uiContainer) ??
      const {};

  void setHttpsBypassRules(Set<String> rules) =>
      _store.putStringSet(LegacySettings.uiContainer, 'https_bypass_rules', {
        for (final rule in rules)
          if (rule.trim().isNotEmpty) rule.trim(),
      });
}

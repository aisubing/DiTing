part of 'legacy_settings.dart';

/// Keys owned by the app-list / CA screens. Every name is a verbatim legacy key; renaming one
/// silently resets that setting on upgrade, and all five live in the global `dns_vpn_prefs`.
extension LegacyHubSettings on LegacySettings {
  /// `ALL` / `SYSTEM` / `USER` / `SELECTED`, returned raw, so consumers fall back to `USER`.
  String get excludedAppsFilterRaw =>
      _string(LegacySettings.uiContainer, 'excluded_apps_filter') ?? 'USER';

  void setExcludedAppsFilterRaw(String value) => _store.putString(
    LegacySettings.uiContainer,
    'excluded_apps_filter',
    value,
  );

  /// `LABEL_ASC` / `LABEL_DESC` / `PACKAGE_ASC` / `PACKAGE_DESC`.
  String get excludedAppsSortRaw =>
      _string(LegacySettings.uiContainer, 'excluded_apps_sort') ?? 'LABEL_ASC';

  void setExcludedAppsSortRaw(String value) =>
      _store.putString(LegacySettings.uiContainer, 'excluded_apps_sort', value);

  /// Same values as [excludedAppsFilterRaw], own key, defaulting to `USER`.
  String get appAllowlistFilterRaw =>
      _string(LegacySettings.uiContainer, 'app_allowlist_filter') ?? 'USER';

  void setAppAllowlistFilterRaw(String value) => _store.putString(
    LegacySettings.uiContainer,
    'app_allowlist_filter',
    value,
  );

  String get appAllowlistSortRaw =>
      _string(LegacySettings.uiContainer, 'app_allowlist_sort') ?? 'LABEL_ASC';

  void setAppAllowlistSortRaw(String value) =>
      _store.putString(LegacySettings.uiContainer, 'app_allowlist_sort', value);

  /// The custom half of the MITM bypass list; presets from `assets/https_passthrough.txt` are
  /// unioned in, never stored here.
  Set<String> get httpsBypassRules =>
      _stringSet('https_bypass_rules', container: LegacySettings.uiContainer) ??
      const {};

  void setHttpsBypassRules(Set<String> rules) =>
      _store.putStringSet(LegacySettings.uiContainer, 'https_bypass_rules', {
        for (final rule in rules)
          if (rule.trim().isNotEmpty) rule.trim(),
      });
}

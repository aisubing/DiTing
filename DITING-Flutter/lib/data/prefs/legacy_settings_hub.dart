part of 'legacy_settings.dart';

/// Keys owned by the app-list / CA screens.
///
/// Every name is a verbatim legacy key; renaming one silently resets that
/// setting for an upgraded install. All five live in the global
/// `dns_vpn_prefs` container, since they are not dataset-scoped, so an
/// express-mode instance sees the same values.
extension LegacyHubSettings on LegacySettings {
    /// `excluded_apps_filter`: `ALL` / `SYSTEM` / `USER` / `SELECTED`. The value
    /// is returned raw, so consumers fall back to `USER` on anything unknown.
  String get excludedAppsFilterRaw =>
      _string(LegacySettings.uiContainer, 'excluded_apps_filter') ?? 'USER';

  void setExcludedAppsFilterRaw(String value) => _store.putString(
    LegacySettings.uiContainer,
    'excluded_apps_filter',
    value,
  );

    /// `excluded_apps_sort`: `LABEL_ASC` / `LABEL_DESC` / `PACKAGE_ASC` /
    /// `PACKAGE_DESC`.
  String get excludedAppsSortRaw =>
      _string(LegacySettings.uiContainer, 'excluded_apps_sort') ?? 'LABEL_ASC';

  void setExcludedAppsSortRaw(String value) =>
      _store.putString(LegacySettings.uiContainer, 'excluded_apps_sort', value);

    /// `app_allowlist_filter`: same values as [excludedAppsFilterRaw] but its own
    /// key, defaulting to `USER`.
  String get appAllowlistFilterRaw =>
      _string(LegacySettings.uiContainer, 'app_allowlist_filter') ?? 'USER';

  void setAppAllowlistFilterRaw(String value) => _store.putString(
    LegacySettings.uiContainer,
    'app_allowlist_filter',
    value,
  );

    /// `app_allowlist_sort`, default `LABEL_ASC`.
  String get appAllowlistSortRaw =>
      _string(LegacySettings.uiContainer, 'app_allowlist_sort') ?? 'LABEL_ASC';

  void setAppAllowlistSortRaw(String value) =>
      _store.putString(LegacySettings.uiContainer, 'app_allowlist_sort', value);

    /// `https_bypass_rules`: the custom half of the MITM bypass list.
    ///
    /// The tunnel rule manager unions it with the presets from
    /// `assets/https_passthrough.txt`, so presets must not be stored here.
  Set<String> get httpsBypassRules =>
      _stringSet('https_bypass_rules', container: LegacySettings.uiContainer) ??
      const {};

  void setHttpsBypassRules(Set<String> rules) =>
      _store.putStringSet(LegacySettings.uiContainer, 'https_bypass_rules', {
        for (final rule in rules)
          if (rule.trim().isNotEmpty) rule.trim(),
      });
}

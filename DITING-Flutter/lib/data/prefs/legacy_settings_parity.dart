part of 'legacy_settings.dart';

/// Legacy keys for app behaviour, language, notifications, log mode, background
/// and update checks.
///
/// Key names and container names are copied verbatim from the legacy stores:
/// writing to the wrong container stores the value where the legacy app never
/// reads it, so upgrading and downgrading both lose the setting silently.
///
/// Static members must be written as `LegacySettings.xxx`, because an extension
/// cannot reference static members of the extended type unqualified.
/// `dnsContainer` is an instance field and can be used directly.
extension LegacySettingsParity on LegacySettings {
    /// Short alias for the global UI container, so getters need not repeat the
    /// `LegacySettings.` type qualifier.
  String get _ui => LegacySettings.uiContainer;

    /// Short alias for the notification container, for the same reason.
  String get _notification => LegacySettings.notificationContainer;


    /// `dns_log_mode`, stored in the dataset container because it says how that
    /// dataset records, not a global preference. Values: `all` /
    /// `blocked_and_errors` / `off`.
  String get dnsLogModeRaw => _string(dnsContainer, 'dns_log_mode') ?? 'all';

  void setDnsLogModeRaw(String storageValue) =>
      _store.putString(dnsContainer, 'dns_log_mode', storageValue);

    /// `log_retention_days`, 1-30, default 7.
  int get logRetentionDays => _int(_ui, 'log_retention_days', 7);

  void setLogRetentionDays(int days) =>
      _store.putInt(_ui, 'log_retention_days', days.clamp(1, 30));

    /// `floating_log_enabled`: the log overlay, default off.
  bool get floatingLogEnabled => _bool(_ui, 'floating_log_enabled', false);

  void setFloatingLogEnabled(bool value) =>
      _store.putBool(_ui, 'floating_log_enabled', value);


    /// `hide_from_recents_enabled`, default off. Applied natively on activity
    /// create and resume, where it also disables the recents screenshot.
  bool get hideFromRecentsEnabled =>
      _bool(_ui, 'hide_from_recents_enabled', false);

  void setHideFromRecentsEnabled(bool value) =>
      _store.putBool(_ui, 'hide_from_recents_enabled', value);

    /// `bypass_lan_enabled`: bypass LAN addresses, default on.
  void setBypassLanEnabled(bool value) =>
      _store.putBool(_ui, 'bypass_lan_enabled', value);

    /// `ipv6_mode`: `auto` / `disable` / `prefer`. The route config treats
    /// anything other than `auto` as not supported.
  void setIpv6ModeRaw(String storageValue) =>
      _store.putString(dnsContainer, 'ipv6_mode', storageValue);


    /// `app_language_mode`: `system` / `chinese`. Persisted only; it does not
    /// switch the runtime locale, which is still Chinese-only.
  String get appLanguageModeRaw =>
      _string(_ui, 'app_language_mode') ?? 'system';

  void setAppLanguageModeRaw(String storageValue) =>
      _store.putString(_ui, 'app_language_mode', storageValue);


    /// `initial_agreement_accepted`: whether the first-launch disclaimer dialog
    /// was accepted.
  bool get initialAgreementAccepted =>
      _bool(_ui, 'initial_agreement_accepted', false);

  void setInitialAgreementAccepted(bool value) =>
      _store.putBool(_ui, 'initial_agreement_accepted', value);

    /// `disable_startup_update_check`, default true: inverted on purpose, so the
    /// default means the startup check is off.
  bool get disableStartupUpdateCheck =>
      _bool(_ui, 'disable_startup_update_check', true);

  void setDisableStartupUpdateCheck(bool value) =>
      _store.putBool(_ui, 'disable_startup_update_check', value);


    /// `custom_background_enabled` / `custom_background_uri` /
    /// `custom_background_uris`. The `_uri` key is the image in effect, while
    /// `_uris` is the full history list.
  bool get customBackgroundEnabled =>
      _bool(_ui, 'custom_background_enabled', false);

  void setCustomBackgroundEnabled(bool value) =>
      _store.putBool(_ui, 'custom_background_enabled', value);

  String? get customBackgroundUri => _string(_ui, 'custom_background_uri');

  void setCustomBackgroundUri(String uri) =>
      _store.putString(_ui, 'custom_background_uri', uri);

    /// Background history as a JSON array, in the order the user added them.
  List<String> get customBackgroundUris {
    final raw = _string(_ui, 'custom_background_uris');
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is String && item.trim().isNotEmpty) item,
      ];
    } on FormatException {
      return const [];
    }
  }

  void setCustomBackgroundUris(List<String> uris) => _store.putString(
    _ui,
    'custom_background_uris',
    jsonEncode([
      for (final uri in uris)
        if (uri.trim().isNotEmpty) uri,
    ]),
  );


    /// All notification keys live in the separate `notification_settings_prefs`
    /// container, because the foreground service reads that one; writing them
    /// elsewhere has no effect.
  bool get notificationPersistent => _bool(_notification, 'persistent', true);

  void setNotificationPersistent(bool value) =>
      _store.putBool(_notification, 'persistent', value);

    /// `speed`: show the live rate in the ongoing notification, default off.
  bool get notificationSpeed => _bool(_notification, 'speed', false);

  void setNotificationSpeed(bool value) =>
      _store.putBool(_notification, 'speed', value);

    /// Two notification texts: running and stopped.
  ({String running, String stopped}) get notificationTexts => (
    running: _string(_notification, 'custom_running_text') ?? '',
    stopped: _string(_notification, 'custom_stopped_text') ?? '',
  );

  void setNotificationTexts({
    required String running,
    required String stopped,
  }) {
    _store.putString(_notification, 'custom_running_text', running);
    _store.putString(_notification, 'custom_stopped_text', stopped);
  }


    /// Auto-update keys live in the dataset container, chosen per rule dataset.
    /// Writing them to `uiContainer` would make express and server modes share
    /// one switch, while the legacy app kept three independent ones.
    ///
    /// Defaults: off, interval 24 hours, valid range 1-168.
  bool get subscriptionAutoUpdateEnabled => _bool(
    dnsContainer,
    LegacySettings.subscriptionAutoUpdateEnabledKey,
    false,
  );

  int get subscriptionAutoUpdateIntervalHours {
    final value = _int(
      dnsContainer,
      LegacySettings.subscriptionAutoUpdateIntervalKey,
      LegacySettings.defaultSubscriptionAutoUpdateIntervalHours,
    );
    return value >= LegacySettings.minSubscriptionAutoUpdateIntervalHours &&
            value <= LegacySettings.maxSubscriptionAutoUpdateIntervalHours
        ? value
        : LegacySettings.defaultSubscriptionAutoUpdateIntervalHours;
  }

  void setSubscriptionAutoUpdateEnabled(bool value) => _store.putBool(
    dnsContainer,
    LegacySettings.subscriptionAutoUpdateEnabledKey,
    value,
  );

  void setSubscriptionAutoUpdateIntervalHours(int hours) => _store.putInt(
    dnsContainer,
    LegacySettings.subscriptionAutoUpdateIntervalKey,
    hours.clamp(
      LegacySettings.minSubscriptionAutoUpdateIntervalHours,
      LegacySettings.maxSubscriptionAutoUpdateIntervalHours,
    ),
  );


    /// The nine AI analysis keys are global (`dns_vpn_prefs`), shared by the log,
    /// domain and parameter pages, so they must not use `dnsContainer`.
    ///
    /// Defaults: enabled, DeepSeek, `deepseek-flash`, temperature 0.7, empty
    /// system prompt.
  bool get agentApiEnabled => _bool(_ui, 'agent_api_enabled', true);

  void setAgentApiEnabled(bool value) =>
      _store.putBool(_ui, 'agent_api_enabled', value);

    /// Plain-text key, matching what the legacy store wrote; only the keys inside
    /// the providers list are obfuscated.
  String get agentApiKey => _string(_ui, 'agent_api_key') ?? '';

  void setAgentApiKey(String value) =>
      _store.putString(_ui, 'agent_api_key', value.trim());

  String get agentApiBaseUrl =>
      _string(_ui, 'agent_api_base_url')?.trim().isNotEmpty == true
      ? _string(_ui, 'agent_api_base_url')!.trim()
      : 'https://api.deepseek.com/v1';

  void setAgentApiBaseUrl(String value) =>
      _store.putString(_ui, 'agent_api_base_url', value.trim());

  String get agentApiModel {
    final model = _string(_ui, 'agent_api_model')?.trim();
    return model == null || model.isEmpty ? 'deepseek-flash' : model;
  }

  void setAgentApiModel(String value) =>
      _store.putString(_ui, 'agent_api_model', value.trim());

    /// Stored as a string, not a float, by the legacy app; both forms are read
    /// because early installs may hold either, and a mismatch silently falls back
    /// to 0.7.
  double get agentApiTemperature {
    final raw = _store.read(_ui, 'agent_api_temperature');
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      final parsed = double.tryParse(raw.trim());
      if (parsed != null) return parsed;
    }
    return 0.7;
  }

  void setAgentApiTemperature(double value) =>
      _store.putString(_ui, 'agent_api_temperature', value.toStringAsFixed(1));

  String get agentApiSystemPrompt =>
      _string(_ui, 'agent_api_system_prompt') ?? '';

  void setAgentApiSystemPrompt(String value) =>
      _store.putString(_ui, 'agent_api_system_prompt', value);

    /// `agent_ai_providers_json`. `null` means first launch, where the list must
    /// be migrated or seeded by the legacy migration rules.
  String? get agentAiProvidersJson => _string(_ui, 'agent_ai_providers_json');

  void setAgentAiProvidersJson(String value) =>
      _store.putString(_ui, 'agent_ai_providers_json', value);

  String get agentAiActiveProviderId =>
      _string(_ui, 'agent_ai_active_provider_id') ?? '';

  void setAgentAiActiveProviderId(String value) =>
      _store.putString(_ui, 'agent_ai_active_provider_id', value);
}

part of 'legacy_settings.dart';

/// Keys for app behaviour, language, notifications, log mode, background and update checks. Names
/// are verbatim; writing to the wrong container stores a value the legacy app never reads.
extension LegacySettingsParity on LegacySettings {
  String get _ui => LegacySettings.uiContainer;

  String get _notification => LegacySettings.notificationContainer;

  /// One of `all` / `blocked_and_errors` / `off`.
  String get dnsLogModeRaw => _string(dnsContainer, 'dns_log_mode') ?? 'all';

  void setDnsLogModeRaw(String storageValue) =>
      _store.putString(dnsContainer, 'dns_log_mode', storageValue);

  /// Dataset-scoped: the native retention sweep reads this key from the data set's own container.
  int get logRetentionDays => _int(dnsContainer, 'log_retention_days', 7);

  void setLogRetentionDays(int days) =>
      _store.putInt(dnsContainer, 'log_retention_days', days.clamp(1, 30));

  bool get floatingLogEnabled => _bool(_ui, 'floating_log_enabled', false);

  void setFloatingLogEnabled(bool value) =>
      _store.putBool(_ui, 'floating_log_enabled', value);

  /// Applied natively on activity create and resume, where it also disables the recents screenshot.
  bool get hideFromRecentsEnabled =>
      _bool(_ui, 'hide_from_recents_enabled', false);

  void setHideFromRecentsEnabled(bool value) =>
      _store.putBool(_ui, 'hide_from_recents_enabled', value);

  void setBypassLanEnabled(bool value) =>
      _store.putBool(_ui, 'bypass_lan_enabled', value);

  /// `auto` / `disable` / `prefer`; the route config supports only `auto`.
  void setIpv6ModeRaw(String storageValue) =>
      _store.putString(dnsContainer, 'ipv6_mode', storageValue);

  /// `system` / `chinese`. Persisted only; it does not switch the runtime locale.
  String get appLanguageModeRaw =>
      _string(_ui, 'app_language_mode') ?? 'system';

  void setAppLanguageModeRaw(String storageValue) =>
      _store.putString(_ui, 'app_language_mode', storageValue);

  bool get initialAgreementAccepted =>
      _bool(_ui, 'initial_agreement_accepted', false);

  void setInitialAgreementAccepted(bool value) =>
      _store.putBool(_ui, 'initial_agreement_accepted', value);

  /// Inverted on purpose: the default `true` means the startup check is off.
  bool get disableStartupUpdateCheck =>
      _bool(_ui, 'disable_startup_update_check', true);

  void setDisableStartupUpdateCheck(bool value) =>
      _store.putBool(_ui, 'disable_startup_update_check', value);

  /// The `_uri` key is the image in effect, `_uris` the full history list.
  bool get customBackgroundEnabled =>
      _bool(_ui, 'custom_background_enabled', false);

  void setCustomBackgroundEnabled(bool value) =>
      _store.putBool(_ui, 'custom_background_enabled', value);

  String? get customBackgroundUri => _string(_ui, 'custom_background_uri');

  void setCustomBackgroundUri(String uri) =>
      _store.putString(_ui, 'custom_background_uri', uri);

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

  /// The foreground service reads `notification_settings_prefs`, so writing these keys elsewhere
  /// has no effect.
  bool get notificationPersistent => _bool(_notification, 'persistent', true);

  void setNotificationPersistent(bool value) =>
      _store.putBool(_notification, 'persistent', value);

  bool get notificationSpeed => _bool(_notification, 'speed', false);

  void setNotificationSpeed(bool value) =>
      _store.putBool(_notification, 'speed', value);

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

  /// Legacy-style bodies composed by Dart (`notification_status_text.dart`): the services cannot
  /// see the provider catalog, so the default is persisted next to the custom text.
  void setNotificationDefaultRunningText(String value) =>
      _store.putString(_notification, 'default_running_text', value);

  void setNotificationDefaultExpressText(String value) =>
      _store.putString(_notification, 'default_express_text', value);

  void setNotificationDefaultServerText(String value) =>
      _store.putString(_notification, 'default_server_text', value);

  /// Dataset container: one shared switch would make express and server modes change together.
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

  /// The nine AI analysis keys are global and shared by the log, domain and parameter pages.
  bool get agentApiEnabled => _bool(_ui, 'agent_api_enabled', true);

  void setAgentApiEnabled(bool value) =>
      _store.putBool(_ui, 'agent_api_enabled', value);

  /// Plain text, as the legacy store wrote it; only the keys inside the providers list are
  /// obfuscated.
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

  /// The legacy app stored a string, so early installs may hold either form; unparsable values fall
  /// back to 0.7.
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

  /// Null means first launch, where the legacy migration rules seed or migrate the list.
  String? get agentAiProvidersJson => _string(_ui, 'agent_ai_providers_json');

  void setAgentAiProvidersJson(String value) =>
      _store.putString(_ui, 'agent_ai_providers_json', value);

  String get agentAiActiveProviderId =>
      _string(_ui, 'agent_ai_active_provider_id') ?? '';

  void setAgentAiActiveProviderId(String value) =>
      _store.putString(_ui, 'agent_ai_active_provider_id', value);
}

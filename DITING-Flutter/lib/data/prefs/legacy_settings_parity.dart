part of 'legacy_settings.dart';

/// 本轮新增的旧版键：前后台行为 / 语言 / 通知栏 / 日志模式 / 背景图 / 更新检查。
///
/// 每个键名都逐字照抄 1.4.3 的 store，容器归属也照抄——写错容器等于「设置能存
/// 但旧版读不到」，升级与降级都会丢设置，而界面上完全看不出来。三个来源：
/// - `ui/settings/SystemSettingsStore.kt`（`dns_vpn_prefs`）
/// - `notification/NotificationSettingsStore.kt`（`notification_settings_prefs`）
/// - `ui/settings/AppearanceSettingsStore.kt`（`dns_vpn_prefs`）
///
/// 静态常量必须写成 `LegacySettings.xxx`：扩展不能无限定地引用被扩展类型的静态
/// 成员（`unqualified_reference_to_static_member_of_extended_type`）。`dnsContainer`
/// 是实例字段，可以直接用。
extension LegacySettingsParity on LegacySettings {
  /// 全局 UI 容器的短别名。扩展里必须经由类型限定，所以这里单独包一层，
  /// 免得每个 getter 都写一遍 `LegacySettings.`。
  String get _ui => LegacySettings.uiContainer;

  /// 通知栏容器的短别名，理由同上。
  String get _notification => LegacySettings.notificationContainer;

  // -------------------------------------------------------- 日志模式（数据集）

  /// `dns_log_mode`。1.4.3 把它存在**数据集容器**里（普通模式 `dns_vpn_prefs`、
  /// 极速模式 `diting_express_prefs`），与 `dns_resolution_mode` 同一份：日志
  /// 模式是「这个数据集怎么记」，不是全局偏好。三个值是 `LegacyLogMode` 的
  /// storageValue：`all` / `blocked_and_errors` / `off`。
  String get dnsLogModeRaw => _string(dnsContainer, 'dns_log_mode') ?? 'all';

  void setDnsLogModeRaw(String storageValue) =>
      _store.putString(dnsContainer, 'dns_log_mode', storageValue);

  /// `log_retention_days`，1–30，默认 7（`SystemSettingsStore`）。
  int get logRetentionDays => _int(_ui, 'log_retention_days', 7);

  void setLogRetentionDays(int days) =>
      _store.putInt(_ui, 'log_retention_days', days.clamp(1, 30));

  /// `floating_log_enabled`：日志浮窗，默认关闭。
  bool get floatingLogEnabled => _bool(_ui, 'floating_log_enabled', false);

  void setFloatingLogEnabled(bool value) =>
      _store.putBool(_ui, 'floating_log_enabled', value);

  // ------------------------------------------------------ 前后台行为 / 隐私

  /// `hide_from_recents_enabled`：从最近任务列表隐藏，默认关闭。
  ///
  /// `SystemSettingsStore` 的默认值是 `false`；`RecentsPrivacyController.apply()`
  /// 在 `MainActivity.onCreate` / `onResume` 里读它并设置
  /// `setRecentsScreenshotEnabled` / `excludeFromRecents`。
  bool get hideFromRecentsEnabled =>
      _bool(_ui, 'hide_from_recents_enabled', false);

  void setHideFromRecentsEnabled(bool value) =>
      _store.putBool(_ui, 'hide_from_recents_enabled', value);

  /// `bypass_lan_enabled`：绕过局域网，默认**开启**。写侧此前缺失
  /// （`VpnRouteConfig` 只读），「前后台行为」页需要它能改。
  void setBypassLanEnabled(bool value) =>
      _store.putBool(_ui, 'bypass_lan_enabled', value);

  /// `ipv6_mode`：`auto` / `disable` / `prefer`（`VpnRouteConfig` 只认 `auto`
  /// 与「其余」，其余一律按不支持处理）。
  void setIpv6ModeRaw(String storageValue) =>
      _store.putString(dnsContainer, 'ipv6_mode', storageValue);

  // --------------------------------------------------------------- 语言设置

  /// `app_language_mode`：`system` / `chinese`。
  ///
  /// 1.4.3 的 `LANGUAGE_SETTINGS` 页只有「跟随系统 / 中文」两项（英文选项在
  /// 枚举里预留了但没有文案资源，因此界面上不存在）。本轮照旧：只落这两个值，
  /// 落盘但不改运行时语言（Flutter 侧还没有英文资源）。
  String get appLanguageModeRaw =>
      _string(_ui, 'app_language_mode') ?? 'system';

  void setAppLanguageModeRaw(String storageValue) =>
      _store.putString(_ui, 'app_language_mode', storageValue);

  // --------------------------------------------------------------- 启动与须知

  /// `initial_agreement_accepted`：首启免责声明是否已确认。
  ///
  /// 上一轮免责声明是一个独立路由页（`/disclaimer`），没有「首次启动」这个
  /// 时机，这个键也就没人读。本轮改回首启弹窗（旧版 `MainActivityDialogs` 的
  /// 「使用须知与免责声明」），它才重新有意义。
  bool get initialAgreementAccepted =>
      _bool(_ui, 'initial_agreement_accepted', false);

  void setInitialAgreementAccepted(bool value) =>
      _store.putBool(_ui, 'initial_agreement_accepted', value);

  /// `disable_startup_update_check`：默认 **true**（即默认关闭启动检查）。
  ///
  /// 取反语义容易写反：键名叫 disable，默认值为 true 表示「默认不检查」。
  bool get disableStartupUpdateCheck =>
      _bool(_ui, 'disable_startup_update_check', true);

  void setDisableStartupUpdateCheck(bool value) =>
      _store.putBool(_ui, 'disable_startup_update_check', value);

  // ------------------------------------------------------------- 软件背景图

  /// `custom_background_enabled` / `custom_background_uri` / `custom_background_uris`。
  ///
  /// 1.4.3 用 `ActivityResultContracts.PickVisualMedia` 选图，把 URI 存成
  /// `custom_background_uris`（多张）并在选第一张时把 `_uri` 也写上。这里保持
  /// 同一套键：`uri` 是「当前生效的那张」，`uris` 是历史清单。
  bool get customBackgroundEnabled =>
      _bool(_ui, 'custom_background_enabled', false);

  void setCustomBackgroundEnabled(bool value) =>
      _store.putBool(_ui, 'custom_background_enabled', value);

  String? get customBackgroundUri => _string(_ui, 'custom_background_uri');

  void setCustomBackgroundUri(String uri) =>
      _store.putString(_ui, 'custom_background_uri', uri);

  /// 历史壁纸清单，以 JSON 数组存放，顺序即用户添加顺序。
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

  // ------------------------------------------------------------- 通知栏设置

  /// 通知栏四个键都在独立的 `notification_settings_prefs` 容器里。
  ///
  /// 容器不能换成 `dns_vpn_prefs`：旧版的 `NotificationSettingsStore` 用的是
  /// 自己那份 prefs，前台服务读的也是它。写到别的容器，通知栏行为不会变。
  bool get notificationPersistent => _bool(_notification, 'persistent', true);

  void setNotificationPersistent(bool value) =>
      _store.putBool(_notification, 'persistent', value);

  /// `speed`：在常驻通知里显示实时速率，默认关闭。
  bool get notificationSpeed => _bool(_notification, 'speed', false);

  void setNotificationSpeed(bool value) =>
      _store.putBool(_notification, 'speed', value);

  /// 一条通知文案有两份：运行中与已停止。
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

  // ------------------------------------------------------- 订阅自动更新（数据集）

  /// 自动更新的两个键在**数据集容器**里（`dns_vpn_prefs` / `diting_express_prefs`
  /// / `diting_dns_mode_prefs`），由 `SubscriptionAutoUpdateSettings` 按
  /// `RuleDataset.prefsName()` 选容器。写到 `uiContainer` 会让极速模式与服务器
  /// 模式共用同一份开关，而旧版三份是彼此独立的。
  ///
  /// 默认值逐字照抄旧版：**关闭**、间隔 24 小时，合法区间 1–168。
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

  // --------------------------------------------------------- AI 分析（Agent）

  /// AI 分析的九个键，全部在**全局** `dns_vpn_prefs`（`AgentApiSettingsStore`
  /// 用的是 `PREFS_NAME`，不是数据集容器）。本仓的 AI 分析是全局能力：日志页、
  /// 域名页与参数页共用一份配置，所以不能用 `dnsContainer`。
  ///
  /// 默认值逐字照抄旧版 `AgentApiConfig`：**开启**、DeepSeek、`deepseek-flash`、
  /// 温度 0.7、系统提示词为空。
  bool get agentApiEnabled => _bool(_ui, 'agent_api_enabled', true);

  void setAgentApiEnabled(bool value) =>
      _store.putBool(_ui, 'agent_api_enabled', value);

  /// 明文 Key。`AgentApiSettingsStore.setAgentApiConfig` 存的就是明文（厂商列表里
  /// 的 `apiKey` 才是混淆过的），这里保持一致以免两边读出来的不一样。
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

  /// 旧版把这个键存成**字符串**（`config.temperature.toString()`），不是 float。
  /// 读的时候两种都认：早期安装里可能存在 float，写死一种会让温度静默回落 0.7。
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

  /// 厂商列表的 JSON（`agent_ai_providers_json`）。`null` 表示首次启动，需要按
  /// 旧版 `performInitialMigration` 的规则迁移或播种。
  String? get agentAiProvidersJson => _string(_ui, 'agent_ai_providers_json');

  void setAgentAiProvidersJson(String value) =>
      _store.putString(_ui, 'agent_ai_providers_json', value);

  String get agentAiActiveProviderId =>
      _string(_ui, 'agent_ai_active_provider_id') ?? '';

  void setAgentAiActiveProviderId(String value) =>
      _store.putString(_ui, 'agent_ai_active_provider_id', value);
}

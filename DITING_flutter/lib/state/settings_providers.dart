/// 设置域状态：旧版「其他设置」六行 / 外观子树 / 通知栏 / 前后台行为 / 语言。
///
/// 这些 provider 的共同点：值直接来自 `LegacySettings`，写回同名键后 bump
/// `legacySettingsRevisionProvider` 让所有读者重建。上一轮把外观状态散在
/// `appearance_providers.dart` 与各页面私有 State 里，导致「改了不生效、重进才
/// 生效」；本轮统一走这层。
///
/// 不在这里做的两件事：
/// - **不翻译语言**：Flutter 侧还没有英文资源，`app_language_mode` 只落盘。
/// - **不改运行时行为**：通知栏、后台隐藏、电池优化都靠原生通道生效，页面只负责
///   读写键与提示；通道缺失时页面照常可点，值照样存下来。
library;

import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

LegacySettings _settings(Ref ref) => ref.read(legacySettingsProvider);

void _bump(Ref ref) => ref.read(legacySettingsRevisionProvider.notifier).bump();

// ---------------------------------------------------------------------------
// 日志模式（旧版 dns_log_mode，存在数据集容器里）
// ---------------------------------------------------------------------------

/// 日志记录模式。1.4.3 的 `DnsLogModeScreen` 三档，值即 storageValue。
///
/// 三档对日志仪表盘的正文影响极大：`all` 是完整仪表盘、`blockedAndErrors` 与
/// `off` 各自换成另一套卡片组合（见 `lib/pages/logs/`）。
enum LegacyLogMode {
  all('all', '记录全部', '请求、命中、竞速与拦截都进日志'),
  blockedAndErrors('blocked_and_errors', '仅拦截与错误', '只记录被拦截与出错的请求'),
  off('off', '关闭日志', '不记录任何请求，节省空间');

  const LegacyLogMode(this.storageValue, this.label, this.description);

  final String storageValue;
  final String label;
  final String description;

  static LegacyLogMode fromStorageValue(String? value) => values.firstWhere(
    (mode) => mode.storageValue == value,
    orElse: () => LegacyLogMode.all,
  );
}

class LogModeNotifier extends Notifier<LegacyLogMode> {
  @override
  LegacyLogMode build() =>
      LegacyLogMode.fromStorageValue(_settings(ref).dnsLogModeRaw);

  void select(LegacyLogMode mode) {
    state = mode;
    _settings(ref).setDnsLogModeRaw(mode.storageValue);
    _bump(ref);
  }
}

final logModeProvider = NotifierProvider<LogModeNotifier, LegacyLogMode>(
  LogModeNotifier.new,
);

/// 日志保留天数（1–30，默认 7）。
class LogRetentionNotifier extends Notifier<int> {
  @override
  int build() => _settings(ref).logRetentionDays;

  void set(int days) {
    state = days.clamp(1, 30);
    _settings(ref).setLogRetentionDays(state);
    _bump(ref);
  }
}

final logRetentionProvider = NotifierProvider<LogRetentionNotifier, int>(
  LogRetentionNotifier.new,
);

/// 日志浮窗开关。
class FloatingLogNotifier extends Notifier<bool> {
  @override
  bool build() => _settings(ref).floatingLogEnabled;

  void toggle(bool value) {
    state = value;
    _settings(ref).setFloatingLogEnabled(value);
    _bump(ref);
  }
}

final floatingLogProvider = NotifierProvider<FloatingLogNotifier, bool>(
  FloatingLogNotifier.new,
);

// ---------------------------------------------------------------------------
// 前后台行为（旧版 FOREGROUND_BACKGROUND_SETTINGS）
// ---------------------------------------------------------------------------

/// IPv6 三档。`VpnRouteConfig` 只区分 `auto` 与其余。
enum LegacyIpv6Mode {
  auto('auto', '自动', '按当前网络能力决定是否启用'),
  disable('disable', '关闭', '隧道内不启用 IPv6'),
  prefer('prefer', '优先', '尽量走 IPv6，失败再回落');

  const LegacyIpv6Mode(this.storageValue, this.label, this.description);

  final String storageValue;
  final String label;
  final String description;

  static LegacyIpv6Mode fromStorageValue(String? value) => values.firstWhere(
    (mode) => mode.storageValue == value,
    orElse: () => LegacyIpv6Mode.auto,
  );
}

class ForegroundBackgroundNotifier extends Notifier<ForegroundBackgroundState> {
  @override
  ForegroundBackgroundState build() {
    final settings = _settings(ref);
    return ForegroundBackgroundState(
      hideFromRecents: settings.hideFromRecentsEnabled,
      bypassLan: settings.bypassLanEnabled,
      ipv6Mode: LegacyIpv6Mode.fromStorageValue(settings.ipv6ModeRaw),
    );
  }

  void setHideFromRecents(bool value) {
    state = state.copyWith(hideFromRecents: value);
    _settings(ref).setHideFromRecentsEnabled(value);
    _bump(ref);
  }

  void setBypassLan(bool value) {
    state = state.copyWith(bypassLan: value);
    _settings(ref).setBypassLanEnabled(value);
    _bump(ref);
  }

  void setIpv6Mode(LegacyIpv6Mode mode) {
    state = state.copyWith(ipv6Mode: mode);
    _settings(ref).setIpv6ModeRaw(mode.storageValue);
    _bump(ref);
  }
}

/// 前后台行为的三项取值。
class ForegroundBackgroundState {
  const ForegroundBackgroundState({
    required this.hideFromRecents,
    required this.bypassLan,
    required this.ipv6Mode,
  });

  final bool hideFromRecents;
  final bool bypassLan;
  final LegacyIpv6Mode ipv6Mode;

  ForegroundBackgroundState copyWith({
    bool? hideFromRecents,
    bool? bypassLan,
    LegacyIpv6Mode? ipv6Mode,
  }) => ForegroundBackgroundState(
    hideFromRecents: hideFromRecents ?? this.hideFromRecents,
    bypassLan: bypassLan ?? this.bypassLan,
    ipv6Mode: ipv6Mode ?? this.ipv6Mode,
  );
}

final foregroundBackgroundProvider =
    NotifierProvider<ForegroundBackgroundNotifier, ForegroundBackgroundState>(
      ForegroundBackgroundNotifier.new,
    );

// ---------------------------------------------------------------------------
// 语言（旧版 LANGUAGE_SETTINGS：只有跟随系统 / 中文）
// ---------------------------------------------------------------------------

/// 语言两选一。旧版枚举里预留了英文但没有文案资源，界面上不存在，本轮不臆造。
enum AppLanguageMode {
  system('system', '跟随系统'),
  chinese('chinese', '中文');

  const AppLanguageMode(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static AppLanguageMode fromStorageValue(String? value) => values.firstWhere(
    (mode) => mode.storageValue == value,
    orElse: () => AppLanguageMode.system,
  );
}

class LanguageNotifier extends Notifier<AppLanguageMode> {
  @override
  AppLanguageMode build() =>
      AppLanguageMode.fromStorageValue(_settings(ref).appLanguageModeRaw);

  void select(AppLanguageMode mode) {
    state = mode;
    _settings(ref).setAppLanguageModeRaw(mode.storageValue);
    _bump(ref);
  }
}

final languageModeProvider =
    NotifierProvider<LanguageNotifier, AppLanguageMode>(LanguageNotifier.new);

// ---------------------------------------------------------------------------
// 通知栏（旧版通知设置四键）
// ---------------------------------------------------------------------------

class NotificationSettingsNotifier extends Notifier<NotificationSettingsState> {
  @override
  NotificationSettingsState build() {
    final settings = _settings(ref);
    final texts = settings.notificationTexts;
    return NotificationSettingsState(
      persistent: settings.notificationPersistent,
      showSpeed: settings.notificationSpeed,
      runningText: texts.running,
      stoppedText: texts.stopped,
    );
  }

  void setPersistent(bool value) {
    state = state.copyWith(persistent: value);
    _settings(ref).setNotificationPersistent(value);
    _bump(ref);
  }

  void setShowSpeed(bool value) {
    state = state.copyWith(showSpeed: value);
    _settings(ref).setNotificationSpeed(value);
    _bump(ref);
  }

  void setRunningText(String value) {
    state = state.copyWith(runningText: value);
    _settings(ref)
        .setNotificationTexts(running: value, stopped: state.stoppedText);
    _bump(ref);
  }

  void setStoppedText(String value) {
    state = state.copyWith(stoppedText: value);
    _settings(ref)
        .setNotificationTexts(running: state.runningText, stopped: value);
    _bump(ref);
  }
}

/// 通知栏四项取值。两条文案的空串表示「用默认文案」。
class NotificationSettingsState {
  const NotificationSettingsState({
    required this.persistent,
    required this.showSpeed,
    required this.runningText,
    required this.stoppedText,
  });

  final bool persistent;
  final bool showSpeed;
  final String runningText;
  final String stoppedText;

  NotificationSettingsState copyWith({
    bool? persistent,
    bool? showSpeed,
    String? runningText,
    String? stoppedText,
  }) => NotificationSettingsState(
    persistent: persistent ?? this.persistent,
    showSpeed: showSpeed ?? this.showSpeed,
    runningText: runningText ?? this.runningText,
    stoppedText: stoppedText ?? this.stoppedText,
  );
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
      NotificationSettingsNotifier.new,
    );

// ---------------------------------------------------------------------------
// 软件背景（旧版 custom_background_*）
// ---------------------------------------------------------------------------

class CustomBackgroundNotifier extends Notifier<CustomBackgroundState> {
  @override
  CustomBackgroundState build() {
    final settings = _settings(ref);
    return CustomBackgroundState(
      enabled: settings.customBackgroundEnabled,
      currentUri: settings.customBackgroundUri,
      uris: settings.customBackgroundUris,
    );
  }

  void setEnabled(bool value) {
    state = state.copyWith(enabled: value);
    _settings(ref).setCustomBackgroundEnabled(value);
    _bump(ref);
  }

  /// 添加一张壁纸：同时更新「当前生效」与历史清单。
  ///
  /// 旧版的顺序是「先 append 到 `_uris`，再写 `_uri`」；这里保持一致，避免
  /// 出现「清单里有但当前指向另一张」的中间态。
  void add(String uri) {
    if (uri.trim().isEmpty) return;
    final uris = [...state.uris, uri];
    state = state.copyWith(uris: uris, currentUri: uri, enabled: true);
    final settings = _settings(ref);
    settings.setCustomBackgroundUris(uris);
    settings.setCustomBackgroundUri(uri);
    settings.setCustomBackgroundEnabled(true);
    _bump(ref);
  }

  /// 选中已有的一张作为当前壁纸。
  void select(String uri) {
    if (!state.uris.contains(uri)) return;
    state = state.copyWith(currentUri: uri);
    _settings(ref).setCustomBackgroundUri(uri);
    _bump(ref);
  }

  /// 移除一张。移除当前那张时，把 `_uri` 退回到剩下清单里的最后一张。
  void remove(String uri) {
    final uris = [
      for (final item in state.uris)
        if (item != uri) item,
    ];
    final nextCurrent = state.currentUri == uri
        ? (uris.isEmpty ? null : uris.last)
        : state.currentUri;
    state = state.copyWith(uris: uris, currentUri: nextCurrent);
    final settings = _settings(ref);
    settings.setCustomBackgroundUris(uris);
    if (nextCurrent == null) {
      _storeRemoveCurrent(settings);
    } else {
      settings.setCustomBackgroundUri(nextCurrent);
    }
    _bump(ref);
  }

  void _storeRemoveCurrent(LegacySettings settings) {
    // 没有「删除键」的 API：写空串在旧版语义里等价于「未设置」
    // （`getCustomBackgroundUri()` 对空串返回 null）。
    settings.setCustomBackgroundUri('');
  }
}

/// 软件背景三项。
class CustomBackgroundState {
  const CustomBackgroundState({
    required this.enabled,
    required this.currentUri,
    required this.uris,
  });

  final bool enabled;
  final String? currentUri;
  final List<String> uris;

  CustomBackgroundState copyWith({
    bool? enabled,
    String? currentUri,
    List<String>? uris,
  }) => CustomBackgroundState(
    enabled: enabled ?? this.enabled,
    currentUri: currentUri ?? this.currentUri,
    uris: uris ?? this.uris,
  );
}

final customBackgroundProvider =
    NotifierProvider<CustomBackgroundNotifier, CustomBackgroundState>(
      CustomBackgroundNotifier.new,
    );

// ---------------------------------------------------------------------------
// 启动更新检查 / 首启须知
// ---------------------------------------------------------------------------

class StartupUpdateCheckNotifier extends Notifier<bool> {
  @override
  bool build() => _settings(ref).disableStartupUpdateCheck;

  /// 参数是「关闭启动检查」的开关值，与键名同向，避免取反写错。
  void toggle(bool value) {
    state = value;
    _settings(ref).setDisableStartupUpdateCheck(value);
    _bump(ref);
  }
}

final startupUpdateCheckProvider =
    NotifierProvider<StartupUpdateCheckNotifier, bool>(
      StartupUpdateCheckNotifier.new,
    );

class InitialAgreementNotifier extends Notifier<bool> {
  @override
  bool build() => _settings(ref).initialAgreementAccepted;

  void accept() {
    state = true;
    _settings(ref).setInitialAgreementAccepted(true);
    _bump(ref);
  }
}

final initialAgreementProvider =
    NotifierProvider<InitialAgreementNotifier, bool>(
      InitialAgreementNotifier.new,
    );

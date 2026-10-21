/// 订阅自动更新的设置层：总开关 / 间隔小时 / 分组开关。
///
/// ## 落盘位置
/// 总开关与间隔在**数据集容器**里（`dns_vpn_prefs` / `diting_express_prefs` /
/// `diting_dns_mode_prefs`），键名与默认值逐字照抄 1.4.3 的
/// `SubscriptionAutoUpdateSettings`：`subscription_auto_update_enabled`（默认
/// 关闭）、`subscription_auto_update_interval_hours`（默认 24，合法 1–168）。
///
/// 分组开关不在 prefs 里，而是 `subscription_group.autoUpdateEnabled` 这一列
/// （旧版 `SubscriptionGroupDao.setAutoUpdateEnabled`）。
///
/// ## 这里不做什么
/// 旧版写完设置会调 `SubscriptionAutoUpdateScheduler.sync()` 去重排
/// WorkManager。本仓没有 WorkManager 侧的后台任务（原生侧未移植该调度器），
/// 所以这里只落盘 + 提示，**不**假装已经排期——页面文案要如实说明「设置已保存，
/// 后台调度在原生侧接入后生效」。
library;

import 'package:diting/data/db/subscription_models.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/subscription_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 自动更新的两项设置。
class AutoUpdateSettings {
  const AutoUpdateSettings({required this.enabled, required this.intervalHours});

  final bool enabled;
  final int intervalHours;

  /// 间隔是不是预设档位（决定「自定义更新时间」那行是否高亮）。
  bool get isCustom =>
      !LegacySettings.subscriptionAutoUpdatePresetHours.contains(intervalHours);
}

/// 当前数据集的自动更新设置。
final autoUpdateSettingsProvider = Provider<AutoUpdateSettings>((ref) {
  final settings = ref.watch(legacySettingsProvider);
  return AutoUpdateSettings(
    enabled: settings.subscriptionAutoUpdateEnabled,
    intervalHours: settings.subscriptionAutoUpdateIntervalHours,
  );
});

/// 设置写入口。写完 bump revision，`autoUpdateSettingsProvider` 随之重建。
class AutoUpdateActions {
  AutoUpdateActions(this._ref);

  final Ref _ref;

  void setEnabled(bool enabled) {
    final settings = _ref.read(legacySettingsProvider);
    settings.setSubscriptionAutoUpdateEnabled(enabled);
    // 旧版「关闭总开关时保留已选间隔」，因此这里只写开关，不动间隔。
    _ref.read(legacySettingsRevisionProvider.notifier).bump();
  }

  /// 间隔超出 1–168 时不写，返回 false 让调用方保留输入框并提示。
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

  /// 分组开关写 `subscription_group.autoUpdateEnabled` 列。
  Future<void> setGroupEnabled(int groupId, bool enabled) async {
    final repository = await _ref.read(subscriptionRepositoryProvider.future);
    await repository?.setGroupAutoUpdateEnabled(groupId, enabled);
  }
}

final autoUpdateActionsProvider = Provider<AutoUpdateActions>(
  AutoUpdateActions.new,
);

/// 分组列表 + 各自的自动更新开关（直接来自 `subscription_group` 行）。
final autoUpdateGroupsProvider =
    FutureProvider<List<SubscriptionGroupRecord>>((ref) =>
        ref.watch(subscriptionGroupsProvider.future),
    );

/// 功能中心演示状态：隐藏卡片集合与日志长按提示。
///
/// 隐藏集合原本只在内存里，离开页面就丢；现在落盘到 1.4.3 的
/// `dns_vpn_prefs` / `hidden_features_set`（StringSet），键名逐字照抄
/// `ui/settings/HiddenFeaturesStore.kt`：
///
/// | 卡片 | 键 |
/// | --- | --- |
/// | 服务商管理 | `provider_management` |
/// | 引导解析设置 | `bootstrap_settings` |
/// | 解析模式 | `resolution_mode` |
/// | 缓存设置 | `cache_settings` |
/// | 规则控制 | `rule_control` |
/// | 黑名单 | `blacklist` |
/// | 白名单 | `whitelist` |
/// | 覆写名单 | `rewrite_list` |
/// | 应用流量统计 | `traffic_stats` |
/// | 应用独立规则 | `app_rules` |
/// | 禁止联网应用 | `blocked_apps` |
/// | 排除应用 | `excluded_apps` |
/// | HTTPS 流量检查 | `https_inspection` |
/// | 出站代理 | `outbound_proxy` |
/// | 网络诊断 | `network_tools` |
/// | AI 分析 | `agent_api` |
/// | 外观调整 | `appearance` |
/// | 服务显示 | `service_display` |
/// | 其他设置 | `other_settings` |
/// | 日志 | `logs` |
/// | 备份与迁移 | `data_management` |
/// | 数据清理 | `data_cleanup` |
/// | 更新与支持 | `app_update` |
/// | 应用信息 | `app_info` |
/// | 赞助 | `sponsor` |
/// | 赞助者名单 | `sponsor_list` |
/// | 共建者名单 | `contributors` |
///
/// 「隐藏功能」卡（`/hub/hidden-features`）是固定常驻卡，**没有**键，也不可隐藏。
///
/// 这 27 个键与 `lib/data/mock_feature_hub.dart` 的 `featureKey` 必须逐个一致，
/// `test/feature_hub_migration_test.dart` 已锁定清单长度与唯一性；本文件另加一条
/// 断言（见 [hiddenFeatureKeysInFile]）把两份清单钉在一起。
library;

import 'package:diting/data/mock_data.dart';
import 'package:diting/data/prefs/legacy_settings_provider.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `HiddenFeaturesStore.PREFS_NAME`（全局 UI 键容器）。
const hiddenFeaturesContainer = LegacySettings.uiContainer;

/// `HiddenFeaturesStore.KEY_HIDDEN_FEATURES`。
const hiddenFeaturesKey = 'hidden_features_set';

/// 源码内的键清单，用于与 `mock_feature_hub.dart` 对齐校验。
///
/// 顺序与 `HiddenFeature` 枚举声明顺序一致（DNS 服务 → 关于软件）。
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
  'app_update',
  'app_info',
  'sponsor',
  'sponsor_list',
  'contributors',
];

/// 当前被隐藏的功能键（落盘）。
///
/// 写入即落 `dns_vpn_prefs`，读时依赖 [legacySettingsRevisionProvider]：
/// SharedPreferences 写入不可观察，没有显式版本号的话，隐藏功能页改完开关、
/// 功能中心已经 build 过就仍显示旧卡片。
class HiddenFeatureKeysNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(legacySettingsRevisionProvider);
    final store = ref.watch(legacyPrefsStoreProvider);
    final value = store.read(hiddenFeaturesContainer, hiddenFeaturesKey);
    // 桥接层把 Set 转成 List 传过来；旧版也有存成 JSON 字符串的历史安装。
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

/// 当前被隐藏的功能键。
final hiddenFeatureKeysProvider =
    NotifierProvider<HiddenFeatureKeysNotifier, Set<String>>(
      HiddenFeatureKeysNotifier.new,
    );

/// 当前模式下可见的功能中心分类（已按隐藏集合过滤，空分类整类消失）。
///
/// 卡片清单仍是 `mock_feature_hub.dart` 的文案常量（不是业务数据，
/// `test/route_catalog_test.dart` 守着 route），这里只做过滤。
///
/// 功能中心页与隐藏功能页都从这里取，避免两处各写一份过滤逻辑而漂移。
final visibleFeatureCategoriesProvider = Provider<List<MockFeatureCategory>>((
  ref,
) {
  final express = ref.watch(workModeProvider) == AppWorkMode.express;
  final hidden = ref.watch(hiddenFeatureKeysProvider);
  return visibleFeatureCategories(express: express, hiddenKeys: hidden);
});

/// 「日志卡可长按」提示是否已经看过。
///
/// 上游用 `SettingsGuides.HOME_LOG_LONG_PRESS_ID` 记录，长按一次后永久消失；
/// 这里同样只在本次会话内记住——那是一次性引导，1.4.3 也没有对应的落盘键，
/// 不要为它自创一个。
class LogLongPressHintNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void acknowledge() => state = false;
}

final logLongPressHintProvider =
    NotifierProvider<LogLongPressHintNotifier, bool>(
      LogLongPressHintNotifier.new,
    );

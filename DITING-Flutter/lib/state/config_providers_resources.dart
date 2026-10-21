/// 配置域的「保留资源」状态：图标集 / User-Agent / 按需连接。
///
/// 上一轮这里是 `part of config_providers.dart`，与通用 / 网络 / 覆写 / 策略表 /
/// 嗅探五族配置共库。那五族属于 FlClash 的内核配置，1.4.3 没有对应界面，已随
/// 内核配置页一并删除；本库因此独立出来，只保留用户要求保留的三张表。
///
/// 一个 notifier 管三组数据而不是三个 notifier：三者操作都是「整表替换」，没有
/// 交叉逻辑，拆开只会多出三份几乎相同的 boilerplate。
library;

import 'package:diting/data/mock_config_resources.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 资源配置域的整表快照。
class ConfigResources {
  const ConfigResources({
    required this.iconSets,
    required this.userAgents,
    required this.selectedUserAgent,
    required this.ssidRules,
    required this.onDemand,
  });

  final List<MockIconSet> iconSets;
  final List<MockUserAgent> userAgents;

  /// 当前选中的 UA；null 表示「不覆写」（沿用订阅或内核默认）。
  ///
  /// 上一轮这一位放在 `generalConfigProvider` 里，而那一族随内核配置删除。
  /// 一行保留项不值得拖回整套通用配置，因此并入本快照。
  final String? selectedUserAgent;
  final List<MockSsidRule> ssidRules;
  final bool onDemand;

  ConfigResources copyWith({
    List<MockIconSet>? iconSets,
    List<MockUserAgent>? userAgents,
    String? selectedUserAgent,
    bool clearSelectedUserAgent = false,
    List<MockSsidRule>? ssidRules,
    bool? onDemand,
  }) => ConfigResources(
    iconSets: iconSets ?? this.iconSets,
    userAgents: userAgents ?? this.userAgents,
    selectedUserAgent: clearSelectedUserAgent
        ? null
        : (selectedUserAgent ?? this.selectedUserAgent),
    ssidRules: ssidRules ?? this.ssidRules,
    onDemand: onDemand ?? this.onDemand,
  );
}

class ConfigResourcesNotifier extends Notifier<ConfigResources> {
  @override
  ConfigResources build() => const ConfigResources(
    iconSets: mockIconSets,
    userAgents: mockUserAgents,
    selectedUserAgent: null,
    ssidRules: mockSsidRules,
    onDemand: false,
  );

  // —— 图标集 ——

  /// [originalName] 为空表示新增。图标集按名字被引用，因此重名要就地覆盖而不是
  /// 追加一份（列表页按名字删改，重名会让「删哪一份」变成不确定）。
  void putIconSet(String? originalName, MockIconSet iconSet) {
    state = state.copyWith(
      iconSets: originalName == null
          ? [...state.iconSets, iconSet]
          : [
              for (final item in state.iconSets)
                item.name == originalName ? iconSet : item,
            ],
    );
  }

  void removeIconSet(String name) => state = state.copyWith(
    iconSets: [
      for (final item in state.iconSets)
        if (item.name != name) item,
    ],
  );

  // —— User-Agent ——

  /// 返回 false 表示空值或重复，调用方给一句提示。
  bool addUserAgent(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        state.userAgents.any((item) => item.value == trimmed)) {
      return false;
    }
    state = state.copyWith(
      userAgents: [
        ...state.userAgents,
        MockUserAgent(value: trimmed),
      ],
    );
    return true;
  }

  bool updateUserAgent(String original, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        state.userAgents.any(
          (item) => item.value == trimmed && item.value != original,
        )) {
      return false;
    }
    state = state.copyWith(
      userAgents: [
        for (final item in state.userAgents)
          item.value == original
              ? MockUserAgent(value: trimmed, isDefault: item.isDefault)
              : item,
      ],
      // 改的正好是当前选中的那条时同步切换，否则选中项会指向一个不存在的值。
      selectedUserAgent: state.selectedUserAgent == original ? trimmed : null,
    );
    return true;
  }

  /// 内置 UA 不可删：删掉之后内核回落到默认值，用户会以为「设置没生效」。
  void removeUserAgent(String value) {
    if (state.userAgents.any((item) => item.value == value && item.isDefault)) {
      return;
    }
    state = state.copyWith(
      userAgents: [
        for (final item in state.userAgents)
          if (item.value != value) item,
      ],
      clearSelectedUserAgent: state.selectedUserAgent == value,
    );
  }

  /// null 表示「不覆写」。
  void selectUserAgent(String? value) => state = state.copyWith(
    selectedUserAgent: value,
    clearSelectedUserAgent: value == null,
  );

  // —— 按需连接 ——

  void setOnDemand(bool value) => state = state.copyWith(onDemand: value);

  bool putSsid(String? original, MockSsidRule rule) {
    final trimmed = rule.ssid.trim();
    if (trimmed.isEmpty ||
        state.ssidRules.any(
          (item) => item.ssid == trimmed && item.ssid != original,
        )) {
      return false;
    }
    final normalized = MockSsidRule(
      ssid: trimmed,
      cellular: rule.cellular,
      wifi: rule.wifi,
      delayMs: rule.delayMs,
    );
    state = state.copyWith(
      ssidRules: original == null
          ? [...state.ssidRules, normalized]
          : [
              for (final item in state.ssidRules)
                item.ssid == original ? normalized : item,
            ],
    );
    return true;
  }

  void removeSsid(String ssid) => state = state.copyWith(
    ssidRules: [
      for (final item in state.ssidRules)
        if (item.ssid != ssid) item,
    ],
  );

  void toggleSsid(String ssid, {bool? cellular, bool? wifi}) {
    state = state.copyWith(
      ssidRules: [
        for (final item in state.ssidRules)
          item.ssid == ssid
              ? item.copyWith(cellular: cellular, wifi: wifi)
              : item,
      ],
    );
  }
}

final configResourcesProvider =
    NotifierProvider<ConfigResourcesNotifier, ConfigResources>(
      ConfigResourcesNotifier.new,
    );

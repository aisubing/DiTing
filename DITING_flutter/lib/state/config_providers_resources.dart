part of 'config_providers.dart';

/// 资源类数据（过滤器 / 追加规则 / 脚本 / 提供者 / 图标集 / UA / 按需）。
///
/// 七类数据放在一个 notifier 里：它们的操作都是「整表替换」，且没有交叉逻辑，
/// 拆开只会多出七份几乎相同的 boilerplate。
///
/// 单独放进 part 文件是为了守住单文件 550 行的上限：通用 / 网络 / 覆写 / 策略表 /
/// 嗅探与这里的资源表互不引用，只是放在同一个库里共享 import。
class ConfigResourcesNotifier extends Notifier<ConfigResources> {
  var _sequence = 0;

  @override
  ConfigResources build() => const ConfigResources(
    filters: mockFilters,
    rules: mockAddedRules,
    scripts: mockScripts,
    providers: mockClashProviders,
    iconSets: mockIconSets,
    userAgents: mockUserAgents,
    ssidRules: mockSsidRules,
    onDemand: false,
  );

  // —— 过滤器 ——

  bool addFilter(MockFilter filter) {
    if (state.filters.any((item) => item.label == filter.label)) {
      return false;
    }
    state = state.copyWith(filters: [...state.filters, filter]);
    return true;
  }

  bool updateFilter(String label, MockFilter next) {
    if (label != next.label &&
        state.filters.any((item) => item.label == next.label)) {
      return false;
    }
    state = state.copyWith(
      filters: [
        for (final item in state.filters) item.label == label ? next : item,
      ],
    );
    return true;
  }

  void removeFilters(Set<String> labels) => state = state.copyWith(
    filters: [
      for (final item in state.filters)
        if (!labels.contains(item.label)) item,
    ],
  );

  // —— 追加规则 ——

  void putRule(MockAddedRule rule) {
    final exists = state.rules.any((item) => item.id == rule.id);
    state = state.copyWith(
      rules: exists
          ? [for (final item in state.rules) item.id == rule.id ? rule : item]
          : [...state.rules, rule],
    );
  }

  MockAddedRule newRule() => MockAddedRule(
    id: 'ar-user-${_sequence++}',
    kind: AddedRuleKind.domainSuffix,
    payload: '',
    policy: mockRulePolicies.first,
  );

  void removeRules(Set<String> ids) => state = state.copyWith(
    rules: [
      for (final item in state.rules)
        if (!ids.contains(item.id)) item,
    ],
  );

  /// 上移/下移：规则有先后顺序，顺序决定命中优先级。
  void moveRule(String id, int delta) {
    final index = state.rules.indexWhere((item) => item.id == id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= state.rules.length) {
      return;
    }
    final next = [...state.rules];
    final rule = next.removeAt(index);
    next.insert(target, rule);
    state = state.copyWith(rules: next);
  }

  // —— 脚本 ——

  bool putScript(String? originalName, MockScript script) {
    final clash = state.scripts.any(
      (item) => item.name == script.name && item.name != originalName,
    );
    if (clash) {
      return false;
    }
    state = state.copyWith(
      scripts: originalName == null
          ? [...state.scripts, script]
          : [
              for (final item in state.scripts)
                item.name == originalName ? script : item,
            ],
    );
    return true;
  }

  void removeScript(String name) => state = state.copyWith(
    scripts: [
      for (final item in state.scripts)
        if (item.name != name) item,
    ],
  );

  // —— Clash 提供者 ——

  bool putProvider(String? originalName, MockClashProvider provider) {
    final clash = state.providers.any(
      (item) => item.name == provider.name && item.name != originalName,
    );
    if (clash) {
      return false;
    }
    state = state.copyWith(
      providers: originalName == null
          ? [...state.providers, provider]
          : [
              for (final item in state.providers)
                item.name == originalName ? provider : item,
            ],
    );
    return true;
  }

  void removeProvider(String name) => state = state.copyWith(
    providers: [
      for (final item in state.providers)
        if (item.name != name) item,
    ],
  );

  // —— 图标集 ——

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
    );
    return true;
  }

  /// 内置 UA 不可删：删掉之后内核回落到默认值，用户会以为「设置没生效」。
  void removeUserAgent(String value) => state = state.copyWith(
    userAgents: [
      for (final item in state.userAgents)
        if (item.value != value || item.isDefault) item,
    ],
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

/// 资源配置域的整表快照。
class ConfigResources {
  const ConfigResources({
    required this.filters,
    required this.rules,
    required this.scripts,
    required this.providers,
    required this.iconSets,
    required this.userAgents,
    required this.ssidRules,
    required this.onDemand,
  });

  final List<MockFilter> filters;
  final List<MockAddedRule> rules;
  final List<MockScript> scripts;
  final List<MockClashProvider> providers;
  final List<MockIconSet> iconSets;
  final List<MockUserAgent> userAgents;
  final List<MockSsidRule> ssidRules;
  final bool onDemand;

  ConfigResources copyWith({
    List<MockFilter>? filters,
    List<MockAddedRule>? rules,
    List<MockScript>? scripts,
    List<MockClashProvider>? providers,
    List<MockIconSet>? iconSets,
    List<MockUserAgent>? userAgents,
    List<MockSsidRule>? ssidRules,
    bool? onDemand,
  }) => ConfigResources(
    filters: filters ?? this.filters,
    rules: rules ?? this.rules,
    scripts: scripts ?? this.scripts,
    providers: providers ?? this.providers,
    iconSets: iconSets ?? this.iconSets,
    userAgents: userAgents ?? this.userAgents,
    ssidRules: ssidRules ?? this.ssidRules,
    onDemand: onDemand ?? this.onDemand,
  );
}

final configResourcesProvider =
    NotifierProvider<ConfigResourcesNotifier, ConfigResources>(
      ConfigResourcesNotifier.new,
    );

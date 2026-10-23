part of 'profiles_providers.dart';

class ProxyGroupsNotifier extends Notifier<List<MockProxyGroup>> {
  var _sequence = 0;

  @override
  List<MockProxyGroup> build() => [...mockProxyGroups];

  bool put(MockProxyGroup group) {
    if (state.any((item) => item.id != group.id && item.name == group.name)) {
      return false;
    }
    final index = state.indexWhere((item) => item.id == group.id);
    state = index < 0
        ? [...state, group]
        : [
            for (var i = 0; i < state.length; i++)
              if (i == index) group else state[i],
          ];
    return true;
  }

  MockProxyGroup create({required String name, required GroupKind kind}) {
    return MockProxyGroup(
      id: 'g-new-${_sequence++}',
      name: name,
      kind: kind,
      members: const [],
    );
  }

  void remove(Set<String> ids) {
    state = [
      for (final group in state)
        if (!ids.contains(group.id)) group,
    ];
  }

  void duplicate(Set<String> ids) {
    final copies = [
      for (final group in state)
        if (ids.contains(group.id))
          MockProxyGroup(
            id: 'g-new-${_sequence++}',
            name: '${group.name} 副本',
            kind: group.kind,
            members: [...group.members],
            filter: group.filter,
            useProviders: [...group.useProviders],
            icon: group.icon,
            probeUrl: group.probeUrl,
            intervalSeconds: group.intervalSeconds,
            strategy: group.strategy,
            hidden: group.hidden,
            lazy: group.lazy,
          ),
    ];
    state = [...state, ...copies];
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex || oldIndex < 0 || oldIndex >= state.length) {
      return;
    }
    final next = [...state];
    next.insert(newIndex.clamp(0, next.length), next.removeAt(oldIndex));
    state = next;
  }

  /// Saved from the member picker: replaces the whole ordered member set.
  void setMembers(String groupId, List<String> members) {
    state = [
      for (final group in state)
        if (group.id == groupId) group.copyWith(members: members) else group,
    ];
  }

  void setIcon(String groupId, String icon) {
    state = [
      for (final group in state)
        if (group.id == groupId) group.copyWith(icon: icon) else group,
    ];
  }

  /// Re-sorts by type, replacing the whole list.
  void replaceAll(List<MockProxyGroup> groups) => state = [...groups];
}

final proxyGroupsProvider =
    NotifierProvider<ProxyGroupsNotifier, List<MockProxyGroup>>(
      ProxyGroupsNotifier.new,
    );

class CustomRulesNotifier extends Notifier<List<MockCustomRule>> {
  var _sequence = 0;

  @override
  List<MockCustomRule> build() => [...mockCustomRules];

  bool put(MockCustomRule rule) {
    final index = state.indexWhere((item) => item.id == rule.id);
    state = index < 0
        ? [...state, rule]
        : [
            for (var i = 0; i < state.length; i++)
              if (i == index) rule else state[i],
          ];
    return true;
  }

  MockCustomRule create({
    required CustomRuleType type,
    required String content,
    required String target,
    required bool noResolve,
    required bool src,
  }) {
    return MockCustomRule(
      id: 'r-new-${_sequence++}',
      type: type,
      content: content.trim(),
      target: target,
      noResolve: noResolve,
      src: src,
    );
  }

  void remove(Set<String> ids) {
    state = [
      for (final rule in state)
        if (!ids.contains(rule.id)) rule,
    ];
  }

  void duplicate(Set<String> ids) {
    state = [
      ...state,
      for (final rule in state)
        if (ids.contains(rule.id))
          MockCustomRule(
            id: 'r-new-${_sequence++}',
            type: rule.type,
            content: rule.content,
            target: rule.target,
            noResolve: rule.noResolve,
            src: rule.src,
            disabled: rule.disabled,
          ),
    ];
  }

  void toggle(String id, bool enabled) {
    state = [
      for (final rule in state)
        if (rule.id == id) rule.copyWith(disabled: !enabled) else rule,
    ];
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex || oldIndex < 0 || oldIndex >= state.length) {
      return;
    }
    final next = [...state];
    next.insert(newIndex.clamp(0, next.length), next.removeAt(oldIndex));
    state = next;
  }

  /// Saved from the quick editor: replaces the whole list.
  void replaceAll(List<MockCustomRule> rules) => state = [...rules];
}

final customRulesProvider =
    NotifierProvider<CustomRulesNotifier, List<MockCustomRule>>(
      CustomRulesNotifier.new,
    );

class ProxyProvidersNotifier extends Notifier<List<MockProxyProvider>> {
  @override
  List<MockProxyProvider> build() => [...mockProxyProviders];

  /// Adds an entry; only the name is asked for, other fields get placeholders.
  void addProvider(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    state = [
      ...state,
      MockProxyProvider(
        id: 'pp-new-${state.length}',
        name: trimmed,
        url: 'https://sub.example.com/providers/proxies',
        updatedAt: '待更新',
        proxyCount: 0,
      ),
    ];
  }

  void toggleEnabled(String id, bool enabled) {
    state = [
      for (final provider in state)
        if (provider.id == id)
          MockProxyProvider(
            id: provider.id,
            name: provider.name,
            url: provider.url,
            updatedAt: provider.updatedAt,
            proxyCount: provider.proxyCount,
            intervalMinutes: provider.intervalMinutes,
            healthCheck: provider.healthCheck,
            enabled: enabled,
          )
        else
          provider,
    ];
  }

  void setHealthCheck(String id, bool enabled) {
    state = [
      for (final provider in state)
        if (provider.id == id)
          MockProxyProvider(
            id: provider.id,
            name: provider.name,
            url: provider.url,
            updatedAt: provider.updatedAt,
            proxyCount: provider.proxyCount,
            intervalMinutes: provider.intervalMinutes,
            healthCheck: enabled,
            enabled: provider.enabled,
          )
        else
          provider,
    ];
  }
}

final proxyProvidersProvider =
    NotifierProvider<ProxyProvidersNotifier, List<MockProxyProvider>>(
      ProxyProvidersNotifier.new,
    );

class RuleProvidersNotifier extends Notifier<List<MockRuleProvider>> {
  @override
  List<MockRuleProvider> build() => [...mockRuleProviders];

  void addProvider({
    required String name,
    required String url,
    required String behavior,
  }) {
    state = [
      ...state,
      MockRuleProvider(
        id: 'rp-new-${state.length}',
        name: name.trim(),
        url: url.trim(),
        behavior: behavior,
        ruleCount: 0,
        updatedAt: '待更新',
      ),
    ];
  }

  /// Adds an entry; only the name is asked for, other fields get placeholders.
  void addNamed(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    addProvider(
      name: trimmed,
      url: 'https://rules.example.com/new.yaml',
      behavior: 'domain',
    );
  }

  void remove(String id) {
    state = [
      for (final provider in state)
        if (provider.id != id) provider,
    ];
  }
}

final ruleProvidersProvider =
    NotifierProvider<RuleProvidersNotifier, List<MockRuleProvider>>(
      RuleProvidersNotifier.new,
    );

/// Dialer: node name to relay target.
class DialersNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {
    for (final dialer in mockDialers) dialer.proxyName: dialer.target,
  };

  void set(String proxyName, String? target) {
    state = {...state};
    if (target == null || target.isEmpty) {
      state.remove(proxyName);
    } else {
      state[proxyName] = target;
    }
  }
}

final dialersProvider = NotifierProvider<DialersNotifier, Map<String, String>>(
  DialersNotifier.new,
);

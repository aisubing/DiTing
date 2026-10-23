part of 'profiles_providers.dart';

/// Extension mode, keyed by profile id so each profile keeps its own mode.
class ExtendModesNotifier extends Notifier<Map<String, ExtendMode>> {
  @override
  Map<String, ExtendMode> build() => const {};

  ExtendMode modeOf(String profileId) =>
      state[profileId] ?? ExtendMode.standard;

  void select(String profileId, ExtendMode mode) {
    state = {...state, profileId: mode};
  }
}

final extendModesProvider =
    NotifierProvider<ExtendModesNotifier, Map<String, ExtendMode>>(
      ExtendModesNotifier.new,
    );

/// Script selected for each profile.
class ScriptSelectionNotifier extends Notifier<Map<String, String?>> {
  @override
  Map<String, String?> build() => const {};

  String? scriptOf(String profileId) => state[profileId];

  /// Tapping again deselects, as upstream `scriptId == scriptId ? null : scriptId`.
  void select(String profileId, String scriptId) {
    state = {
      ...state,
      profileId: state[profileId] == scriptId ? null : scriptId,
    };
  }
}

final scriptSelectionProvider =
    NotifierProvider<ScriptSelectionNotifier, Map<String, String?>>(
      ScriptSelectionNotifier.new,
    );

/// Match target per profile; null follows the profile default.
class MatchTargetsNotifier extends Notifier<Map<String, String?>> {
  @override
  Map<String, String?> build() => const {};

  String? targetOf(String profileId) => state[profileId];

  void select(String profileId, String? target) {
    state = {...state, profileId: target};
  }
}

final matchTargetsProvider =
    NotifierProvider<MatchTargetsNotifier, Map<String, String?>>(
      MatchTargetsNotifier.new,
    );

class AddedRulesNotifier extends Notifier<List<MockCustomRule>> {
  var _sequence = 0;

  @override
  List<MockCustomRule> build() => [
    for (final rule in mockCustomRules)
      if (rule.target != '🛑 广告拦截') rule,
  ];

  MockCustomRule create({
    required CustomRuleType type,
    required String content,
    required String target,
  }) {
    return MockCustomRule(
      id: 'ar-new-${_sequence++}',
      type: type,
      content: content.trim(),
      target: target,
    );
  }

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

  void removeAll(Set<String> ids) {
    state = [
      for (final rule in state)
        if (!ids.contains(rule.id)) rule,
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
}

final addedRulesProvider =
    NotifierProvider<AddedRulesNotifier, List<MockCustomRule>>(
      AddedRulesNotifier.new,
    );


class GlobalRulesNotifier extends Notifier<List<MockGlobalRule>> {
  @override
  List<MockGlobalRule> build() => [...mockGlobalRules];

  void toggle(String id, bool enabled) {
    state = [
      for (final rule in state)
        if (rule.id == id)
          MockGlobalRule(
            id: rule.id,
            type: rule.type,
            content: rule.content,
            target: rule.target,
            enabled: enabled,
          )
        else
          rule,
    ];
  }
}

final globalRulesProvider =
    NotifierProvider<GlobalRulesNotifier, List<MockGlobalRule>>(
      GlobalRulesNotifier.new,
    );

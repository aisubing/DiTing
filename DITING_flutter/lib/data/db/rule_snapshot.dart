/// Translates the Room rule tables into `Engine.applyRuleSnapshot` input.
///
/// 1.4.3 keeps "important" block rules in a separate list so they survive
/// allowlist overrides; everything else goes into the plain global arrays. The
/// Go policy engine lowercases and validates each pattern itself.
library;

import 'dart:convert';

import 'package:diting/data/mock_data.dart';

Map<String, Object?> buildRuleSnapshot(Map<RuleKind, List<MockRule>> rules) {
  final normalBlock = <String>{};
  final importantBlock = <String>{};
  final allow = <String>{};

  for (final rule in rules[RuleKind.block] ?? const <MockRule>[]) {
    if (!rule.enabled || rule.pattern.isEmpty) continue;
    if (rule.important) {
      importantBlock.add(rule.pattern);
    } else {
      normalBlock.add(rule.pattern);
    }
  }
  for (final rule in rules[RuleKind.allow] ?? const <MockRule>[]) {
    if (rule.enabled && rule.pattern.isNotEmpty) {
      allow.add(rule.pattern);
    }
  }

  return {
    'filterEnabled': true,
    'globalAllow': allow.toList(),
    'globalBlock': normalBlock.toList(),
    'globalImportant': importantBlock.toList(),
    'appRules': <String, Object?>{},
    'invertedBlock': <Object?>[],
    'invertedAllow': <Object?>[],
    'specialBlock': <Object?>[],
    'specialAllow': <Object?>[],
    'disabledRules': <String>[],
  };
}

String encodeRuleSnapshot(Map<RuleKind, List<MockRule>> rules) =>
    jsonEncode(buildRuleSnapshot(rules));

/// `Engine.setRewriteRules` takes a flat domain -> target map. CNAME targets
/// and IP literals share the same shape, so no type detection is needed.
String encodeRewriteRules(Map<RuleKind, List<MockRule>> rules) {
  final targets = <String, String>{};
  for (final rule in rules[RuleKind.rewrite] ?? const <MockRule>[]) {
    final target = rule.target?.trim();
    if (!rule.enabled || rule.pattern.isEmpty) continue;
    if (target == null || target.isEmpty) continue;
    targets[rule.pattern] = target;
  }
  return targets.isEmpty ? '' : jsonEncode(targets);
}

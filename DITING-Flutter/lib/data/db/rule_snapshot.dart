/// Translates the Room rule tables into `Engine.applyRuleSnapshot`: "important" rules travel in a
/// separate list, and app-scoped rules stay under `appRules[<pkg>]` because emitting them globally
/// widens a single-app block to every app.
library;

import 'dart:convert';

import 'package:diting/data/mock_data.dart';

Map<String, Object?> buildRuleSnapshot(
  Map<RuleKind, List<MockRule>> rules, {
  Map<String, Set<String>> appAllowlist = const {},
}) {
  final normalBlock = <String>{};
  final importantBlock = <String>{};
  final allow = <String>{};
  final scopedBlock = <String, Set<String>>{};
  final scopedImportant = <String, Set<String>>{};

  for (final rule in rules[RuleKind.block] ?? const <MockRule>[]) {
    if (!rule.enabled || rule.pattern.isEmpty) continue;
    final scopes = _scopesOf(rule);
    if (scopes.isEmpty) {
      if (rule.important) {
        importantBlock.add(rule.pattern);
      } else {
        normalBlock.add(rule.pattern);
      }
    } else {
      for (final pkg in scopes) {
        (rule.important ? scopedImportant : scopedBlock)
            .putIfAbsent(pkg, () => <String>{})
            .add(rule.pattern);
      }
    }
  }
  for (final rule in rules[RuleKind.allow] ?? const <MockRule>[]) {
    if (!rule.enabled || rule.pattern.isEmpty) continue;
    // App-scoped allow rules come from the app allowlist map.
    if (_scopesOf(rule).isEmpty) allow.add(rule.pattern);
  }

  return {
    'filterEnabled': true,
    'globalAllow': allow.toList(),
    'globalBlock': normalBlock.toList(),
    'globalImportant': importantBlock.toList(),
    // Each package maps to `allow` / `block` / `important` arrays; the Go parser silently discards
    // any other shape.
    'appRules': _encodeAppRules(
      appAllowlist: appAllowlist,
      scopedBlock: scopedBlock,
      scopedImportant: scopedImportant,
    ),
    'invertedBlock': <Object?>[],
    'invertedAllow': <Object?>[],
    'specialBlock': <Object?>[],
    'specialAllow': <Object?>[],
    'disabledRules': <String>[],
  };
}

List<String> _scopesOf(MockRule rule) {
  final scope = rule.appScope?.trim();
  if (scope == null || scope.isEmpty || rule.appInverted) return const [];
  return [
    for (final part in scope.split('|'))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}

/// Per-app allowlists and app-scoped block rules, keyed by package name, not UID.
Map<String, Object?> _encodeAppRules({
  required Map<String, Set<String>> appAllowlist,
  required Map<String, Set<String>> scopedBlock,
  required Map<String, Set<String>> scopedImportant,
}) {
  final result = <String, Object?>{};
  final packages = <String>{
    ...appAllowlist.keys,
    ...scopedBlock.keys,
    ...scopedImportant.keys,
  };
  for (final packageName in packages) {
    if (packageName.trim().isEmpty) continue;
    final allowDomains = appAllowlist[packageName] ?? const <String>{};
    final block = scopedBlock[packageName] ?? const <String>{};
    final important = scopedImportant[packageName] ?? const <String>{};
    if (allowDomains.isEmpty && block.isEmpty && important.isEmpty) continue;
    result[packageName] = {
      'allow': [
        for (final domain in allowDomains)
          if (domain.trim().isNotEmpty) domain.trim(),
      ],
      'block': block.toList(),
      'important': important.toList(),
    };
  }
  return result;
}

String encodeRuleSnapshot(
  Map<RuleKind, List<MockRule>> rules, {
  Map<String, Set<String>> appAllowlist = const {},
}) => jsonEncode(buildRuleSnapshot(rules, appAllowlist: appAllowlist));

/// `Engine.setRewriteRules` takes a flat domain -> target map; CNAME targets and IP literals share
/// that shape.
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

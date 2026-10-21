/// Translates the Room rule tables into `Engine.applyRuleSnapshot` input.
///
/// 1.4.3 keeps "important" block rules in a separate list so they survive
/// allowlist overrides; everything else goes into the plain global arrays. The
/// Go policy engine lowercases and validates each pattern itself.
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
    // Shape mirrors `DomainPolicyEngine.buildRuleSnapshotJson`: every package
    // maps to an object with `allow` / `block` / `important` arrays. A bare
    // array here would be silently discarded by the Go parser instead of
    // applying the allowlist.
    'appRules': _encodeAppRules(appAllowlist),
    'invertedBlock': <Object?>[],
    'invertedAllow': <Object?>[],
    'specialBlock': <Object?>[],
    'specialAllow': <Object?>[],
    'disabledRules': <String>[],
  };
}

/// Per-app allowlists, keyed by **package name**.
///
/// 1.4.3's `GoTunnelRuleManager.syncAppAllowlist` keys this object by UID
/// because it feeds `Engine.setAppAllowlist` directly. The snapshot route takes
/// package names instead (the engine resolves them through `AppUidResolver`,
/// which the tunnel service registers), so no UID lookup is needed here.
Map<String, Object?> _encodeAppRules(Map<String, Set<String>> appAllowlist) {
  final result = <String, Object?>{};
  appAllowlist.forEach((packageName, domains) {
    if (packageName.trim().isEmpty || domains.isEmpty) return;
    result[packageName] = {
      'allow': [
        for (final domain in domains)
          if (domain.trim().isNotEmpty) domain.trim(),
      ],
      'block': <String>[],
      'important': <String>[],
    };
  });
  return result;
}

String encodeRuleSnapshot(
  Map<RuleKind, List<MockRule>> rules, {
  Map<String, Set<String>> appAllowlist = const {},
}) => jsonEncode(buildRuleSnapshot(rules, appAllowlist: appAllowlist));

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

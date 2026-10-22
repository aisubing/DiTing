/// Translates the Room rule tables into `Engine.applyRuleSnapshot` input.
///
/// 1.4.3 keeps "important" block rules in a separate list so they survive
/// allowlist overrides; everything else goes into the plain global arrays. The
/// Go policy engine lowercases and validates each pattern itself.
///
/// **App-scoped rules never go into the global arrays.** A rule whose
/// `appScope` is set (e.g. `*$app=com.foo` / `||ads.com^$app=com.foo`) applies
/// to one app only; the engine expects it in `appRules[<pkg>].block` /
/// `.important`, keyed by package name exactly like
/// `DomainPolicyEngine.buildRuleSnapshotJson`. Emitting it globally instead
/// would widen a single-app block into an all-app block.
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
  // package -> block / important patterns sourced from app-scoped rules.
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
    // App-scoped allow rules are already covered by the app allowlist map; the
    // rule-table allow rows are the global ones. Keep globals here.
    if (_scopesOf(rule).isEmpty) allow.add(rule.pattern);
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

/// Split an `appScope` package list (`|`-separated) into trimmed package names.
List<String> _scopesOf(MockRule rule) {
  final scope = rule.appScope?.trim();
  if (scope == null || scope.isEmpty || rule.appInverted) return const [];
  return [
    for (final part in scope.split('|'))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}

/// Per-app allowlists + app-scoped block rules, keyed by **package name**.
///
/// 1.4.3's `GoTunnelRuleManager.syncAppAllowlist` keys this object by UID
/// because it feeds `Engine.setAppAllowlist` directly. The snapshot route takes
/// package names instead (the engine resolves them through `AppUidResolver`,
/// which the tunnel service registers), so no UID lookup is needed here.
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
    // Skip packages that would contribute nothing in any of the three arrays.
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

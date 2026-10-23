import 'package:diting/data/db/legacy_database.dart';
import 'package:diting/data/db/rule_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Null on non-Android hosts, tests and fresh installs without the legacy DB.
final ruleRepositoryProvider = Provider<RuleRepository?>((ref) => null);

/// Server mode keeps its own rule dataset (`diting_dns_rules`); opening is lazy and in-place, so
/// the file's `user_version` and journal mode stay untouched.
final serverRuleRepositoryProvider = FutureProvider<RuleRepository?>((
  ref,
) async {
  final db = await LegacyDatabase.open(LegacyDatabase.serverFile);
  return db == null ? null : RuleRepository(db);
});

/// Express mode owns `diting_express` (version 2); same tables, separate file.
final expressRuleRepositoryProvider = FutureProvider<RuleRepository?>((
  ref,
) async {
  final db = await LegacyDatabase.open(LegacyDatabase.expressFile);
  return db == null ? null : RuleRepository(db);
});

/// Rules visible on the first frame; `main()` overrides this with the database snapshot.
final initialRulesProvider = Provider<Map<RuleKind, List<MockRule>>>(
  (ref) => {
    for (final kind in RuleKind.values) kind: [...mockRulesOf(kind)],
  },
);

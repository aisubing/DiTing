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

/// Database snapshot backing `rulesProvider`. Starts empty: the full-table load can take seconds
/// on subscription-sized datasets, so `main()` fills it after the first frame instead of blocking
/// `runApp` (the legacy app likewise never waited on rules before its first frame).
class InitialRulesNotifier extends Notifier<Map<RuleKind, List<MockRule>>> {
  @override
  Map<RuleKind, List<MockRule>> build() => {
        for (final kind in RuleKind.values) kind: const [],
      };

  void fill(Map<RuleKind, List<MockRule>> rules) => state = rules;
}

final initialRulesProvider =
    NotifierProvider<InitialRulesNotifier, Map<RuleKind, List<MockRule>>>(
      InitialRulesNotifier.new,
    );

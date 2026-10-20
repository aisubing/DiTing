import 'package:diting/data/db/rule_repository.dart';
import 'package:diting/data/mock_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Null on non-Android hosts, tests and fresh installs without the legacy DB.
final ruleRepositoryProvider = Provider<RuleRepository?>((ref) => null);

/// Rules visible on the first frame.
///
/// `main()` overrides this with the database snapshot. The mock default keeps
/// widget tests and the desktop gallery populated without touching real data.
final initialRulesProvider = Provider<Map<RuleKind, List<MockRule>>>(
  (ref) => {
    for (final kind in RuleKind.values) kind: [...mockRulesOf(kind)],
  },
);

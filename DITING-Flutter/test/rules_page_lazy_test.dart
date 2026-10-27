// Regression for the 2026-10-27 ANR: a subscription-sized rule table must not be inflated in the
// first frame. The page builds rows lazily, so only the viewport's rows exist.
import 'package:diting/data/db/rule_providers.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/pages/rules/rules_page.dart';
import 'package:diting/state/rules_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_host.dart';

/// Fixed state for one-shot override of the initial-rules provider.
class _FixedInitialRules extends InitialRulesNotifier {
  _FixedInitialRules(this._initial);

  final Map<RuleKind, List<MockRule>> _initial;

  @override
  Map<RuleKind, List<MockRule>> build() => _initial;
}

List<MockRule> _subscriptionRules(int count) => [
  for (var i = 0; i < count; i++)
    MockRule(
      id: '$i',
      pattern: 'rule-$i.example',
      kind: RuleKind.block,
      source: RuleSource.subscription,
      subscriptionName: 'filter_1.txt',
    ),
];

void main() {
  test('筛选与统计共用同一份结果', () {
    final container = ProviderContainer(
      overrides: [
        initialRulesProvider.overrideWith(
          () => _FixedInitialRules({
            RuleKind.block: [
              const MockRule(
                id: '1',
                pattern: 'ads.example',
                kind: RuleKind.block,
                source: RuleSource.subscription,
              ),
              const MockRule(
                id: '2',
                pattern: 'mine.example',
                kind: RuleKind.block,
                source: RuleSource.user,
                enabled: false,
              ),
              const MockRule(
                id: '3',
                pattern: 'rewrite.example',
                kind: RuleKind.block,
                source: RuleSource.user,
                target: 'cdn.example',
              ),
            ],
          }),
        ),
      ],
    );
    addTearDown(container.dispose);

    const all = RuleListFilter(kind: RuleKind.block);
    final allTally = container.read(ruleListTallyProvider(all));
    expect(allTally.total, 3);
    expect(allTally.enabled, 2);
    expect(allTally.custom, 2);
    expect(allTally.matched, 3);
    expect(allTally.matchedEnabled, 2);

    // Source chip narrows the rows without touching the table-wide stats.
    const userOnly = RuleListFilter(
      kind: RuleKind.block,
      source: RuleSource.user,
    );
    final userTally = container.read(ruleListTallyProvider(userOnly));
    expect(userTally.total, 3);
    expect(userTally.matched, 2);
    expect(userTally.matchedEnabled, 1);

    // The query also reaches the rewrite target, so "cdn" finds the rewritten rule.
    const byTarget = RuleListFilter(kind: RuleKind.block, query: 'cdn');
    expect(
      container.read(filteredRulesProvider(byTarget)).map((rule) => rule.id),
      ['3'],
    );
  });

  testWidgets('订阅级规则表首帧只构建可见行', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialRulesProvider.overrideWith(
            () => _FixedInitialRules({
              RuleKind.block: _subscriptionRules(20000),
            }),
          ),
        ],
        child: const AppHost(child: RulesPage(kind: 'block')),
      ),
    );
    await tester.pumpAndSettle();

    // The caption reports the whole table without the list having been built.
    expect(find.text('共 20000 条 · 启用 20000'), findsOneWidget);
    // First rows are laid out; rows far below the viewport were never inflated.
    expect(find.text('rule-0.example'), findsOneWidget);
    expect(find.text('rule-15000.example'), findsNothing);
  });
}

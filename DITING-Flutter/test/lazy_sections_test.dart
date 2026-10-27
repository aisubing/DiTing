// Regression guard for the bulk-list pages: rows behind the viewport must not be built in the
// first frame. The rule tables froze the app this way (2026-10-27 ANR, 191,090 rows), and every
// other large list in the app now goes through `lazySectionSlivers`.
import 'package:diting/data/db/dns_cache_repository.dart';
import 'package:diting/pages/logs/logs_cache_page.dart';
import 'package:diting/state/log_dashboard_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/section_slivers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is only exported from `misc.dart`
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/app_host.dart';

List<DnsCacheRecord> _entries(int count) => [
  for (var i = 0; i < count; i++)
    DnsCacheRecord(
      domain: 'cache-$i.example',
      queryType: 1,
      expiresAt: DateTime.now().millisecondsSinceEpoch + 300 * 1000,
      hitCount: i,
      originalTtlSeconds: 300,
      responseSize: 64,
    ),
];

void main() {
  testWidgets('惰性区段首帧只构建可见行', (tester) async {
    await tester.pumpWidget(
      AppHost(
        child: CustomScrollView(
          slivers: [
            ...lazySectionSlivers(
              title: '条目',
              itemCount: 5000,
              itemBuilder: (context, index) =>
                  ListItem(title: Text('row-$index')),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('条目'), findsOneWidget);
    expect(find.text('row-0'), findsOneWidget);
    // Far below the viewport, so never inflated.
    expect(find.text('row-4000'), findsNothing);
  });

  testWidgets('空区段用占位替代头尾', (tester) async {
    await tester.pumpWidget(
      AppHost(
        child: CustomScrollView(
          slivers: [
            ...lazySectionOrEmpty(
              title: '条目',
              itemCount: 0,
              itemBuilder: (context, index) => const SizedBox.shrink(),
              empty: const Text('还没有条目'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有条目'), findsOneWidget);
    expect(find.text('条目'), findsNothing);
  });

  testWidgets('DNS 缓存表只构建可见行', (tester) async {
    final overrides = <Override>[
      dnsCacheProvider.overrideWith((ref) async => _entries(200)),
      cacheLastHitProvider.overrideWith((ref) async => const <String, int?>{}),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const AppHost(child: LogsCachePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('cache-0.example'), findsOneWidget);
    // Row 150 of 200 sits well below a 891 pt viewport.
    expect(find.text('cache-150.example'), findsNothing);
  });
}

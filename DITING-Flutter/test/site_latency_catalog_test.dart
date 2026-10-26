import 'package:diting/data/site_latency_categories.dart';
import 'package:diting/data/site_latency_targets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The catalog feeds both the card and the detail page, so a duplicate id or an empty category
/// would show up as a missing row rather than an error.
void main() {
  test('id 与 host 都不重复', () {
    final ids = [for (final target in siteLatencyTargets) target.id];
    final hosts = [for (final target in siteLatencyTargets) target.host];
    expect(ids.toSet().length, ids.length);
    expect(hosts.toSet().length, hosts.length);
  });

  test('站点大幅扩充且每个分类都有站点', () {
    expect(siteLatencyTargets.length, greaterThanOrEqualTo(44));
    for (final category in SiteCategory.values) {
      expect(
        siteLatencyInCategory(category),
        isNotEmpty,
        reason: '${category.label} 分类为空',
      );
    }
    final grouped = [
      for (final category in SiteCategory.values)
        ...siteLatencyInCategory(category),
    ];
    expect(grouped.length, siteLatencyTargets.length);
  });

  test('默认四个站点都在目录里', () {
    for (final id in defaultDashboardSiteIds) {
      expect(siteLatencyById(id), isNotNull, reason: id);
    }
    expect(defaultDashboardSiteIds.length, dashboardSiteCount);
  });

  test('解析出的仪表盘站点总是四个且不重复', () {
    expect(resolveDashboardSites(const []), hasLength(dashboardSiteCount));
    expect(
      resolveDashboardSites(const ['no_such_site']),
      hasLength(dashboardSiteCount),
    );
    final picked = resolveDashboardSites(const [
      'github',
      'github',
      'steam',
      'netflix',
      'spotify',
    ]);
    expect(picked.map((target) => target.id), [
      'github',
      'steam',
      'netflix',
      'spotify',
    ]);
  });
}

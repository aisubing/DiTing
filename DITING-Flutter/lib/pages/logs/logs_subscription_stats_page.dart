import 'package:diting/pages/logs/logs_shared.dart';
import 'package:diting/state/log_dashboard_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/section_slivers.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Subscription rule block rate. Numerator counts BLOCKED DNS rows and blocked/invalid HTTPS
/// rows carrying a blockSubscriptionId, matching upstream; missing data is never invented.
class LogsSubscriptionStatsPage extends ConsumerWidget {
  const LogsSubscriptionStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(subscriptionInterceptionProvider);
    final range = ref.watch(subscriptionStatsRangeProvider);
    return CommonScaffold(
      title: '订阅拦截率',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: () => ref.read(dnsLogRevisionProvider.notifier).bump(),
          icon: const GlyphIcon(AppGlyphs.refresh),
        ),
      ],
      body: SliverPageBody(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                generateSection(
                  title: '时间范围',
                  items: [
                    LogStatsRangeSelector<SubscriptionStatsRange>(
                      values: SubscriptionStatsRange.values,
                      labelOf: (option) => option.label,
                      value: range,
                      onChanged: (value) => ref
                          .read(subscriptionStatsRangeProvider.notifier)
                          .select(value),
                    ),
                  ],
                ),
                const ListFooter(
                  text:
                      '拦截率为所选时间范围内，该订阅拦截请求数占全部已记录请求'
                      '（DNS + HTTPS）的比例。',
                ),
              ],
            ),
          ),
          ..._statsSlivers(context, asyncStats),
        ],
      ),
    );
  }

  /// Stats sections as slivers. The per-subscription list is built on demand: the table grows
  /// with the number of imported subscriptions, and inflating it eagerly was the same first-frame
  /// trap the rule lists hit.
  List<Widget> _statsSlivers(
    BuildContext context,
    AsyncValue<SubscriptionInterceptionSnapshot> asyncStats,
  ) {
    if (!asyncStats.hasValue) {
      if (asyncStats.hasError) {
        return lazySectionSlivers(
          title: '概览',
          itemCount: 1,
          itemBuilder: (context, _) => ListItem(
            leading: const GlyphIcon(AppGlyphs.error),
            title: const Text('无法读取拦截统计'),
            subtitle: Text('${asyncStats.error}'),
          ),
        );
      }
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: LogsPageLoading(label: '正在加载统计数据'),
          ),
        ),
      ];
    }
    final snapshot = asyncStats.requireValue;
    final colorScheme = context.colorScheme;

    if (snapshot.missingColumn) {
      return lazySectionSlivers(
        title: '屏蔽订阅',
        itemCount: 1,
        itemBuilder: (context, _) => ListItem(
          leading: GlyphIcon(AppGlyphs.warning, color: colorScheme.warning),
          title: const Text('当前数据库缺少订阅标记列'),
          subtitle: const Text(
            '这张库是在加入「订阅拦截统计」之前创建的，日志行里没有记录'
            'blockSubscriptionId。重新产生请求日志后即可统计，历史数据无法补算。',
          ),
        ),
      );
    }

    return [
      SliverToBoxAdapter(
        child: generateSection(
          title: '概览',
          items: [
            StatStrip(
              stats: [
                StatItem(
                  label: '全部已记录请求',
                  value: countOf(snapshot.totalRequests),
                ),
              ],
            ),
          ],
          footer: 'DNS 与 HTTPS 日志合计，含通过、屏蔽和失败。',
        ),
      ),
      if (snapshot.items.isEmpty)
        SliverToBoxAdapter(
          child: generateSection(
            title: '屏蔽订阅',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.rules),
                title: const Text('暂无屏蔽订阅'),
                subtitle: const Text('导入屏蔽订阅并产生 DNS 或 HTTPS 请求后，此处将显示其拦截率。'),
              ),
            ],
          ),
        )
      else
        ...lazySectionSlivers(
          title: '屏蔽订阅',
          itemCount: snapshot.items.length,
          footer: '按拦截次数排序；「已删除」表示订阅已移除，但历史命中仍保留。',
          itemBuilder: (context, index) {
            final item = snapshot.items[index];
            return ListItem(
              leading: GlyphIcon(
                item.deleted ? AppGlyphs.warning : AppGlyphs.rules,
                color: item.deleted
                    ? colorScheme.onSurfaceVariant
                    : (item.enabled ? colorScheme.primary : null),
              ),
              title: Text(item.name),
              subtitle: Text(
                '${item.statusLabel} | 拦截 ${countOf(item.hits)} 次 | '
                '${percentOf(item.rate)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                percentOf(item.rate),
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            );
          },
        ),
    ];
  }
}

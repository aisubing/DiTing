import 'package:diting/app/l10n/l10n.dart';
import 'package:diting/pages/logs/logs_shared.dart';
import 'package:diting/state/log_dashboard_providers.dart';
import 'package:diting/state/log_race_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/section_slivers.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Race stats from the real `dns_race_log` table, aggregated per time window. An empty
/// table leaves every section empty and the overview at a dash, never demo numbers.
class LogsRacePage extends ConsumerWidget {
  const LogsRacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(raceStatsProvider);
    final range = ref.watch(raceStatsRangeProvider);
    return CommonScaffold(
      title: '竞速统计',
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
            child: generateSection(
              title: '时间范围',
              items: [
                LogStatsRangeSelector<LogStatsRange>(
                  values: LogStatsRange.values,
                  labelOf: (range) => range.label(context.l10n),
                  value: range,
                  onChanged: (value) =>
                      ref.read(raceStatsRangeProvider.notifier).select(value),
                ),
              ],
            ),
          ),
          ..._statsSlivers(context, asyncStats, range),
          const SliverToBoxAdapter(
            child: ListFooter(
              text:
                  '只统计真实发出过 DoH 请求的竞速解析；'
                  '本机缓存命中的查询不进这张表。',
            ),
          ),
        ],
      ),
    );
  }

  /// Stats sections as slivers. The ranking and the strategy lists are built on demand: they grow
  /// with the number of configured resolvers, and eager construction is the same first-frame trap
  /// the rule lists hit with a large subscription.
  List<Widget> _statsSlivers(
    BuildContext context,
    AsyncValue<RaceStatsSnapshot> asyncStats,
    LogStatsRange range,
  ) {
    if (!asyncStats.hasValue) {
      if (asyncStats.hasError) {
        return lazySectionSlivers(
          title: '概览',
          itemCount: 1,
          itemBuilder: (context, _) => ListItem(
            leading: const GlyphIcon(AppGlyphs.error),
            title: const Text('无法读取竞速记录'),
            subtitle: Text('${asyncStats.error}'),
          ),
        );
      }
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: LogsPageLoading(label: '正在读取竞速记录'),
          ),
        ),
      ];
    }
    final snapshot = asyncStats.requireValue;
    final summary = snapshot.summary;
    final colorScheme = context.colorScheme;
    final hasData = summary.requests > 0;

    return [
      SliverToBoxAdapter(
        child: generateSection(
          title: '概览',
          footer: hasData
              ? '${range.label}内共 ${countOf(summary.requests)} 次竞速解析。'
              : '所选时间范围内还没有竞速记录。',
          items: [
            StatStrip(
              stats: [
                StatItem(label: '竞速请求', value: countOf(summary.requests)),
                StatItem(
                  label: '成功',
                  value: hasData ? countOf(summary.successes) : '—',
                  color: colorScheme.success,
                ),
                StatItem(
                  label: '失败',
                  value: hasData ? countOf(summary.failures) : '—',
                  color: hasData && summary.failures > 0
                      ? colorScheme.error
                      : null,
                ),
                StatItem(
                  label: '平均耗时',
                  value: hasData ? millisOf(summary.averageLatencyMs) : '—',
                ),
              ],
            ),
          ],
        ),
      ),
      if (snapshot.strategyStats.isNotEmpty)
        ...lazySectionSlivers(
          title: '策略概览',
          itemCount: snapshot.strategyStats.length,
          footer:
              '缓存命中的请求不触发竞速，因此不进这张表；'
              '首选命中率 = 首选服务商即胜出且成功的比例。',
          itemBuilder: (context, index) {
            final item = snapshot.strategyStats[index];
            return ListItem(
              leading: GlyphIcon(_strategyGlyph(item.strategy), size: 20),
              title: Text(item.label),
              subtitle: Text(_strategySubtitle(item), maxLines: 2),
              trailing: Text(
                '${countOf(item.requests)} 次',
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            );
          },
        ),
      if (snapshot.entries.isEmpty)
        SliverToBoxAdapter(
          child: generateSection(
            title: '胜出服务商',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.shuffle),
                title: const Text('还没有胜出记录'),
                subtitle: const Text('竞速解析成功后，胜出的服务商会在这里按次数排序。'),
              ),
            ],
          ),
        )
      else
        ...lazySectionSlivers(
          title: '胜出服务商',
          itemCount: snapshot.entries.length,
          footer: '按胜出次数排序；平均耗时是该服务商胜出时的耗时均值。',
          itemBuilder: (context, index) {
            final entry = snapshot.entries[index];
            return ListItem(
              leading: SizedBox(
                width: 24,
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: AppTextStyle.headline.of(context, emphasized: true),
                ),
              ),
              title: Text(entry.name),
              subtitle: Text('平均胜出耗时 ${millisOf(entry.averageLatencyMs)}'),
              trailing: Text(
                '${countOf(entry.wins)} 次',
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: colorScheme.primary),
              ),
            );
          },
        ),
      if (snapshot.smartSelections.isNotEmpty)
        ...lazySectionSlivers(
          title: '智能选择首选',
          itemCount: snapshot.smartSelections.length,
          footer:
              '只有智能选择策略下才有意义；首选命中率统计「首选服务商就是'
              '胜出者」的比例，兜底救回的查询不计入。',
          itemBuilder: (context, index) {
            final item = snapshot.smartSelections[index];
            return ListItem(
              leading: const GlyphIcon(AppGlyphs.sparkle, size: 20),
              title: Text(item.name),
              subtitle: Text(
                '首选命中 ${percentOf(item.selectedSuccessRate)} · '
                '平均首选耗时 ${millisOf(item.averageElapsedMs)}',
                maxLines: 2,
              ),
              trailing: Text(
                '${countOf(item.selectedCount)} 次',
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
            );
          },
        ),
    ];
  }

  /// Row subtitle; only smart selection appends primary hit rate and fallbacks.
  static String _strategySubtitle(RaceStrategyDisplay item) {
    final parts = <String>[
      '成功 ${percentOf(item.successRate)}',
      '平均 ${millisOf(item.averageElapsedMs)}',
    ];
    if (item.strategy == 'smart_prediction' || item.strategy == 'prediction') {
      parts.add('首选命中 ${percentOf(item.primaryWinRate)}');
      parts.add('兜底 ${countOf(item.fallbackUses)} 次');
    }
    return parts.join(' · ');
  }

  static Glyph _strategyGlyph(String strategy) => switch (strategy) {
    'smart_prediction' || 'prediction' => AppGlyphs.sparkle,
    'primary_backup' => AppGlyphs.split,
    'single' => AppGlyphs.dns,
    _ => AppGlyphs.shuffle,
  };
}

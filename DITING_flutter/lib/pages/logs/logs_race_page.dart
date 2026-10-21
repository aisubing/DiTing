import 'package:diting/pages/logs/logs_shared.dart';
import 'package:diting/state/log_dashboard_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// 竞速统计（1.4.3 `RaceStatsScreen`）。
///
/// 结构照抄旧版：时间范围选择器 → 「概览」组（请求 / 成功 / 失败 / 平均耗时）
/// → 「胜出服务商」组（每个服务商的胜出次数与平均耗时）。
///
/// 数据源是真实表 `dns_race_log`（[raceStatsProvider]，按窗口聚合）。库空时
/// 「概览」四格是破折号、「胜出服务商」是空状态——不塞演示数字。
///
/// 旧版还有「策略统计」与「智能选择统计」两组，对应的列
/// （`strategy` / `fallbackUsed` / `selectedProviderId`）在本仓的原生写入侧
/// 尚未落地，因此**不列**：列出来只会是一张全 0 的表。等写入侧补齐再补这两组。
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
      body: PageBody(
        children: [
          generateSection(
            title: '时间范围',
            items: [
              LogStatsRangeSelector<LogStatsRange>(
                values: LogStatsRange.values,
                labelOf: (range) => range.label,
                value: range,
                onChanged: (value) =>
                    ref.read(raceStatsRangeProvider.notifier).select(value),
              ),
            ],
          ),
          _buildStats(context, asyncStats, range),
          const ListFooter(
            text:
                '只统计真实发出过 DoH 请求的竞速解析；'
                '本机缓存命中的查询不进这张表。',
          ),
        ],
      ),
    );
  }

  Widget _buildStats(
    BuildContext context,
    AsyncValue<RaceStatsSnapshot> asyncStats,
    LogStatsRange range,
  ) {
    if (!asyncStats.hasValue) {
      if (asyncStats.hasError) {
        return generateSection(
          title: '概览',
          items: [
            ListItem(
              leading: const GlyphIcon(AppGlyphs.error),
              title: const Text('无法读取竞速记录'),
              subtitle: Text('${asyncStats.error}'),
            ),
          ],
        );
      }
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: LogsPageLoading(label: '正在读取竞速记录'),
      );
    }
    final snapshot = asyncStats.requireValue;
    final summary = snapshot.summary;
    final colorScheme = context.colorScheme;
    final hasData = summary.requests > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        generateSection(
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
        if (snapshot.entries.isEmpty)
          generateSection(
            title: '胜出服务商',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.shuffle),
                title: const Text('还没有胜出记录'),
                subtitle: const Text('竞速解析成功后，胜出的服务商会在这里按次数排序。'),
              ),
            ],
          )
        else
          generateSection(
            title: '胜出服务商',
            footer: '按胜出次数排序；平均耗时是该服务商胜出时的耗时均值。',
            items: [
              for (final (index, entry) in snapshot.entries.indexed)
                ListItem(
                  leading: SizedBox(
                    width: 24,
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: AppTextStyle.headline.of(
                        context,
                        emphasized: true,
                      ),
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
                ),
            ],
          ),
      ],
    );
  }
}

/// 三档时间范围由 `logs_shared.dart` 的 `LogStatsRangeSelector` 统一渲染。

import 'package:diting/pages/logs/logs_shared.dart';
import 'package:diting/state/log_dashboard_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/log_refresh_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Bootstrap DNS stats from the real `bootstrap_log` table, one row per probe.
class LogsBootstrapPage extends ConsumerStatefulWidget {
  const LogsBootstrapPage({super.key});

  @override
  ConsumerState<LogsBootstrapPage> createState() => _LogsBootstrapPageState();
}

class _LogsBootstrapPageState extends ConsumerState<LogsBootstrapPage> {
  /// Probes land here continuously while the tunnel resolves; follow them without a tap.
  LogLiveRefreshNotifier? _logRefresh;

  @override
  void initState() {
    super.initState();
    _logRefresh = ref.read(logLiveRefreshProvider.notifier);
    _logRefresh!.attachPolling();
  }

  @override
  void dispose() {
    _logRefresh?.detachPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncStats = ref.watch(bootstrapStatsProvider);
    final range = ref.watch(bootstrapStatsRangeProvider);
    return CommonScaffold(
      title: 'Bootstrap 统计',
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
                labelOf: (option) => option.label,
                value: range,
                onChanged: (value) => ref
                    .read(bootstrapStatsRangeProvider.notifier)
                    .select(value),
              ),
            ],
          ),
          _buildStats(context, asyncStats, range),
          const ListFooter(text: '成功率为成功次数 ÷ 尝试次数；平均耗时按各节点的尝试次数加权。'),
        ],
      ),
    );
  }

  Widget _buildStats(
    BuildContext context,
    AsyncValue<BootstrapStatsSnapshot> asyncStats,
    LogStatsRange range,
  ) {
    if (!asyncStats.hasValue) {
      if (asyncStats.hasError) {
        return generateSection(
          title: '概览',
          items: [
            ListItem(
              leading: const GlyphIcon(AppGlyphs.error),
              title: const Text('无法读取 Bootstrap 记录'),
              subtitle: Text('${asyncStats.error}'),
            ),
          ],
        );
      }
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: LogsPageLoading(label: '正在读取 Bootstrap 记录'),
      );
    }
    final snapshot = asyncStats.requireValue;
    final colorScheme = context.colorScheme;
    final hasData = snapshot.attempts > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        generateSection(
          title: '概览',
          footer: hasData
              ? '${range.label}内共 ${countOf(snapshot.attempts)} 次 Bootstrap 探测。'
              : '所选时间范围内还没有 Bootstrap 探测记录。',
          items: [
            StatStrip(
              stats: [
                StatItem(label: '尝试次数', value: countOf(snapshot.attempts)),
                StatItem(
                  label: '成功',
                  value: hasData ? countOf(snapshot.successes) : '—',
                  color: colorScheme.success,
                ),
                StatItem(
                  label: '成功率',
                  value: hasData ? percentOf(snapshot.successRate) : '—',
                ),
                StatItem(
                  label: '平均耗时',
                  value: hasData ? millisOf(snapshot.averageElapsedMs) : '—',
                ),
              ],
            ),
          ],
        ),
        if (snapshot.ips.isEmpty)
          generateSection(
            title: '节点',
            items: [
              ListItem(
                leading: const GlyphIcon(AppGlyphs.dns),
                title: const Text('还没有探测记录'),
                subtitle: const Text(
                  '开启「启用 Bootstrap IP」并产生解析后，各节点的尝试与成功率会出现在这里。',
                ),
              ),
            ],
          )
        else
          generateSection(
            title: '节点',
            footer: '按尝试次数排序；显示最近窗口内的聚合值。',
            items: [
              for (final ip in snapshot.ips)
                ListItem(
                  leading: const GlyphIcon(AppGlyphs.dns),
                  title: Text(ip.name.isEmpty ? ip.id : ip.name),
                  subtitle: Text(
                    '${ip.ip} · 成功 '
                    '${percentOf(ip.attempts == 0 ? 0 : ip.successes / ip.attempts)}'
                    ' · 平均 ${millisOf(ip.averageElapsedMs ?? 0)}'
                    '${ip.failures > 0 ? ' · 失败 ${countOf(ip.failures)} 次' : ''}',
                    maxLines: 2,
                  ),
                  trailing: Text(
                    '${countOf(ip.attempts)} 次',
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
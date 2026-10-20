import 'package:diting/data/db/dns_log_repository.dart';
import 'package:diting/data/mock_dashboard.dart';
import 'package:diting/routes/routes.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/log_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 首页快捷入口：四个常用页 + 服务统计条。
///
/// 上游首页没有这一块（它有底栏导航），但 DITING 的底栏只有六个 tab，日志/流量
/// 之外还有连接、配置等页，快捷入口把它们收在一处，避免功能中心点两层。
class HomeQuickEntries extends ConsumerWidget {
  const HomeQuickEntries({super.key, required this.mode});

  final AppWorkMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const entries = <(String, Glyph, String)>[
      ('连接', AppGlyphs.connections, ObservabilityPaths.connections),
      ('请求', AppGlyphs.requests, ObservabilityPaths.requests),
      ('DNS', AppGlyphs.dns, ObservabilityPaths.dnsQueries),
      ('资源', AppGlyphs.resources, ObservabilityPaths.resources),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const _ServiceStatsStrip(),
          Row(
            spacing: 10,
            children: [
              for (final (label, glyph, route) in entries)
                Expanded(
                  child: CommonCard(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: () => context.push(route),
                    child: Column(
                      spacing: 6,
                      children: [
                        GlyphIcon(glyph, size: 22),
                        Text(
                          label,
                          style: AppTextStyle.caption1.of(context),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 服务统计条：今日查询 / 缓存命中 / 平均延迟。
///
/// 三个数都来自 `dns_log` 的当日聚合（与日志仪表盘同一 provider），不是引擎
/// session 计数：后者重启隧道就归零，与「今日」语义不符。电源未运行时不显示
/// 上次的旧值——但仍在运行的隧道会继续写日志，所以这里只切换文案不丢弃数据。
class _ServiceStatsStrip extends ConsumerWidget {
  const _ServiceStatsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final power = ref.watch(powerProvider);
    final core = ref.watch(coreStateProvider);
    final running = power.isRunning && core == CoreState.running;
    final daily =
        ref.watch(dnsLogDailyStatsProvider).value ??
        const DnsLogDailyStats.empty();
    return CommonCard(
      child: StatStrip(
        stats: [
          StatItem(
            label: '今日查询',
            value: running ? _formatCount(daily.total) : '0',
          ),
          StatItem(
            label: '缓存命中',
            value: running ? '${(daily.cacheHitRate * 100).round()}' : '0',
            unit: '%',
            color: context.colorScheme.success,
          ),
          StatItem(
            label: '平均延迟',
            value: running && daily.latencySamples > 0
                ? '${daily.averageLatencyMs}'
                : '—',
            unit: running && daily.latencySamples > 0 ? 'ms' : null,
          ),
        ],
      ),
    );
  }
}

/// 与日志页同口径的千分位，避免首页显示 28471、日志页显示 28,471。
String _formatCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

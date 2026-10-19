import 'package:diting/data/mock_dashboard.dart';
import 'package:diting/routes/routes.dart';
import 'package:diting/state/dashboard_providers.dart';
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
/// 电源未运行时全部归零——上游同样在停止态显示空数据而不是上次的旧值。
class _ServiceStatsStrip extends ConsumerWidget {
  const _ServiceStatsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final power = ref.watch(powerProvider);
    final core = ref.watch(coreStateProvider);
    final running = power.isRunning && core == CoreState.running;
    final stats = mockServiceStatsSnapshot;
    return CommonCard(
      child: StatStrip(
        stats: [
          StatItem(
            label: '今日查询',
            value: running ? stats.queries : '0',
          ),
          StatItem(
            label: '缓存命中',
            value: running ? stats.cacheHitRate : '0',
            unit: '%',
            color: context.colorScheme.success,
          ),
          StatItem(
            label: '平均延迟',
            value: running ? stats.averageLatency : '—',
            unit: running ? 'ms' : null,
          ),
        ],
      ),
    );
  }
}

/// 统计条要的四个数，从 `mock_data` 的 `mockServiceStats` 摊平。
///
/// 单独建一个小结构而不是直接用 `ServiceStats`，是因为这里只要展示用的字符串，
/// 不想要那层的 `Duration` / `double` 语义。
const mockServiceStatsSnapshot = (
  queries: '28,471',
  cacheHitRate: '98',
  averageLatency: '14',
);

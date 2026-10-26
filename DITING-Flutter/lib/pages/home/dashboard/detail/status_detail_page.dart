import 'package:diting/data/dashboard_models.dart';
import 'package:diting/pages/home/dashboard/cards/dashboard_block_parts.dart';
import 'package:diting/pages/home/dashboard/detail/dashboard_detail_parts.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/primary_provider_providers.dart';
import 'package:diting/state/server_status_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Status detail: the card only fits run time, the provider name and today's query count. This
/// page adds what the card had to drop — core state wording per work mode, the full service
/// counters (hit / block / latency / hit rate), the provider's protocol and address, and the
/// listening port when server mode owns one.
class StatusDetailPage extends ConsumerWidget {
  const StatusDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = ref.watch(coreStateProvider);
    final mode = ref.watch(workModeProvider);
    final stats = ref.watch(serviceStatsProvider);
    final primary = ref.watch(primaryProviderProvider);
    final serverStatus = ref.watch(serverStatusProvider);
    final port = ref.watch(serverPortProvider);
    final colorScheme = context.colorScheme;
    final health = _healthOf(mode, core, serverStatus, colorScheme);
    return DashboardDetailScaffold(
      title: '状态详情',
      children: [
        DashboardDetailFigure(
          label: '运行时长',
          value: core.isRunning ? stats.uptimeLabel : '—',
          hint: core.isRunning
              ? health.summary
              : '${mode.title}${core.label}，计时已暂停',
          color: core.isRunning ? colorScheme.onSurface : null,
        ),
        generateSection(
          title: '内核',
          items: [
            ListItem(
              leading: GlyphIcon(health.glyph, size: 20, color: health.color),
              title: Text(mode.title),
              subtitle: Text(health.summary),
              trailing: Text(
                core.label,
                style: AppTextStyle.subheadline.of(
                  context,
                  emphasized: true,
                ).copyWith(color: health.color),
              ),
            ),
            KeyValueRow(label: '工作模式', value: mode.title),
            KeyValueRow(label: '内核状态', value: core.label),
            if (mode == AppWorkMode.server)
              KeyValueRow(
                label: '监听端口',
                value: serverStatus == ServerStatus.running ? '$port' : '未监听',
                monospace: true,
              ),
          ],
        ),
        generateSection(
          title: '当前服务商',
          items: [
            if (primary case final provider?)
              ListItem(
                leading: const GlyphIcon(AppGlyphs.dns, size: 20),
                title: Text(provider.name),
                subtitle: Text('${provider.protocol.label} · ${provider.address}'),
                trailing: Text(
                  '${provider.latencyMs} ms',
                  style: AppTextStyle.subheadline.of(
                    context,
                    emphasized: true,
                  ).copyWith(color: colorScheme.primary),
                ),
              )
            else
              const ListItem(
                leading: GlyphIcon(AppGlyphs.dns, size: 20),
                title: Text('未选择服务商'),
                subtitle: Text('在服务商管理里挑一个，解析才会走真实上游。'),
              ),
          ],
          footer: primary == null ? null : '延迟是该服务商的最近一次实测值，不是本机到目标的往返。',
        ),
        const ListHeader(title: '今日计数'),
        DashboardDetailStats(
          stats: [
            StatItem(label: '查询', value: dashboardCount(stats.queries)),
            StatItem(
              label: '缓存命中',
              value: dashboardCount(stats.cacheHits),
              color: colorScheme.primary,
            ),
            StatItem(
              label: '已拦截',
              value: dashboardCount(stats.blocked),
              color: colorScheme.error,
            ),
            StatItem(
              label: '平均时延',
              value: stats.averageLatencyMs <= 0
                  ? '—'
                  : '${stats.averageLatencyMs}',
              unit: 'ms',
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DashboardShareBar(
            segments: [
              (
                value: stats.cacheHits.toDouble(),
                color: colorScheme.primary,
              ),
              (value: stats.blocked.toDouble(), color: colorScheme.error),
              (
                value: (stats.queries - stats.cacheHits - stats.blocked).clamp(
                  0,
                  stats.queries,
                ).toDouble(),
                color: DashboardColors.of(context).track,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            '缓存命中率 ${dashboardPercent(stats.cacheHitRate)}',
            style: AppTextStyle.caption1.of(context).copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const ListFooter(
          text:
              '计数从本次内核启动开始累计，重启或切换工作模式后归零；'
              '已在服务器模式里做的重置也只清计数，不动规则与缓存。',
        ),
      ],
    );
  }

  /// Wording and colour for the core, per work mode: "running" means the tunnel in normal and
  /// express mode but a listening DNS port in server mode.
  static ({Glyph glyph, Color color, String summary}) _healthOf(
    AppWorkMode mode,
    CoreState core,
    ServerStatus serverStatus,
    ColorScheme colorScheme,
  ) {
    final glyph = core.isRunning
        ? AppGlyphs.checkCircle
        : core == CoreState.failed
        ? AppGlyphs.error
        : AppGlyphs.info;
    final summary = core.isRunning
        ? mode == AppWorkMode.server
              ? '本机 DNS 端口可用，局域网设备可把它当作 DNS'
              : '本机流量已经过谛听，解析与规则都在生效'
        : mode == AppWorkMode.server
        ? 'DNS 端口未监听，服务器模式当前不提供解析'
        : '内核未运行，本机流量按系统默认网络走';
    return (
      glyph: glyph,
      color: core.isRunning
          ? colorScheme.success
          : core == CoreState.failed
          ? colorScheme.error
          : colorScheme.onSurfaceVariant,
      summary: summary,
    );
  }
}

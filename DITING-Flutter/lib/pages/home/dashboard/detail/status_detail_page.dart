import 'package:diting/data/dashboard_models.dart';
import 'package:diting/data/mock_data.dart';
import 'package:diting/pages/home/dashboard/cards/dashboard_block_parts.dart';
import 'package:diting/pages/home/dashboard/detail/dashboard_detail_chart.dart';
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
    final colors = DashboardColors.of(context);
    final health = _healthOf(mode, core, serverStatus, colorScheme);
    return DashboardDetailScaffold(
      title: '状态详情',
      children: [
        DashboardDetailHero(
          glyph: AppGlyphs.clock,
          label: '运行时长',
          // Not running has no figure: "未计时" says it in words where a lone em dash looked
          // like a stray line under the label.
          value: core.isRunning ? stats.uptimeLabel : '未计时',
          color: core.isRunning ? colorScheme.onSurface : null,
          chipLabel: core.label,
          chipColor: health.color,
          hint: core.isRunning ? health.summary : '${mode.title}${core.label}，计时已暂停',
        ),
        DashboardDetailCard(
          glyph: AppGlyphs.status,
          title: '内核',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                spacing: 10,
                children: [
                  GlyphIcon(health.glyph, size: 20, color: health.color),
                  Expanded(
                    child: Text(
                      health.summary,
                      style: AppTextStyle.subheadline.of(context).copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              DashboardDetailRows(
                rows: [
                  DashboardDetailRow(label: '工作模式', value: mode.title),
                  DashboardDetailRow(label: '内核状态', value: core.label),
                  if (mode == AppWorkMode.server)
                    DashboardDetailRow(
                      label: '监听端口',
                      value: serverStatus == ServerStatus.running
                          ? '$port'
                          : '未监听',
                      monospace: true,
                      color: serverStatus == ServerStatus.running
                          ? colorScheme.primary
                          : null,
                    ),
                ],
              ),
            ],
          ),
        ),
        DashboardDetailCard(
          glyph: AppGlyphs.dns,
          title: '当前服务商',
          footer: primary == null ? null : '延迟是该服务商的最近一次实测值，不是本机到目标的往返。',
          child: primary == null
              ? Text(
                  '还没有选择服务商。在服务商管理里挑一个，解析才会走真实上游。',
                  style: AppTextStyle.subheadline.of(context).copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              : Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: 3,
                        children: [
                          Text(
                            primary.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.body
                                .of(context, emphasized: true)
                                .copyWith(color: colorScheme.onSurface),
                          ),
                          Text(
                            '${primary.protocol.label} · ${primary.address}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.caption1
                                .of(context)
                                .copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontFamily: appMonospaceFontFamily,
                                ),
                          ),
                        ],
                      ),
                    ),
                    _LatencyBadge(provider: primary),
                  ],
                ),
        ),
        DashboardDetailCard(
          glyph: AppGlyphs.requests,
          title: '今日计数',
          footer: '计数从本次内核启动开始累计，重启或切换工作模式后归零；'
              '已在服务器模式里做的重置也只清计数，不动规则与缓存。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: DashboardStatGrid(
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
                      // No unit on a missing value: "— ms" reads as a broken number.
                      value: stats.averageLatencyMs <= 0
                          ? '—'
                          : '${stats.averageLatencyMs}',
                      unit: stats.averageLatencyMs <= 0 ? null : 'ms',
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Row(
                    children: [
                      Text(
                        '缓存命中率',
                        style: AppTextStyle.caption1.of(context).copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dashboardPercent(stats.cacheHitRate),
                        style: DashboardText.figure(
                          context,
                          AppTextStyle.subheadline,
                          color: stats.cacheHits > 0
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  DashboardShareBar(
                    segments: [
                      (
                        value: stats.cacheHits.toDouble(),
                        color: colorScheme.primary,
                      ),
                      (
                        value: stats.blocked.toDouble(),
                        color: colorScheme.error,
                      ),
                      (
                        value: (stats.queries - stats.cacheHits - stats.blocked)
                            .clamp(0, stats.queries)
                            .toDouble(),
                        color: colors.track,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
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

/// Last measured latency of one provider. A provider that has never been probed stores `-1`, which
/// used to be rendered as the literal `-1 ms`; [providerLatencyLabel] turns it into 未测速.
class _LatencyBadge extends StatelessWidget {
  const _LatencyBadge({required this.provider});

  final MockProvider provider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final measured = provider.latencyMs >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: DashboardColors.of(context).tone,
        shape: AppShape.all(AppCorner.full),
      ),
      child: Text(
        providerLatencyLabel(provider),
        maxLines: 1,
        style: AppTextStyle.caption1
            .of(context, emphasized: true)
            .copyWith(
              color: measured ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontFamily: appMonospaceFontFamily,
            ),
      ),
    );
  }
}

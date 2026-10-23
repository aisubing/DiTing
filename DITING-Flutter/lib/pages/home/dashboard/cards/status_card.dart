import 'package:diting/data/dashboard_models.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/dashboard_providers.dart';
import 'package:diting/state/primary_provider_providers.dart';
import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Status card, after FlClash widgets/current_outbound.dart. Uptime shows a dash when
/// stopped, not `0s`: not started is not the same as just started.
class StatusCard extends ConsumerWidget {
  const StatusCard({super.key, this.onDetail});

  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = ref.watch(coreStateProvider);
    final mode = ref.watch(workModeProvider);
    final stats = ref.watch(serviceStatsProvider);
    final primary = ref.watch(primaryProviderProvider);
    final scale = DashboardDensityScope.scaleOf(context);
    final colorScheme = context.colorScheme;
    final (tone, label) = switch (core) {
      CoreState.running => (DashboardChipTone.ok, core.label),
      CoreState.starting => (DashboardChipTone.idle, core.label),
      CoreState.failed => (DashboardChipTone.warn, core.label),
      CoreState.stopped => (DashboardChipTone.idle, core.label),
    };
    return DashboardCard(
      semanticLabel: '状态',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardCardHeader(
            glyph: AppGlyphs.status,
            title: '状态',
            leading: [DashboardChip(label: label, tone: tone, dot: true)],
            trailing: [
              if (onDetail != null)
                DashboardIconButton(
                  glyph: AppGlyphs.chevronForward,
                  tooltip: '详情',
                  onPressed: onDetail,
                ),
            ],
          ),
          SizedBox(height: 12 * scale),
          Text('运行时长', style: DashboardText.label(context)),
          SizedBox(height: 2 * scale),
          Text(
            core.isRunning ? stats.uptimeLabel : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.figure(
              context,
              AppTextStyle.title1,
              color: core.isRunning ? colorScheme.onSurface : null,
            ),
          ),
          SizedBox(height: 14 * scale),
          Row(
            spacing: 16,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _StatusCell(
                  label: '当前服务商',
                  value: primary?.name ?? '未选择',
                  hint: primary?.address,
                ),
              ),
              Expanded(
                flex: 2,
                child: _StatusCell(
                  label: '今日查询',
                  value: dashboardCount(stats.queries),
                  hint: mode.title,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.label, required this.value, this.hint});

  final String label;
  final String value;

  /// Sub-line under the main value; omitted entirely when null.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.label(context),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.figure(context, AppTextStyle.subheadline),
        ),
        if (hint != null && hint.isNotEmpty)
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardText.label(context),
          ),
      ],
    );
  }
}
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

/// Status card, after FlClash widgets/current_outbound.dart. Uptime shows a placeholder rule
/// when stopped, not `0s`: not started is not the same as just started.
class StatusCard extends ConsumerWidget {
  const StatusCard({super.key, this.onDetail});

  final VoidCallback? onDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = ref.watch(coreStateProvider);
    final mode = ref.watch(workModeProvider);
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
          if (core.isRunning)
            // Stats poll every second; only the figures showing them rebuild.
            Consumer(
              builder: (context, ref, _) => Text(
                ref.watch(serviceStatsProvider.select((s) => s.uptimeLabel)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DashboardText.figure(
                  context,
                  AppTextStyle.title1,
                  color: colorScheme.onSurface,
                ),
              ),
            )
          else
            _UptimePlaceholder(scale: scale),
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
                child: Consumer(
                  builder: (context, ref, _) => _StatusCell(
                    label: '今日查询',
                    value: dashboardCount(
                      ref.watch(serviceStatsProvider.select((s) => s.queries)),
                    ),
                    hint: mode.title,
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

/// Stand-in for the uptime figure while stopped. An em dash fell to the font's baseline and
/// left a stray speck in the middle of a 28pt line; a rounded rule sized to the same line box
/// reads as "no value yet" and keeps the card's rhythm when the tunnel starts.
class _UptimePlaceholder extends StatelessWidget {
  const _UptimePlaceholder({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return SizedBox(
      height: AppTextStyle.title1.leading * scale,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 44 * scale,
          height: 5 * scale,
          decoration: BoxDecoration(
            // Same tone as the chart tracks, so the card stays one family.
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(3 * scale),
          ),
        ),
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

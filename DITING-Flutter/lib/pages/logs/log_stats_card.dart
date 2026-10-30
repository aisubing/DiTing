import 'package:diting/app/l10n/l10n.dart';
import 'package:diting/pages/home/dashboard/cards/dashboard_block_parts.dart';
import 'package:diting/pages/home/dashboard/dashboard_card.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/state/log_stats_providers.dart';
import 'package:diting/state/traffic_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Statistics card: request counts and data usage, each over its own window, with a
/// proportional bar under each row of figures and a shortcut to the request log between them.
class LogStatsCard extends StatelessWidget {
  const LogStatsCard({super.key, this.onRecentActivity});

  /// Opens the request log; null (edit mode) leaves the row inert.
  final VoidCallback? onRecentActivity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = context.colorScheme;
    return DashboardCard(
      semanticLabel: l10n.logStatsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          GlyphIcon(AppGlyphs.dataUsage, size: 36, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            l10n.logStatsTitle,
            textAlign: TextAlign.center,
            style: AppTextStyle.title3.of(context, emphasized: true),
          ),
          const SizedBox(height: 20),
          const _RequestsSection(),
          const SizedBox(height: 8),
          _RecentActivityRow(onTap: onRecentActivity),
          const SizedBox(height: 8),
          const _DataSection(),
        ],
      ),
    );
  }
}

class _RequestsSection extends ConsumerWidget {
  const _RequestsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = context.colorScheme;
    final window = ref.watch(logStatsWindowProvider(LogStatsSection.requests));
    final stats = ref.watch(logStatsRequestsProvider(window)).value;
    final rest = colorScheme.onSurfaceVariant;
    String figure(int? value) => value == null ? '—' : dashboardCount(value);
    return _Section(
      title: l10n.logStatsRequests,
      section: LogStatsSection.requests,
      cells: [
        (
          value: figure(stats?.blocked),
          label: l10n.logBlocked,
          color: colorScheme.error,
        ),
        (
          value: figure(stats?.cached),
          label: l10n.logCacheHits,
          color: colorScheme.tertiary,
        ),
        (
          value: figure(stats?.total),
          label: l10n.logStatsTotal,
          color: colorScheme.onSurface,
        ),
      ],
      label: rest,
      segments: stats == null
          ? const []
          : [
              (value: stats.blocked, color: colorScheme.error),
              (value: stats.cached, color: colorScheme.tertiary),
              (
                value: stats.total - stats.blocked - stats.cached,
                color: rest.withValues(alpha: 0.6),
              ),
            ],
    );
  }
}

class _DataSection extends ConsumerWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = context.colorScheme;
    final window = ref.watch(logStatsWindowProvider(LogStatsSection.data));
    final stats = ref.watch(logStatsDataProvider(window)).value;
    final rest = colorScheme.onSurfaceVariant;
    String figure(int? value) =>
        value == null ? '—' : dashboardBinaryBytes(value);
    return _Section(
      title: l10n.logStatsData,
      section: LogStatsSection.data,
      cells: [
        (
          value: figure(stats?.saved),
          label: l10n.logStatsSaved,
          color: colorScheme.success,
        ),
        (
          value: figure(stats?.uploaded),
          label: l10n.logStatsUploaded,
          color: colorScheme.primary,
        ),
        (
          value: figure(stats?.downloaded),
          label: l10n.logStatsDownloaded,
          color: colorScheme.onSurface,
        ),
      ],
      label: rest,
      segments: stats == null
          ? const []
          : [
              (value: stats.saved, color: colorScheme.success),
              (value: stats.uploaded, color: colorScheme.primary),
              (value: stats.downloaded, color: rest.withValues(alpha: 0.6)),
            ],
    );
  }
}

typedef _Cell = ({String value, String label, Color color});
typedef _Segment = ({int value, Color color});

/// Section title with its window picker, three centered figures, and the proportion bar.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.section,
    required this.cells,
    required this.label,
    required this.segments,
  });

  final String title;
  final LogStatsSection section;
  final List<_Cell> cells;

  /// Label color of the neutral (last) cell, which shows its figure in the text color.
  final Color label;
  final List<_Segment> segments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.headline.of(context),
              ),
            ),
            _WindowPicker(section: section),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, cell) in cells.indexed)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        cell.value,
                        maxLines: 1,
                        style: DashboardText.figure(
                          context,
                          AppTextStyle.title2,
                          color: cell.color,
                        ),
                      ),
                    ),
                    Text(
                      cell.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: DashboardText.label(
                        context,
                        color: index == cells.length - 1 ? label : cell.color,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _ProportionBar(segments: segments),
      ],
    );
  }
}

/// Rounded segments sized by share, separated by gaps. A non-zero share keeps a minimum width
/// so a single blocked request still shows; an all-zero bar draws the bare track.
class _ProportionBar extends StatelessWidget {
  const _ProportionBar({required this.segments});

  static const _height = 6.0;
  static const _gap = 6.0;
  static const _minShare = 0.04;

  final List<_Segment> segments;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final segment in segments)
        if (segment.value > 0) segment,
    ];
    final total = shown.fold(0, (sum, segment) => sum + segment.value);
    const shape = StadiumBorder();
    if (total == 0) {
      return Container(
        height: _height,
        decoration: ShapeDecoration(
          color: DashboardColors.of(context).track,
          shape: shape,
        ),
      );
    }
    return SizedBox(
      height: _height,
      child: Row(
        spacing: _gap,
        children: [
          for (final segment in shown)
            Expanded(
              flex: (1000 * (segment.value / total).clamp(_minShare, 1.0))
                  .round(),
              child: DecoratedBox(
                decoration: ShapeDecoration(color: segment.color, shape: shape),
              ),
            ),
        ],
      ),
    );
  }
}

class _WindowPicker extends ConsumerWidget {
  const _WindowPicker({required this.section});

  final LogStatsSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = logStatsWindowProvider(section);
    final window = ref.watch(provider);
    final color = context.colorScheme.onSurfaceVariant;
    String labelOf(TrafficWindow value) =>
        value == TrafficWindow.all ? l10n.trafficAllHistory : value.label(l10n);
    return CommonPopupBox(
      targetBuilder: (open) => Semantics(
        button: true,
        label: l10n.logStatsWindow,
        child: InkWell(
          customBorder: AppShape.all(AppCorner.sm),
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Text(
                  labelOf(window),
                  style: AppTextStyle.subheadline
                      .of(context)
                      .copyWith(color: color),
                ),
                GlyphIcon(AppGlyphs.chevronDown, size: 16, color: color),
              ],
            ),
          ),
        ),
      ),
      popupBuilder: (_) => CommonPopupMenu(
        items: [
          for (final value in TrafficWindow.values)
            CommonPopupMenuItem(
              label: labelOf(value),
              checked: value == window,
              onPressed: () => ref.read(provider.notifier).select(value),
            ),
        ],
      ),
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  const _RecentActivityRow({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return InkWell(
      customBorder: AppShape.all(AppCorner.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          spacing: 14,
          children: [
            GlyphIcon(
              AppGlyphs.textShort,
              size: 22,
              color: colorScheme.primary,
            ),
            Expanded(
              child: Text(
                context.l10n.logStatsRecentActivity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.body.of(context),
              ),
            ),
            GlyphIcon(
              AppGlyphs.chevronForward,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

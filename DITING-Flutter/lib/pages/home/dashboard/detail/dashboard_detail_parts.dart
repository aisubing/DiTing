import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:material_ui/material_ui.dart';

/// Shared frame of a home card's second-level page: same scaffold, body and spacing as the log
/// drill-downs, so a detail page never looks like a different app section.
class DashboardDetailScaffold extends StatelessWidget {
  const DashboardDetailScaffold({
    super.key,
    required this.title,
    this.actions = const [],
    required this.children,
  });

  final String title;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      title: title,
      actions: actions.isEmpty ? null : actions,
      body: PageBody(children: children),
    );
  }
}

/// Large headline figure for the one number the card could only hint at.
class DashboardDetailFigure extends StatelessWidget {
  const DashboardDetailFigure({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.hint,
    this.color,
  });

  final String label;
  final String value;
  final String? unit;
  final String? hint;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final hint = this.hint;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(
            label,
            style: AppTextStyle.caption1.of(context).copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: DashboardText.figure(
                    context,
                    AppTextStyle.title1,
                    color: color ?? colorScheme.onSurface,
                  ),
                ),
                if (unit case final unit?)
                  TextSpan(
                    text: '  $unit',
                    style: DashboardText.unit(context, AppTextStyle.footnote),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (hint != null && hint.isNotEmpty)
            Text(
              hint,
              style: AppTextStyle.caption1.of(context).copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Stat strip inside a card, padded like every other stats page.
class DashboardDetailStats extends StatelessWidget {
  const DashboardDetailStats({super.key, required this.stats});

  final List<StatItem> stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CommonCard(
        padding: EdgeInsets.zero,
        child: StatStrip(stats: stats),
      ),
    );
  }
}

/// Composition bar for one total split into parts; a zero total draws the track only, so the
/// widget never divides by zero.
class DashboardShareBar extends StatelessWidget {
  const DashboardShareBar({super.key, required this.segments, this.height = 12});

  /// Parts of the whole; values are weights, not percentages.
  final List<({double value, Color color})> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (sum, part) => sum + part.value);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: total <= 0
            ? ColoredBox(color: DashboardColors.of(context).track)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final part in segments)
                    if (part.value > 0)
                      Expanded(
                        // Per-mille flex: a 0.3% sliver must stay a sliver, not round up to
                        // a visible block.
                        flex: (part.value * 1000 / total)
                            .round()
                            .clamp(1, 1000),
                        child: ColoredBox(color: part.color),
                      ),
                ],
              ),
      ),
    );
  }
}

/// Legend line under a [DashboardShareBar]: dot, label and the value with its share.
class DashboardShareLegend extends StatelessWidget {
  const DashboardShareLegend({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.share,
  });

  final String label;
  final String value;
  final Color color;

  /// 0..1 share of the whole; omitted when it makes no sense (device free memory).
  final double? share;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final share = this.share;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        spacing: 8,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: ShapeDecoration(color: color, shape: AppShape.circle),
          ),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.subheadline.of(context),
            ),
          ),
          Text(
            share == null ? value : '$value · ${(share * 100).round()}%',
            maxLines: 1,
            style: AppTextStyle.subheadline.of(
              context,
              emphasized: true,
            ).copyWith(color: colorScheme.onSurface, fontFamily: 'JetBrainsMono'),
          ),
        ],
      ),
    );
  }
}

/// Small helper page section for a "no data yet" state.
class DashboardDetailEmpty extends StatelessWidget {
  const DashboardDetailEmpty({super.key, required this.label, this.description});

  final String label;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        spacing: 6,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyle.subheadline.of(context, emphasized: true),
          ),
          if (description case final description?)
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTextStyle.caption1.of(
                context,
              ).copyWith(color: colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/routes/routes.dart';
import 'package:diting/ui/ui.dart';
import 'package:diting/widgets/stat_strip.dart';
import 'package:go_router/go_router.dart';
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
      // Always show the back button. Relying on the route to imply it leaves the bar without
      // one whenever the page is reached by a deep link or `go`, where nothing is left to pop.
      backAction: () => _back(context),
      actions: actions.isEmpty ? null : actions,
      body: PageBody(
        // A wider top gap: every page starts with a card, and a card flush against the toolbar
        // reads as part of the chrome.
        padding: const EdgeInsets.only(top: 4),
        children: children,
      ),
    );
  }

  /// Pop when this page was pushed onto the board, otherwise fall back to the board itself, so a
  /// deep link still has somewhere to go back to.
  static void _back(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
      return;
    }
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }
    if (router != null) {
      router.go(DashboardPaths.dashboard);
    }
  }
}

/// Card shared by every detail section: tone fill, dashboard radius and the same elevation as the
/// home cards, so a second-level page keeps the board's visual language instead of falling back to
/// the flat list style of the deeper pages.
class DashboardDetailCard extends StatelessWidget {
  const DashboardDetailCard({
    super.key,
    this.glyph,
    this.title,
    this.trailing = const [],
    this.footer,
    this.semanticLabel,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 16),
    required this.child,
  });

  final Glyph? glyph;
  final String? title;
  final List<Widget> trailing;
  final String? footer;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = AppShape.all(DashboardCorner.mobileBlock);
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title case final title?) ...[
            _Header(glyph: glyph, title: title, trailing: trailing),
            const SizedBox(height: 14),
          ],
          child,
          if (footer case final footer?) ...[
            const SizedBox(height: 12),
            Text(footer, style: _caption(context)),
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Semantics(
        container: true,
        label: semanticLabel,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: DashboardColors.of(context).card,
            shape: shape,
            shadows: DashboardShadows.e1(context),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: onTap == null
                ? content
                : InkWell(
                    customBorder: shape,
                    onTap: onTap,
                    child: content,
                  ),
          ),
        ),
      ),
    );
  }

  static TextStyle _caption(BuildContext context) => AppTextStyle.caption1
      .of(context)
      .copyWith(color: context.colorScheme.onSurfaceVariant);
}

class _Header extends StatelessWidget {
  const _Header({this.glyph, required this.title, required this.trailing});

  final Glyph? glyph;
  final String title;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Row(
      spacing: 8,
      children: [
        if (glyph case final glyph?)
          GlyphIcon(glyph, size: 18, color: colorScheme.onSurfaceVariant),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.subheadline.of(context, emphasized: true),
          ),
        ),
        ...trailing,
      ],
    );
  }
}

/// Headline block: the one number the card could only hint at, with its label, an optional status
/// pill and a one-line hint. Replaces a bare floating figure, which read as unanchored text.
class DashboardDetailHero extends StatelessWidget {
  const DashboardDetailHero({
    super.key,
    required this.glyph,
    required this.label,
    required this.value,
    this.unit,
    this.hint,
    this.color,
    this.chipLabel,
    this.chipColor,
    this.monospace = false,
  });

  final Glyph glyph;
  final String label;
  final String value;
  final String? unit;
  final String? hint;
  final Color? color;

  /// Small pill next to the value, e.g. the core state or the sample count.
  final String? chipLabel;
  final Color? chipColor;

  /// Addresses and other machine text read better in a monospaced face.
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final colors = DashboardColors.of(context);
    final accent = color ?? colorScheme.primary;
    final hint = this.hint;
    final figure = color ?? colorScheme.onSurface;
    return DashboardDetailCard(
      semanticLabel: '$label $value',
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 14,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: ShapeDecoration(
                  color: colors.tone,
                  shape: AppShape.all(AppCorner.md),
                ),
                child: Center(
                  child: GlyphIcon(glyph, size: 22, color: accent),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _captionStyle(context),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: value,
                            style: DashboardText.figure(
                              context,
                              AppTextStyle.title1,
                              color: figure,
                            ).copyWith(
                              fontFamily: monospace ? appMonospaceFontFamily : null,
                            ),
                          ),
                          if (unit case final unit?)
                            TextSpan(
                              text: '  $unit',
                              style: DashboardText.unit(
                                context,
                                AppTextStyle.footnote,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (chipLabel case final chipLabel?)
                _StatusPill(
                  label: chipLabel,
                  color: chipColor ?? colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          if (hint != null && hint.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(hint, style: _captionStyle(context)),
          ],
        ],
      ),
    );
  }

  static TextStyle _captionStyle(BuildContext context) => AppTextStyle.caption1
      .of(context)
      .copyWith(color: context.colorScheme.onSurfaceVariant);
}

/// Rounded status pill used by the hero and the section headers.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.12),
        shape: AppShape.all(AppCorner.full),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyle.caption1
            .of(context, emphasized: true)
            .copyWith(color: color),
      ),
    );
  }
}

/// Metric tiles in a two-column grid, framed as its own card.
///
/// A single `StatStrip` row of four cells gave each value a quarter of the phone width, so
/// `73.46 MB` was cut to `73.46 …`. Two columns always fit a binary byte figure, and the tile
/// shrinks a still-too-long value instead of ellipsizing it.
class DashboardDetailStats extends StatelessWidget {
  const DashboardDetailStats({
    super.key,
    required this.stats,
    this.columns = 2,
  });

  final List<StatItem> stats;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return DashboardDetailCard(
      padding: const EdgeInsets.all(10),
      child: DashboardStatGrid(stats: stats, columns: columns),
    );
  }
}

/// The tile grid itself, for pages that already own a card.
class DashboardStatGrid extends StatelessWidget {
  const DashboardStatGrid({
    super.key,
    required this.stats,
    this.columns = 2,
  });

  final List<StatItem> stats;
  final int columns;

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - _gap * (columns - 1)) / columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final stat in stats)
              SizedBox(width: width, child: _MetricTile(item: stat)),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.item});

  final StatItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final valueColor = item.color ?? colorScheme.onSurface;
    final unit = item.unit;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: ShapeDecoration(
        color: DashboardColors.of(context).tone,
        shape: AppShape.all(AppCorner.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    item.value,
                    maxLines: 1,
                    style: DashboardText.figure(
                      context,
                      AppTextStyle.headline,
                      color: valueColor,
                    ),
                  ),
                ),
              ),
              if (unit != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 3),
                  child: Text(
                    unit,
                    style: AppTextStyle.caption1.of(context).copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// One read-only `label: value` row inside a [DashboardDetailCard].
class DashboardDetailRow {
  const DashboardDetailRow({
    required this.label,
    required this.value,
    this.monospace = false,
    this.color,
  });

  final String label;
  final String value;

  /// Monospace for addresses, ports and package names.
  final bool monospace;

  /// Value colour for a state that needs to stand out (ok / error).
  final Color? color;
}

/// Rows with hairline separators; values wrap instead of truncating, so a long IPv6 address or a
/// DNS reply stays readable.
class DashboardDetailRows extends StatelessWidget {
  const DashboardDetailRows({super.key, required this.rows});

  final List<DashboardDetailRow> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final divider = colorScheme.onSurface.withValues(alpha: 0.08);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) Container(height: 1, color: divider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                Text(
                  row.label,
                  style: AppTextStyle.subheadline.of(
                    context,
                  ).copyWith(color: colorScheme.onSurfaceVariant),
                ),
                Expanded(
                  child: Text(
                    row.value,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.subheadline.of(context).copyWith(
                      color: row.color ?? colorScheme.onSurface,
                      fontFamily: row.monospace ? appMonospaceFontFamily : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Page-bottom note: the standing explanation of where the numbers come from.
class DashboardDetailNote extends StatelessWidget {
  const DashboardDetailNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Text(
        text,
        style: AppTextStyle.caption1
            .of(context)
            .copyWith(color: context.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

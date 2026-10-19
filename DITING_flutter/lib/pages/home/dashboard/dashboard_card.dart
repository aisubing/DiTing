import 'package:diting/pages/home/dashboard/dashboard_density.dart';
import 'package:diting/pages/home/dashboard/dashboard_style.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 仪表盘卡片。
///
/// 上游 `views/dashboard/widgets/card.dart:32-85`。比 [CommonCard] 多两件事：
/// 阴影分级（e1/e2）与桌面/移动两档圆角。之所以不直接复用 [CommonCard]，
/// 是因为列表卡的圆角在 16–20，而仪表盘卡要到 32+，混用会让两者贴在一起时
/// 圆角不协调。
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    this.padding,
    this.onTap,
    this.semanticLabel,
    this.clipBehavior = Clip.none,
    required this.child,
  });

  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// 默认不裁剪：按下时控件要能稍微胀出卡片边缘；只有内容自己会溢出的卡片
  /// （图表）才显式裁。
  final Clip clipBehavior;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    final shape = AppShape.all(dashboardCardRadius(density));
    final content = Padding(
      padding: padding ?? dashboardCardPadding(density),
      child: child,
    );
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        clipBehavior: clipBehavior,
        decoration: ShapeDecoration(
          color: DashboardColors.of(context).card,
          shape: shape,
          shadows: DashboardShadows.e1(context),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: onTap == null
              ? content
              : FocusRing(
                  shape: shape,
                  child: InkWell(
                    customBorder: shape,
                    onTap: onTap,
                    child: content,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 卡片标题行：图标 + 标题 + 右侧动作。
///
/// 高 24 是设计定值（`card.dart:97`）：再高会让卡片顶部留白失衡。
class DashboardCardHeader extends StatelessWidget {
  const DashboardCardHeader({
    super.key,
    this.glyph,
    required this.title,
    this.leading = const [],
    this.trailing = const [],
    this.chevron = false,
  });

  static const height = 24.0;
  static const glyphSize = 18.0;

  final Glyph? glyph;
  final String title;

  /// 紧跟标题之后、把 [trailing] 推到右端之前的空间里。
  final List<Widget> leading;
  final List<Widget> trailing;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final mobile = !DashboardDensityScope.of(context).isDesktop;
    final colorScheme = context.colorScheme;
    final style = mobile
        ? DashboardText.mobileCardTitle(context)
        : DashboardText.cardTitle(context);
    return SizedBox(
      height: height,
      child: Row(
        spacing: 8,
        children: [
          if (glyph case final glyph?)
            GlyphIcon(
              glyph,
              size: glyphSize,
              color: colorScheme.onSurfaceVariant,
            ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          ...leading,
          const Spacer(),
          ...trailing,
          if (chevron)
            GlyphIcon(
              AppGlyphs.chevronForward,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

/// 卡片内部的小块（比卡片底色深一层）。
class DashboardBlock extends StatelessWidget {
  const DashboardBlock({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final density = DashboardDensityScope.of(context);
    return Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: color ?? DashboardColors.of(context).tone,
        shape: AppShape.all(
          density.isDesktop ? DashboardCorner.block : DashboardCorner.mobileBlock,
        ),
      ),
      child: child,
    );
  }
}

enum DashboardChipTone { idle, ok, warn }

/// 状态徽标。
///
/// [dot] 打一个前置圆点（在线状态），[large] 用于标题旁的主徽标。
class DashboardChip extends StatelessWidget {
  const DashboardChip({
    super.key,
    required this.label,
    this.tone = DashboardChipTone.idle,
    this.dot = false,
    this.large = false,
  });

  final String label;
  final DashboardChipTone tone;
  final bool dot;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final colors = DashboardColors.of(context);
    final (foreground, background) = switch (tone) {
      DashboardChipTone.idle => (
        colorScheme.onSurfaceVariant,
        colors.tone,
      ),
      DashboardChipTone.ok => (colorScheme.success, colors.tone),
      DashboardChipTone.warn => (colorScheme.warning, colors.tone),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 10 : 8,
        vertical: large ? 5 : 3,
      ),
      decoration: ShapeDecoration(
        color: background,
        shape: AppShape.all(AppCorner.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          if (dot)
            Container(
              width: 6,
              height: 6,
              decoration: ShapeDecoration(
                color: foreground,
                shape: const CircleBorder(),
              ),
            ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (large
                    ? AppTextStyle.footnote
                    : AppTextStyle.caption1)
                .of(context, emphasized: true)
                .toTabular
                .copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// 一行「标签 : 数值」，卡片内部用。
///
/// 两个 `Text` 都带 `ellipsis` 且外层不设固定宽：320 宽的一行三格时，每格只有
/// 约 90dp，「1.2 GB」这类值会被省略而不是撑破父级 `Row`。
class DashboardMetric extends StatelessWidget {
  const DashboardMetric({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.figure(
            context,
            AppTextStyle.headline,
            color: color,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DashboardText.label(context),
        ),
      ],
    );
  }
}

/// 卡片右上角的圆形图标按钮。
///
/// 24 高的标题行会把默认尺寸的圆钮挤成胶囊，因此这里显式溢出对齐。
class DashboardIconButton extends StatelessWidget {
  const DashboardIconButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    this.onPressed,
    this.size = 32,
    this.glyphSize = 18,
  });

  final Glyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: OverflowBox(
        minHeight: size,
        maxHeight: size,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          iconSize: glyphSize,
          style: IconButton.styleFrom(
            minimumSize: Size.square(size),
            fixedSize: Size.square(size),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: context.colorScheme.onSurfaceVariant,
          ),
          onPressed: onPressed,
          icon: GlyphIcon(glyph, size: glyphSize),
        ),
      ),
    );
  }
}

/// M3 Expressive 连接按钮组：两端圆、内侧锐，选中项胀成整颗胶囊。
///
/// 上游 `dashboard/widgets/card.dart:270-347` 用自定义 RenderFlex 把按下的那颗
/// 抬高到同级之上绘制，避免被相邻项压住。这里用普通 `Row`：本仓所有卡片都
/// 不裁剪（`DashboardCard` 默认 `Clip.none`），膨胀只会溢出到卡片外，不会
/// 被兄弟遮挡，因此不需要那层自定义渲染对象——少一个易碎点。
class DashboardConnectedGroup extends StatelessWidget {
  const DashboardConnectedGroup({
    super.key,
    required this.children,
    this.spacing = 0,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<Widget> children;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: crossAxisAlignment,
      spacing: spacing,
      children: children,
    );
  }
}

/// 连接按钮组中的一颗。
class DashboardConnectedButton extends StatelessWidget {
  const DashboardConnectedButton({
    super.key,
    required this.selected,
    required this.first,
    required this.last,
    required this.outer,
    required this.inner,
    required this.background,
    required this.onTap,
    required this.semanticLabel,
    required this.builder,
  });

  final bool selected;
  final bool first;
  final bool last;
  final double outer;
  final double inner;
  final Color background;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget Function(Color foreground) builder;

  static const _selectDuration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final startRest = first ? outer : inner;
    final endRest = last ? outer : inner;
    final colorScheme = context.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: ElasticPress(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: selected ? 1 : 0, end: selected ? 1 : 0),
          duration: _selectDuration,
          curve: Curves.easeOutCubic,
          builder: (context, amount, child) {
            final start = startRest + (outer - startRest) * amount;
            final end = endRest + (outer - endRest) * amount;
            final shape = AppShape.of(
              BorderRadius.horizontal(
                left: Radius.circular(rtl ? end : start),
                right: Radius.circular(rtl ? start : end),
              ),
            );
            return FocusRing(
              shape: shape,
              standsOff: selected,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: Color.lerp(background, colorScheme.primary, amount),
                  shape: shape,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    customBorder: shape,
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                    onTap: onTap,
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: builder(
            selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 分段式横向切换条（出站模式这类 2–3 项等宽选择）。
class DashboardSegmentedControl<T> extends StatelessWidget {
  const DashboardSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.outer = 26,
    this.inner = 12,
    this.height = 52,
  });

  final List<(T value, Glyph glyph, String label)> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final double outer;
  final double inner;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tone = DashboardColors.of(context).tone;
    final style = AppTextStyle.footnote.of(context, emphasized: true);
    final scale = DashboardDensityScope.scaleOf(context);
    return DashboardConnectedGroup(
      children: [
        for (final (index, segment) in segments.indexed)
          Expanded(
            child: DashboardConnectedButton(
              selected: segment.$1 == value,
              first: index == 0,
              last: index == segments.length - 1,
              outer: outer,
              inner: inner,
              background: tone,
              semanticLabel: segment.$3,
              onTap: () => onChanged(segment.$1),
              builder: (foreground) => SizedBox(
                height: height * scale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 2,
                  children: [
                    GlyphIcon(segment.$2, size: 18, color: foreground),
                    Text(
                      segment.$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

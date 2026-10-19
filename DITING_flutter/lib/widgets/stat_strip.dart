import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 页面通用的「统计带」：一行 N 个数字 + 标签，等宽分栏。
///
/// 黑名单统计卡、日志概览、服务器统计、流量汇总都用它，保证同一类信息在
/// 不同页面长得一样——这正是设计系统要解决的问题，不该每页各写一遍。
class StatStrip extends StatelessWidget {
  const StatStrip({
    super.key,
    required this.stats,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.separator = true,
  });

  final List<StatItem> stats;
  final EdgeInsets padding;

  /// 相邻两栏之间是否画竖线。
  final bool separator;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          for (final (index, stat) in stats.indexed) ...[
            if (index > 0 && separator)
              Container(
                width: 1,
                height: 28,
                color: colorScheme.onSurface.withValues(alpha: 0.12),
              ),
            Expanded(child: _StatCell(item: stat)),
          ],
        ],
      ),
    );
  }
}

/// 一栏统计。
class StatItem {
  const StatItem({
    required this.label,
    required this.value,
    this.unit,
    this.color,
  });

  final String label;
  final String value;
  final String? unit;

  /// 非空时数值用该颜色（如拦截数用 error、命中率用 success）。
  final Color? color;
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.item});

  final StatItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final valueColor = item.color ?? colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                item.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.title3
                    .of(context, emphasized: true)
                    .copyWith(color: valueColor),
              ),
            ),
            if (item.unit case final unit?)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  unit,
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyle.caption1
              .of(context)
              .copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// 键值行（`label: value`），用于「当前上游」「监听端口」这类只读信息。
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;

  /// 地址、端口、包名这类内容用等宽字体，位数对齐才看得清。
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTextStyle.subheadline
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyle.subheadline
                  .of(context)
                  .copyWith(
                    color: colorScheme.onSurface,
                    fontFamily: monospace ? 'JetBrainsMono' : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行小标题 + 内容的分组容器，页面正文里反复出现。
///
/// 横向留白只加在 [child]（卡片）上，不加在整列上：`ListHeader`/`ListFooter`
/// 自带 16 的横向内边距，外层再套一次会让这一组的标题比别组缩进 32。
class SectionBlock extends StatelessWidget {
  const SectionBlock({
    super.key,
    this.title,
    required this.child,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  final String? title;
  final Widget child;
  final String? footer;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          if (title case final title?) ListHeader(title: title),
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: padding.left,
              end: padding.right,
            ),
            child: child,
          ),
          if (footer case final footer?) ListFooter(text: footer),
        ],
      ),
    );
  }
}

/// 底部留白：给浮条让位。列表页统一挂在滚动内容的末尾。
class DockSpacer extends StatelessWidget {
  const DockSpacer({super.key, this.extra = 0});

  final double extra;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: NavigationDock.insetOf(context) + extra);
  }
}

/// 可滚动的页面正文，统一带顶栏浮位、底部浮条留白与滚动条。
///
/// 顶部留白必须显式取 `context.appBarInset`：`CommonScaffold` 走
/// `extendBodyBehindAppBar`，正文从屏幕 y=0 起排，不预留就会整片画到顶栏
/// 底下（标题压行、首个分组头藏进状态栏）。占位统一走 `AppBarClearance`，
/// 它同时把 `MediaQuery.padding.top` 清零并关掉 `FloatingBarScope`，避免
/// 正文里再算一次同样的留白。
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.dockSpacer = true,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final bool dockSpacer;

  @override
  Widget build(BuildContext context) {
    return AppBarClearance(
      child: ListView(
        padding: padding,
        children: [...children, if (dockSpacer) const DockSpacer()],
      ),
    );
  }
}

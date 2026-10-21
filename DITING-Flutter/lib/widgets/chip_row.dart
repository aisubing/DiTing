import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 一行可选中的 chip：定高 32、横向滚动、间距 8。
///
/// 抽出来是因为同一语义此前有两种写法，看起来像两个组件：
///
/// * `SizedBox(height: 32)` + 横向 `ListView`（规则页、订阅页）；
/// * `Wrap`（流量页、日志统计三页）。
///
/// `Wrap` 那一版在真机上是 18dp 高——`TonalChip` 的高度由 `_CapCentered` 按
/// 文本行高定，`Wrap` 不给交叉轴约束，它就停在 18；`ListView` 的每项被视口
/// 拉满 32，才有胶囊该有的高度。两种写法还带来另一个分歧：`Wrap` 放不下时会
/// 换行，一行 chip 变成两行，把下面的计数头推到更远处；横向 `ListView` 只是
/// 可以滑动，行高恒定。因此统一成后者（也是白名单/黑名单页那套 UI）。
///
/// **横向内边距由调用方给**，与 `ListHeader`/`ListFooter` 的 16 同源。组件自己
/// 再加一层就变成 32，`ListHeader` 的标题于是比 chip 左移 16——订阅拦截率页
/// 量到 `title x=16 / chip x=32` 就是这个原因。
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children, this.gap = 8});

  final List<Widget> children;

  /// 相邻两颗 chip 之间的空隙。
  final double gap;

  /// 胶囊高度。`TonalChip` 自己没有定高，靠这一层给。
  static const height = 32.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // 视口从 0 起，横向留白交给调用方，滚动时 chip 才能滑到屏幕边沿。
        padding: EdgeInsets.zero,
        itemCount: children.length,
        separatorBuilder: (_, _) => SizedBox(width: gap),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

/// 一颗选中/未选中的筛选 chip。
///
/// 把「选中用什么色、未选中用什么色、禁用档怎么画」这三件事收在一处：此前
/// 流量页的 `_OptionChip`、日志三页的 `LogStatsRangeSelector`、规则页的
/// `_SourceChips`、订阅页的 `_GroupChips` 各写了一遍同样的三元表达式，
/// 改一处配色要改四处。
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.disabled = false,
  });

  final String label;
  final bool selected;

  /// `null` 表示当前档已是选中态、无需再点（仍会画出选中色）。
  final VoidCallback? onPressed;

  /// 禁用档：保留点击手势（点了要能解释为什么不可用），但文字变淡。
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final foreground = disabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
        : selected
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;
    return TonalChip(
      label: label,
      color: selected
          ? colorScheme.primary
          : context.raisedSurfaceLevel.colorOf(colorScheme),
      foregroundColor: foreground,
      onPressed: onPressed,
    );
  }
}

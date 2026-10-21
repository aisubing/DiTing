import 'package:material_ui/material_ui.dart';

/// 给 `NullStatus` 一个**最小**高度，而不是固定高度。
///
/// 空状态此前一律写成 `SizedBox(height: 260/280/300/320, child: NullStatus(...))`。
/// `NullStatus` 内部是 `Align + SingleChildScrollView`：固定高度下内容比视口高
/// 时它不报 overflow，而是安静地把下半截裁掉——真机上量到订阅页的「添加订阅」
/// 按钮排在 `top=539`，而空状态框到 `531` 就结束了，按钮只剩一条蓝边，紧接着的
/// `ListFooter` 说明反而压在按钮原本的位置上。禁止联网应用页更糟：被裁掉的错误
/// 描述与「保存」按钮叠在一起。
///
/// 症状的共同点是**内容长度由数据决定**（错误串、包名、订阅名），固定高度必然
/// 有一天不够。这里只给下限：内容少时与原来的居中观感一致；内容多时空状态长高、
/// 整页滚动，而不是切掉用户的按钮。
///
/// 放在 `ListView` 里时父级高度无界，`NullStatus` 会按内容自然高度排布，内部的
/// `SingleChildScrollView` 因而不介入——滚动交给外层页面，这正是要的效果。
class EmptyStateBox extends StatelessWidget {
  const EmptyStateBox({super.key, required this.child, this.minHeight = 240});

  final Widget child;

  /// 内容再少也占这么高，避免空状态在高屏上缩成一小团。
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: child,
    );
  }
}

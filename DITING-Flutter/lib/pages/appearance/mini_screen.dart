/// 迷你界面草图：把首页画成拇指大小的一块屏，用来给外观选项做预览。
///
/// 上游 `views/theme_preview.dart` 用 `CustomPainter` 在 96×128 的画布上重画
/// 一遍界面，本文件按同样的思路实现，但只保留「一眼能分辨差异」的元素：
/// 页面底色、内容块、底栏形态与 tab 切换动画。像素级还原没有意义，缩略图
/// 只回答一个问题：这个开关打开后，屏幕看起来变成了什么样。
///
/// 绘制逻辑在 `mini_screen_painter.dart`（part 文件）：本文件只放控件与几何，
/// 拆开是因为两者合计超过 550 行上限，而几何被两边共用、不适合复制。
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:diting/state/appearance_extra_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

part 'mini_screen_painter.dart';

// `dart:math` / `dart:ui` 与 `AppShape` 等只在 part 文件里用到，但 part 共享
// 主体的 import 作用域，所以 import 必须留在这一侧。

/// 缩略图里循环演示的四张页面。
enum MiniPage { dashboard, rules, logs, tools }

/// 一块缩小版界面。
///
/// [previous] 非空时，画面停在从 `previous` 切到 [selected] 的 [progress] 处，
/// 切换方式由 [transition] 决定——这正是 tab 动画缩略图要展示的内容。
class MiniScreen extends StatelessWidget {
  const MiniScreen({
    super.key,
    required this.colorScheme,
    required this.floatingBar,
    this.liquidGlass = false,
    this.selected = 0,
    this.previous,
    this.progress = 1,
    this.transition = TabTransition.slide,
    this.onSelect,
  });

  /// 底栏可点的 tab 数。缩略图里四项就够，再多每项只剩几个像素。
  static const int destinationCount = 4;

  final ColorScheme colorScheme;
  final bool floatingBar;

  /// 浮条是否画成玻璃；普通底栏始终是实色（与上游一致）。
  final bool liquidGlass;

  final int selected;
  final int? previous;
  final double progress;
  final TabTransition transition;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final sketch = SizedBox.expand(
      child: CustomPaint(
        painter: _MiniScreenPainter(
          colorScheme: colorScheme,
          floatingBar: floatingBar,
          liquidGlass: liquidGlass,
          selected: selected,
          previous: previous,
          progress: progress,
          transition: transition,
        ),
      ),
    );
    final onSelect = this.onSelect;
    if (onSelect == null) {
      return sketch;
    }
    return LayoutBuilder(
      builder: (_, constraints) {
        final geometry = _MiniGeometry(
          constraints.biggest,
          floatingBar: floatingBar,
        );
        return Stack(
          children: [
            sketch,
            Positioned.fromRect(
              rect: geometry.bar,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < destinationCount; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 把缩略图裁成手机形状；比例与上游的 9:17 一致。
///
/// 内部按固定逻辑尺寸（90×170）画一遍，再整体缩到 30dp 高：这样 `MiniScreen`
/// 里的几何（按宽度 20 等分）在任何显示尺寸下算出来的比例都一致，不用为
/// 缩略图单独调一套数值。
class MiniScreenThumb extends StatelessWidget {
  const MiniScreenThumb({super.key, required this.screen});

  static const Size _logicalSize = Size(90, 170);
  static const double _shownHeight = 30;

  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _shownHeight,
      width: _shownHeight * _logicalSize.width / _logicalSize.height,
      child: ClipRSuperellipse(
        borderRadius: AppRadius.xs,
        child: FittedBox(
          child: SizedBox(
            width: _logicalSize.width,
            height: _logicalSize.height,
            child: screen,
          ),
        ),
      ),
    );
  }
}

/// 一半浅色、一半深色的对角分割屏，用于「跟随系统」的预览。
class MiniSplitScreen extends StatelessWidget {
  const MiniSplitScreen({super.key, required this.light, required this.dark});

  final Widget light;
  final Widget dark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        light,
        ClipPath(clipper: _DiagonalClipper(), child: dark),
      ],
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * 0.7, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(size.width * 0.3, size.height)
    ..close();

  @override
  bool shouldReclip(_DiagonalClipper oldClipper) => false;
}

/// 缩略图的几何：以宽度 20 等分作单位，任何尺寸下比例一致。
class _MiniGeometry {
  _MiniGeometry(this.size, {required bool floatingBar})
    : unit = size.width / 20 {
    margin = unit * 1.5;
    final barHeight = floatingBar ? unit * 3.2 : unit * 3.6;
    pageBottom = floatingBar ? 0 : barHeight;
    bar = floatingBar
        ? Rect.fromLTWH(
            margin,
            size.height - margin - barHeight,
            size.width - margin * 2,
            barHeight,
          )
        : Rect.fromLTWH(0, size.height - barHeight, size.width, barHeight);
  }

  final Size size;
  final double unit;
  late final double margin;

  /// 底栏占掉的高度；浮条不占，页面能从它下面透出来。
  late final double pageBottom;
  late final Rect bar;
}

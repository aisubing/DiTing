import 'dart:math' as math;

import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:material_ui/material_ui.dart';

/// 首页电源按钮：停止 / 启动中 / 运行 / 停止中 四态。
///
/// 上游 `PowerToggleButton.kt` 是「glow + halo + 圆钮 + 文案」四层同步 250ms
/// 变色/变尺寸；这里保留同一结构，用动画驱动，视觉层次与上游一致：运行态是
/// 主色实心、停止态是表面色描边。
///
/// **形状变化只发生在运行态**：停止时三颗都是正圆（旧版原样），启动后内圈圆钮
/// 与外面两层光晕一起长成九边饼干（`MaterialShapes.cookie9Sided`，FlClash
/// `current_outbound.dart` 的 `_StartToggle` 用的同一形状，光晕跟着内圈一起变形
/// 才不会出现「里外不同款」）。尺寸、配色、投影、图标与 250ms 时长仍是旧版那
/// 一套；只有形状走 `easeOutBack` 并随形变整体转 1/9 圈对齐圆心。
///
/// **圆钮下面不再写字**：停止态原先压一行「开启」，与圆钮里的播放三角重复表达
/// 同一件事，而且在 124dp 圆钮下那行小字既不参与点击（命中区仍是圆钮），又把
/// 按钮的视觉重心拉低——首页首屏最醒目的一块反而显得松散。状态改由
/// [Semantics.value]（无障碍朗读）与运行/停止两态的配色区分；`label` 参数保留
/// 下来喂语义，不做可见文案。
class HomePowerButton extends StatelessWidget {
  const HomePowerButton({
    super.key,
    required this.state,
    required this.onPressed,
    this.runningLabel = '停止',
    this.stoppedLabel = '开启',
    this.busyLabel = '启动中',
  });

  final PowerState state;
  final VoidCallback onPressed;
  final String runningLabel;
  final String stoppedLabel;
  final String busyLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final running = state.isRunning;
    final busy = state.isBusy;
    final label = switch (state) {
      PowerState.starting || PowerState.stopping => busyLabel,
      PowerState.running => runningLabel,
      PowerState.stopped || PowerState.error => stoppedLabel,
    };
    return Semantics(
      button: true,
      label: label,
      value: state.label,
      child: Center(
        // 圆钮本身只占 240 方框中间那一圈；去掉圆钮下方的文案后，方框高度可以
        // 收紧到 halo 的直径，否则首屏会留出一段没有内容的空白。
        child: SizedBox(
          width: 240,
          height: 176,
          child: _PowerVisual(
            running: running,
            busy: busy,
            foreground: running ? colorScheme.onPrimary : colorScheme.primary,
            onPressed: busy ? null : onPressed,
          ),
        ),
      ),
    );
  }
}

/// 三颗同心图形：外光晕 / 内光晕 / 圆钮本体。共用同一个控制器。
///
/// 尺寸与颜色按 [AnimationController.value] 线性插值（旧版 250ms 的观感不变）；
/// 形状按同一条曲线的 `easeOutBack` 版本插值，圆→饼干会先冲过头再收回，和 M3
/// Expressive 的形变一致。两条曲线同源，不会出现「颜色到了形状没到」。
class _PowerVisual extends StatefulWidget {
  const _PowerVisual({
    required this.running,
    required this.busy,
    required this.foreground,
    required this.onPressed,
  });

  final bool running;
  final bool busy;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  State<_PowerVisual> createState() => _PowerVisualState();
}

class _PowerVisualState extends State<_PowerVisual>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 250);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: widget.running ? 1 : 0,
  );
  late final Animation<double> _morph = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didUpdateWidget(_PowerVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.running != widget.running) {
      widget.running ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _lerp(double start, double end, double amount) =>
      start + (end - start) * amount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final primary = colorScheme.primary;
    final stoppedFill = colorScheme.surfaceContainerHigh;
    final runningShadow = BoxShadow(
      color: primary.withValues(alpha: 0.32),
      blurRadius: 28,
      offset: const Offset(0, 8),
    );
    final stoppedShadow = BoxShadow(
      color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 12,
      offset: const Offset(0, 8),
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final amount = _controller.value;
        final shape = _MorphBorder(_morph.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            // 外光晕：只在运行态出现，比按钮大一圈、透明度很低。
            _Halo(
              shape: shape,
              size: _lerp(148, 172, amount),
              color: primary.withValues(alpha: _lerp(0, 0.10, amount)),
            ),
            _Halo(
              shape: shape,
              size: _lerp(124, 148, amount),
              color: primary.withValues(alpha: _lerp(0.06, 0.16, amount)),
            ),
            SizedBox.square(
              dimension: _lerp(92, 100, amount),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: shape,
                  color: Color.lerp(stoppedFill, primary, amount),
                  shadows: [
                    BoxShadow.lerp(stoppedShadow, runningShadow, amount)!,
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  shape: shape,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.onPressed,
                    customBorder: shape,
                    child: Center(child: child),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.busy
          ? CommonCircleLoading(size: 42, color: widget.foreground)
          : GlyphIcon(
              widget.running ? AppGlyphs.bolt : AppGlyphs.playPause(0),
              size: 42,
              fill: 1,
              color: widget.foreground,
            ),
    );
  }
}

/// 一圈光晕：只画形状和颜色，尺寸由父级按帧给定。
class _Halo extends StatelessWidget {
  const _Halo({required this.shape, required this.size, required this.color});

  final ShapeBorder shape;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(shape: shape, color: color),
      ),
    );
  }
}

/// 圆 ↔ 九边饼干的可插值 [ShapeBorder]。
///
/// 形状本身由 [Morph] 逐条曲线插值（不是缩放或裁剪，边界不会抖），再整体转到
/// 圆心、转 1/9 圈并缩放到目标矩形。`ShapeDecoration` 与 `Material` 的裁剪都
/// 走 [getOuterPath]，所以填色、投影、水波纹会跟着同一轮廓，不会出现「色块是
/// 饼干、波纹还是圆」。
class _MorphBorder extends ShapeBorder {
  const _MorphBorder(this.progress);

  final double progress;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  ShapeBorder scale(double t) => _MorphBorder(progress);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final transform = Matrix4.translationValues(
      rect.center.dx,
      rect.center.dy,
      0,
    )
      ..rotateZ(progress * 2 * math.pi / 9)
      ..scaleByDouble(rect.width, rect.height, 1, 1)
      ..translateByDouble(-0.5, -0.5, 0, 1);
    return _morphPath(progress).transform(transform.storage);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  bool operator ==(Object other) =>
      other is _MorphBorder && other.progress == progress;

  @override
  int get hashCode => progress.hashCode;
}

/// 只建一次的形变表：`Morph` 构造时要做曲线配对，别放进每帧的绘制路径。
final _morph = Morph(MaterialShapes.circle, MaterialShapes.cookie9Sided);

Path _morphPath(double progress) => _morph.toPath(
  progress: progress,
  rotationPivotX: 0.5,
  rotationPivotY: 0.5,
);

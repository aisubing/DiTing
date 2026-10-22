import 'dart:math' as math;

import 'package:diting/state/work_mode_providers.dart';
import 'package:diting/ui/ui.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:material_ui/material_ui.dart';

const _morphDuration = Duration(milliseconds: 450);
const _stateDuration = Duration(milliseconds: 150);

/// 圆 ↔ 九边饼干形（M3 Expressive 的「正在运行」形态）。
final _startMorph = Morph(MaterialShapes.circle, MaterialShapes.cookie9Sided);

Path _morphPath(double progress) => _startMorph.toPath(
  progress: progress,
  rotationPivotX: 0.5,
  rotationPivotY: 0.5,
);

/// 形变时整颗一起转 1/9 圈，让九条边对上圆心，像 M3 加载器那样顺。
double _morphTurn(double progress) => progress * 2 * math.pi / 9;

/// 首页电源按钮：停止 / 启动中 / 运行 / 停止中 四态。
///
/// 形状取自 FlClash `widgets/current_outbound.dart` 的 `_StartToggle`：**停止态
/// 是正圆 + 播放三角，运行态长成九边饼干 + 暂停双杠**，中间用 `easeOutBack`
/// 450ms 做形变（`Morph` 逐条曲线插值，不是缩放/裁剪，边界不会抖）。运行态
/// 额外投一层主色柔光，替代原先三层同心 halo——光落在图形本身上，比同心圆更
/// 贴合按钮轮廓，也少两层随尺寸变化的容器。
///
/// 视觉只表达「能不能点」（[PowerState]、[Semantics.value]）；文案不再可见：
/// 圆钮里已经用播放/暂停两个符号说明了点击后的结果，再写一行字是重复。
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

  /// 圆钮 / 饼干形共用的方形边长：够大保证首屏命中区，又不会压住下方文案。
  static const _size = 132.0;

  @override
  Widget build(BuildContext context) {
    final busy = state.isBusy;
    // 启动中也朝「运行」形变：用户点下去看到按钮正在变成运行态，而不是原地不动。
    final active = state.isRunning || state == PowerState.starting;
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
        child: Padding(
          // 柔光要溢出按钮本体，给四周留出投影空间，避免被父级裁掉。
          padding: const EdgeInsets.all(12),
          child: _MorphToggle(
            size: _size,
            active: active,
            busy: busy,
            tooltip: label,
            onPressed: busy ? null : onPressed,
          ),
        ),
      ),
    );
  }
}

class _MorphToggle extends StatefulWidget {
  const _MorphToggle({
    required this.size,
    required this.active,
    required this.busy,
    required this.tooltip,
    required this.onPressed,
  });

  final double size;
  final bool active;
  final bool busy;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  State<_MorphToggle> createState() => _MorphToggleState();
}

class _MorphToggleState extends State<_MorphToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _morphDuration,
    value: widget.active ? 1 : 0,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );
  var _hovered = false;
  var _focused = false;

  double get _overlay => _focused
      ? 0.1
      : _hovered
      ? 0.08
      : 0;

  @override
  void didUpdateWidget(_MorphToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      widget.active ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final fill = colorScheme.primary;
    final ink = colorScheme.onPrimary;
    final stateDuration = context.motionDuration(_stateDuration);
    return Tooltip(
      message: widget.tooltip,
      child: InkResponse(
        onTap: widget.onPressed,
        onHover: (value) => setState(() => _hovered = value),
        onFocusChange: (value) => setState(() => _focused = value),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        child: ElasticPress(
          enabled: widget.onPressed != null,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: _overlay),
            duration: stateDuration,
            builder: (_, overlay, child) => AnimatedBuilder(
              animation: _progress,
              builder: (_, child) => CustomPaint(
                painter: _MorphPainter(
                  progress: _progress.value,
                  color: Color.alphaBlend(
                    ink.withValues(alpha: overlay),
                    fill,
                  ),
                  shadow: colorScheme.primary.withValues(alpha: 0.3),
                ),
                child: child,
              ),
              child: child,
            ),
            child: SizedBox.square(
              dimension: widget.size,
              child: Center(
                child: widget.busy
                    ? CommonCircleLoading(
                        size: widget.size * 0.34,
                        color: ink,
                      )
                    : TweenAnimationBuilder<double>(
                        tween: Tween(end: widget.active ? 1 : 0),
                        duration: _morphDuration,
                        curve: Curves.easeOutBack,
                        builder: (_, progress, _) => GlyphIcon(
                          AppGlyphs.playPause(progress),
                          size: widget.size * 0.34,
                          color: ink,
                          fill: 1,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 填色 + 沿轮廓的柔光；形状由 [progress] 在正圆与九边饼干之间插值得出。
class _MorphPainter extends CustomPainter {
  const _MorphPainter({
    required this.progress,
    required this.color,
    required this.shadow,
  });

  static const _shadowOffset = Offset(0, 6);
  static const _shadowBlur = 14.0;

  final double progress;
  final Color color;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _morphPath(progress);
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(_morphTurn(progress))
      ..scale(size.width, size.height)
      ..translate(-0.5, -0.5);
    if (shadow.a > 0) {
      canvas
        ..save()
        ..translate(
          _shadowOffset.dx / size.width,
          _shadowOffset.dy / size.height,
        )
        ..drawPath(
          path,
          Paint()
            ..color = shadow
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              _shadowBlur / 2 / size.width,
            ),
        )
        ..restore();
    }
    canvas
      ..drawPath(path, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_MorphPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.shadow != shadow;
}

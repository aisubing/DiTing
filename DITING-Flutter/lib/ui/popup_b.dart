// Portions derived from DITING (https://github.com/chen08209/DITING), Copyright (c) the DITING authors, GPL-3.0-or-later.

part of 'popup.dart';

class _PopupUnfoldNotification extends Notification {
  const _PopupUnfoldNotification();
}

typedef _PlatterGlass = ({
  LiquidGlassStyle from,
  LiquidGlassStyle to,
  LiquidGlassRim rim,
});

/// The press that opened a popup on its control's pointer down. Its events
/// keep reaching the control, which hands them on for the menu to follow.
class _CarriedPress {
  ValueSetter<Offset>? onMove;
  ValueSetter<Offset>? onRelease;
  VoidCallback? onCancel;
}

class _PopupScope extends InheritedWidget {
  const _PopupScope({
    required this.platter,
    required this.press,
    required this.runPicked,
    required super.child,
  });

  final ValueListenable<bool> platter;
  final _CarriedPress press;
  final ValueSetter<VoidCallback> runPicked;

  static _PopupScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PopupScope>();

  @override
  bool updateShouldNotify(_PopupScope oldWidget) =>
      platter != oldWidget.platter ||
      press != oldWidget.press ||
      runPicked != oldWidget.runPicked;
}

class _PopupMorph extends SingleChildRenderObjectWidget {
  const _PopupMorph({
    required this.anchor,
    required this.animation,
    required this.grow,
    required this.moveX,
    required this.moveY,
    required this.content,
    required this.platter,
    required this.sourceColor,
    required this.sourceImage,
    required this.surfaceColor,
    required this.shadows,
    required this.glass,
    super.child,
  });

  final Rect anchor;
  final Animation<double> animation;
  final Animation<double> grow;
  final Animation<double> moveX;
  final Animation<double> moveY;
  final Animation<double> content;
  final ValueListenable<bool> platter;
  final Color sourceColor;
  final ValueListenable<ui.Image?>? sourceImage;
  final Color surfaceColor;
  final List<BoxShadow> shadows;

  /// The platter's glass as it leaves the anchor and as it lands on the card,
  /// or null for a [surfaceColor] fill.
  final _PlatterGlass? glass;

  @override
  _RenderPopupMorph createRenderObject(BuildContext context) {
    return _RenderPopupMorph(
      anchor: anchor,
      animation: animation,
      grow: grow,
      moveX: moveX,
      moveY: moveY,
      content: content,
      platter: platter,
      sourceColor: sourceColor,
      sourceImage: sourceImage,
      surfaceColor: surfaceColor,
      shadows: shadows,
      glass: glass,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPopupMorph renderObject,
  ) {
    renderObject
      ..anchor = anchor
      ..animation = animation
      ..grow = grow
      ..moveX = moveX
      ..moveY = moveY
      ..content = content
      ..platter = platter
      ..sourceColor = sourceColor
      ..sourceImage = sourceImage
      ..surfaceColor = surfaceColor
      ..shadows = shadows
      ..glass = glass;
  }
}

typedef _MorphFrame = ({
  double grow,
  double moveX,
  double moveY,
  double reveal,
  bool platter,
});

/// Grows the popup out of its anchor the way iOS 26 menus leave their button:
/// a platter flies from the anchor's capsule to the card's center on an arc,
/// growing on its own spring, while the content rides inside it, scaling,
/// fading and sharpening in. Closing returns it into its control the same way,
/// the content blurring out first; with no control to return into, the popup
/// shrinks toward its anchor as it fades.
class _RenderPopupMorph extends RenderProxyBox {
  _RenderPopupMorph({
    required Rect anchor,
    required Animation<double> animation,
    required this.grow,
    required this.moveX,
    required this.moveY,
    required this.content,
    required ValueListenable<bool> platter,
    required Color sourceColor,
    required ValueListenable<ui.Image?>? sourceImage,
    required Color surfaceColor,
    required List<BoxShadow> shadows,
    required _PlatterGlass? glass,
  }) : _anchor = anchor,
       _animation = animation,
       _platter = platter,
       _sourceColor = sourceColor,
       _sourceImage = sourceImage,
       _surfaceColor = surfaceColor,
       _shadows = shadows,
       _glass = glass;

  late final _pane = LiquidGlassPane(markNeedsPaint);

  Animation<double> grow;
  Animation<double> moveX;
  Animation<double> moveY;
  Animation<double> content;

  Rect _anchor;

  set anchor(Rect value) {
    if (value == _anchor) {
      return;
    }
    _anchor = value;
    markNeedsPaint();
  }

  Animation<double> _animation;

  set animation(Animation<double> value) {
    if (value == _animation) {
      return;
    }
    if (attached) {
      _animation
        ..removeListener(markNeedsPaint)
        ..removeStatusListener(_handleStatusChanged);
      value
        ..addListener(markNeedsPaint)
        ..addStatusListener(_handleStatusChanged);
    }
    _animation = value;
    markNeedsPaint();
  }

  _MorphFrame? _closingFrame;
  double _closingFrom = 1;

  void _handleStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.reverse) {
      return;
    }
    _closingFrom = _animation.value;
    _closingFrame = _frame();
  }

  /// Where the opening stands, or null once it has settled.
  _MorphFrame? _frame() {
    if (_animation.value >= 1) {
      return null;
    }
    return (
      grow: grow.value,
      moveX: moveX.value,
      moveY: moveY.value,
      reveal: content.value,
      platter: _platter.value,
    );
  }

  ValueListenable<bool> _platter;

  set platter(ValueListenable<bool> value) {
    if (value == _platter) {
      return;
    }
    if (attached) {
      _platter.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _platter = value;
    markNeedsPaint();
  }

  Color _sourceColor;

  set sourceColor(Color value) {
    if (value == _sourceColor) {
      return;
    }
    _sourceColor = value;
    markNeedsPaint();
  }

  ValueListenable<ui.Image?>? _sourceImage;

  set sourceImage(ValueListenable<ui.Image?>? value) {
    if (value == _sourceImage) {
      return;
    }
    if (attached) {
      _sourceImage?.removeListener(markNeedsPaint);
      value?.addListener(markNeedsPaint);
    }
    _sourceImage = value;
    markNeedsPaint();
  }

  Color _surfaceColor;

  set surfaceColor(Color value) {
    if (value == _surfaceColor) {
      return;
    }
    _surfaceColor = value;
    markNeedsPaint();
  }

  List<BoxShadow> _shadows;

  set shadows(List<BoxShadow> value) {
    if (listEquals(value, _shadows)) {
      return;
    }
    _shadows = value;
    markNeedsPaint();
  }

  _PlatterGlass? _glass;

  set glass(_PlatterGlass? value) {
    if (value == _glass) {
      return;
    }
    _glass = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation
      ..addListener(markNeedsPaint)
      ..addStatusListener(_handleStatusChanged);
    _platter.addListener(markNeedsPaint);
    _sourceImage?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation
      ..removeListener(markNeedsPaint)
      ..removeStatusListener(_handleStatusChanged);
    _platter.removeListener(markNeedsPaint);
    _sourceImage?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _pane.dispose();
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  /// The anchor in this box's coordinates; it comes in those of the layout
  /// box that places this one.
  Rect get _localAnchor =>
      _anchor.shift(-(parentData! as BoxParentData).offset);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      return;
    }
    if (_animation.status != AnimationStatus.reverse) {
      _paintFrame(context, offset, _frame());
      return;
    }
    final frame = _closingFrame;
    final from = _closingFrom;
    final dismissal = from <= 0
        ? 1.0
        : (1 - _animation.value / from).clamp(0.0, 1.0);
    if (_sourceImage != null) {
      final start =
          frame ??
          (grow: 1.0, moveX: 1.0, moveY: 1.0, reveal: 1.0, platter: true);
      _paintFrame(context, offset, (
        grow: start.grow * (1 - _returnSpring.transform(dismissal)),
        moveX: start.moveX * (1 - _returnXSpring.transform(dismissal)),
        moveY: start.moveY * (1 - _returnYSpring.transform(dismissal)),
        reveal: start.reveal * (1 - _contentOut.transform(dismissal)),
        platter: true,
      ), returning: true);
      return;
    }
    final shrink = Curves.easeOut.transform(dismissal);
    final scale = lerpDouble(1, _dismissScale, shrink)!;
    final anchor = _localAnchor.center;
    final origin = Offset(
      anchor.dx.clamp(0.0, size.width),
      anchor.dy.clamp(0.0, size.height),
    );
    final transform = Matrix4.translationValues(origin.dx, origin.dy, 0)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-origin.dx, -origin.dy, 0, 1);
    context.pushTransform(
      needsCompositing,
      offset,
      transform,
      (context, offset) => LiquidGlassFade.push(
        context,
        offset,
        Color.getAlphaFromOpacity(1 - shrink),
        (context, offset) => _paintFrame(context, offset, frame),
      ),
    );
  }

  void _paintFrame(
    PaintingContext context,
    Offset offset,
    _MorphFrame? frame, {
    bool returning = false,
  }) {
    final child = this.child!;
    if (frame == null) {
      _pane.clear();
      context.paintChild(child, offset);
      return;
    }
    final from = _localAnchor;
    final bounds = Offset.zero & size;
    final progress = frame.grow;
    final extent = Size.lerp(from.size, bounds.size, progress)!;
    final rect = Rect.fromCenter(
      center: Offset(
        lerpDouble(from.center.dx, bounds.center.dx, frame.moveX)!,
        lerpDouble(from.center.dy, bounds.center.dy, frame.moveY)!,
      ),
      width: math.max(0.0, extent.width),
      height: math.max(0.0, extent.height),
    );
    final radius = lerpDouble(from.shortestSide / 2, _cardRadius, progress)!;
    final clip = AppShape.all(math.max(0.0, radius)).getOuterPath(rect);
    final sourceImage = _sourceImage;
    final image = sourceImage?.value;
    // The source control stays visible until its snapshot exists, so the
    // platter would only cover it.
    if (sourceImage != null && image == null) {
      return;
    }
    final reveal = frame.reveal;
    // The card paints the same surface and shadow as the platter, so once it
    // is revealed, or a sub menu leaves the root's bounds, the platter steps
    // aside instead of clipping the levels until the spring settles.
    if (!frame.platter && !size.isEmpty) {
      _pane.clear();
      context.pushTransform(
        needsCompositing,
        offset,
        _contentTransform(rect),
        (context, offset) => context.paintChild(child, offset),
      );
      return;
    }
    final glass = _glass;
    final settled = progress.clamp(0.0, 1.0);
    final rim = glass?.rim.scale(settled);
    // Returning cards keep their own fill and shadow as they fade into the
    // platter's; on glass they stand bare and the platter holds throughout.
    final platter = returning && glass == null ? 1 - reveal : 1.0;
    final path = clip.shift(offset);
    if (glass != null) {
      // Frosted as the card and shadowed after, so one capture serves the morph.
      _pane.paint(
        context,
        rect.shift(offset),
        shape: LiquidGlassCorners.circular(math.max(0.0, radius)),
        style: LiquidGlassStyle.lerp(
          glass.from,
          glass.to,
          settled,
        ).copyWith(blur: glass.to.blur),
        hold: bounds
            .expandToInclude(from)
            .inflate(size.longestSide * _overshootPerLongestSide)
            .shift(offset),
        rim: rim,
      );
    }
    final canvas = context.canvas;
    final reach = _shadows.fold(
      0.0,
      (reach, shadow) =>
          math.max(reach, shadow.blurSigma * 3 + shadow.offset.distance),
    );
    // The blur shades under the platter too; keep that out of fading content.
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(path.getBounds().inflate(reach))
          ..addPath(path, Offset.zero),
      );
    final corners = AppRadius.all(math.max(0.0, radius));
    for (final shadow in _shadows) {
      canvas.drawRSuperellipse(
        corners.toRSuperellipse(rect.shift(offset + shadow.offset)),
        shadow.toPaint()
          ..color = shadow.color.withValues(
            alpha: shadow.color.a * settled * platter,
          ),
      );
    }
    canvas.restore();
    final Color fill;
    if (glass == null) {
      final surface = Color.lerp(_sourceColor, _surfaceColor, settled)!;
      fill = surface.withValues(alpha: surface.a * platter);
    } else {
      fill = _sourceColor.withValues(alpha: _sourceColor.a * (1 - settled));
    }
    canvas.drawPath(path, Paint()..color = fill);
    rim?.paintLine(context.canvas, rect.shift(offset), math.max(0.0, radius));
    final glyph = 1 - reveal;
    if (image != null && glyph > 0) {
      final source = from.shift(rect.center - from.center + offset);
      context.canvas.drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        source,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, glyph)
          ..filterQuality = FilterQuality.medium,
      );
    }
    if (reveal <= 0 || size.isEmpty) {
      return;
    }
    // Opening, the content fills the platter and is cut to it; returning, it
    // shrinks whole inside it.
    final transform = _contentTransform(rect, fit: returning);
    final sigma = _maxContentBlur * (1 - reveal);
    void paintContent(PaintingContext context, Offset offset) =>
        context.pushOpacity(
          offset,
          Color.getAlphaFromOpacity(reveal),
          (context, offset) => context.pushLayer(
            ImageFilterLayer(
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            ),
            (context, offset) => context.pushTransform(
              needsCompositing,
              offset,
              transform,
              (context, offset) => context.paintChild(child, offset),
            ),
            offset,
          ),
        );
    if (returning) {
      paintContent(context, offset);
      return;
    }
    context.pushClipPath(needsCompositing, offset, bounds, clip, paintContent);
  }

  Matrix4 _contentTransform(Rect rect, {bool fit = false}) {
    final scale = (fit ? math.min : math.max)(
      rect.width / size.width,
      rect.height / size.height,
    );
    return Matrix4.translationValues(rect.center.dx, rect.center.dy, 0)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
  }
}

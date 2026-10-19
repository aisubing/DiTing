// Portions derived from DITING (https://github.com/chen08209/DITING), Copyright (c) the DITING authors, GPL-3.0-or-later.

part of 'open_container.dart';

class _OpenOpacity extends Animation<double>
    with AnimationWithParentMixin<double> {
  _OpenOpacity(this.route);

  final _OpenContainerRoute<dynamic> route;

  @override
  Animation<double> get parent => route.animation!;

  @override
  double get value => route._fade;
}

enum _Slot { closed, open }

/// Grows the container from the closed child's rect to the whole route by
/// painting alone: the open page is laid out once at its final size and
/// moved under a clip, and the closed child is scaled to the rect's width.
class _ContainerTransition
    extends SlottedMultiChildRenderObjectWidget<_Slot, RenderBox> {
  const _ContainerTransition({
    required this.route,
    required this.closedColor,
    required this.openColor,
    required this.settledColor,
    required this.closed,
    required this.open,
  });

  final _OpenContainerRoute<dynamic> route;
  final Color closedColor;
  final Color openColor;
  final Color settledColor;
  final Widget? closed;
  final Widget open;

  @override
  Iterable<_Slot> get slots => _Slot.values;

  @override
  Widget? childForSlot(_Slot slot) => switch (slot) {
    _Slot.closed => closed,
    _Slot.open => open,
  };

  @override
  _RenderContainerTransition createRenderObject(BuildContext context) {
    return _RenderContainerTransition(
      route: route,
      closedColor: closedColor,
      openColor: openColor,
      settledColor: settledColor,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderContainerTransition renderObject,
  ) {
    renderObject
      ..route = route
      ..closedColor = closedColor
      ..openColor = openColor
      ..settledColor = settledColor
      ..markNeedsLayout();
  }
}

class _RenderContainerTransition extends RenderBox
    with SlottedContainerRenderObjectMixin<_Slot, RenderBox> {
  _RenderContainerTransition({
    required _OpenContainerRoute<dynamic> route,
    required Color closedColor,
    required Color openColor,
    required Color settledColor,
  }) : _route = route,
       _closedColor = closedColor,
       _openColor = openColor,
       _settledColor = settledColor;

  _OpenContainerRoute<dynamic> get route => _route;
  _OpenContainerRoute<dynamic> _route;
  set route(_OpenContainerRoute<dynamic> value) {
    if (identical(value, _route)) {
      return;
    }
    if (attached) {
      _unlisten();
    }
    _route = value;
    if (attached) {
      _listen();
    }
    markNeedsPaint();
  }

  Color _closedColor;
  set closedColor(Color value) {
    if (value == _closedColor) {
      return;
    }
    _closedColor = value;
    markNeedsPaint();
  }

  Color _openColor;
  set openColor(Color value) {
    if (value == _openColor) {
      return;
    }
    _openColor = value;
    markNeedsPaint();
  }

  Color _settledColor;
  set settledColor(Color value) {
    if (value == _settledColor) {
      return;
    }
    _settledColor = value;
    markNeedsPaint();
  }

  RenderBox? get _closed => childForSlot(_Slot.closed);
  RenderBox? get _open => childForSlot(_Slot.open);

  final _clipLayer = LayerHandle<ContainerLayer>();
  final _closedTransformLayer = LayerHandle<TransformLayer>();

  void _handleStatus(AnimationStatus _) => markNeedsPaint();

  void _listen() {
    _route.animation!
      ..addListener(markNeedsPaint)
      ..addStatusListener(_handleStatus);
  }

  void _unlisten() {
    _route.animation!
      ..removeListener(markNeedsPaint)
      ..removeStatusListener(_handleStatus);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listen();
  }

  @override
  void detach() {
    _unlisten();
    super.detach();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    _closedTransformLayer.layer = null;
    super.dispose();
  }

  Rect? get _closedRect => _route._closedRect.value;

  /// The container's rect, or null once the route has settled.
  Rect? get _rect {
    if (_route._settled) {
      return null;
    }
    final full = Offset.zero & size;
    return Rect.lerp(_closedRect ?? full, full, _route._progress)!;
  }

  Matrix4? _closedTransform(Rect rect) {
    final closedRect = _closedRect;
    if (closedRect == null || closedRect.width == 0) {
      return null;
    }
    final scale = rect.width / closedRect.width;
    return Matrix4.translationValues(rect.left, rect.top, 0)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    _closed?.layout(BoxConstraints.tight(_closedRect?.size ?? Size.zero));
    _open?.layout(BoxConstraints.tight(size));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final rect = _rect;
    if (rect == null) {
      _clipLayer.layer = null;
      _closedTransformLayer.layer = null;
      context.canvas.drawRect(offset & size, Paint()..color = _settledColor);
      context.paintChild(_open!, offset);
      return;
    }
    final path = _route._shapeTween.lerp(_route._progress)?.getOuterPath(rect);
    final color = Paint()
      ..color = Color.lerp(_closedColor, _openColor, _route._fade)!;
    if (path == null) {
      context.canvas.drawRect(rect.shift(offset), color);
    } else {
      context.canvas.drawPath(path.shift(offset), color);
    }
    void paintContents(PaintingContext context, Offset offset) {
      final closed = _closed;
      final transform = _closedTransform(rect);
      if (closed != null && transform != null) {
        _closedTransformLayer.layer = context.pushTransform(
          closed.needsCompositing,
          offset,
          transform,
          (context, offset) => context.paintChild(closed, offset),
          oldLayer: _closedTransformLayer.layer,
        );
      } else {
        _closedTransformLayer.layer = null;
      }
      context.paintChild(_open!, offset + rect.topLeft);
    }

    final oldLayer = _clipLayer.layer;
    _clipLayer.layer = path == null
        ? context.pushClipRect(
            needsCompositing,
            offset,
            rect,
            paintContents,
            clipBehavior: Clip.antiAlias,
            oldLayer: oldLayer is ClipRectLayer ? oldLayer : null,
          )
        : context.pushClipPath(
            needsCompositing,
            offset,
            rect,
            path,
            paintContents,
            clipBehavior: Clip.antiAlias,
            oldLayer: oldLayer is ClipPathLayer ? oldLayer : null,
          );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final rect = _rect;
    if (rect == null) {
      return;
    }
    if (identical(child, _closed)) {
      final closedTransform = _closedTransform(rect);
      if (closedTransform != null) {
        transform.multiply(closedTransform);
      }
      return;
    }
    transform.translateByDouble(rect.left, rect.top, 0, 1);
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final rect = _rect;
    if (rect != null) {
      final shape = _route._shapeTween.lerp(_route._progress);
      final inside = shape == null
          ? rect.contains(position)
          : shape.getOuterPath(rect).contains(position);
      if (!inside) {
        return false;
      }
    }
    return super.hitTest(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_route._fade == 0) {
      return false;
    }
    final origin = _rect?.topLeft ?? Offset.zero;
    return result.addWithPaintOffset(
      offset: origin,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        return _open!.hitTest(result, position: transformed);
      },
    );
  }
}

// Portions derived from FlClash (https://github.com/chen08209/FlClash), Copyright (c) the FlClash authors, GPL-3.0-or-later.

part of 'liquid_glass.dart';

/// Redraws onto a capture what a pane's root holds below the pane, as the
/// engine composites it, but for the root's own effect, which the engine
/// applies to the glass as well.
class _Replay {
  _Replay(this.canvas, this.drawn, this.entry) : _toHost = [entry.rootToHost];

  final Canvas canvas;
  final List<Object?> drawn;
  final _Behind entry;
  final List<Matrix4> _toHost;

  // A layer's effects are applied only once something under it draws.
  final _entered = <(ContainerLayer, Matrix4?, bool)>[];
  final _saves = <int>[];

  void run() => _walk(entry.root, root: true);

  bool _walk(ContainerLayer layer, {required bool root}) {
    if (!root && !entry.ancestors.contains(layer) && !_mayShow(layer)) {
      return false;
    }
    final geometry = _geometry(layer);
    final outer = _toHost.last;
    _toHost.add(geometry == null ? outer : (outer.clone()..multiply(geometry)));
    _entered.add((layer, geometry, root));
    var reached = false;
    for (Layer? child = layer.firstChild; child != null && !reached;) {
      switch (child) {
        case _ when identical(child, entry.pane):
          reached = true;
        case final _LiquidGlassLayer pane
            when pane._capturedPass == _LiquidGlassHostLayer._pass:
          if (pane._captured case final picture? when _shows(pane.rect)) {
            _draw(picture);
          }
        case final PictureLayer recorded:
          if (recorded.picture case final picture?
              when _shows(recorded.canvasBounds.inflate(_overflow))) {
            _draw(picture);
          }
        case final ContainerLayer container:
          reached = _walk(container, root: false);
      }
      child = child.nextSibling;
    }
    _leave();
    _toHost.removeLast();
    return reached;
  }

  bool _mayShow(ContainerLayer layer) {
    if (layer is OpacityLayer && layer.alpha == 0) {
      return false;
    }
    final clip = layer.describeClipBounds();
    return clip == null || _shows(clip);
  }

  bool _shows(Rect bounds) =>
      MatrixUtils.transformRect(_toHost.last, bounds).overlaps(entry.slot);

  void _draw(ui.Picture picture) {
    while (_saves.length < _entered.length) {
      _saves.add(_apply(_entered[_saves.length]));
    }
    canvas.drawPicture(picture);
    drawn.add(picture);
  }

  int _apply((ContainerLayer, Matrix4?, bool) entered) {
    final (layer, geometry, root) = entered;
    var saves = 0;
    if (geometry != null) {
      canvas
        ..save()
        ..transform(geometry.storage);
      drawn.addAll(geometry.storage);
      saves++;
    }
    final effect = root
        ? null
        : switch (layer) {
            OpacityLayer(:final alpha?) when alpha < 255 => (
              Paint()..color = Color.fromARGB(alpha, 0, 0, 0),
              alpha,
            ),
            ColorFilterLayer(:final colorFilter?) => (
              Paint()..colorFilter = colorFilter,
              colorFilter,
            ),
            ImageFilterLayer(:final imageFilter?) => (
              Paint()..imageFilter = imageFilter,
              imageFilter,
            ),
            ShaderMaskLayer(:final shader) => (Paint(), shader),
            _ => null,
          };
    if (effect case (final paint, final key)?) {
      canvas.saveLayer(null, paint);
      drawn
        ..add(layer.runtimeType)
        ..add(key);
      saves++;
    }
    if (_clip(layer)) {
      saves++;
    }
    return saves;
  }

  bool _clip(ContainerLayer layer) {
    final Object clip;
    switch (layer) {
      case ClipRectLayer(:final clipRect?, :final clipBehavior)
          when clipBehavior != Clip.none:
        canvas
          ..save()
          ..clipRect(clipRect, doAntiAlias: clipBehavior != Clip.hardEdge);
        clip = clipRect;
      case ClipRSuperellipseLayer(
            :final clipRSuperellipse?,
            :final clipBehavior,
          )
          when clipBehavior != Clip.none:
        canvas
          ..save()
          ..clipRSuperellipse(
            clipRSuperellipse,
            doAntiAlias: clipBehavior != Clip.hardEdge,
          );
        clip = clipRSuperellipse;
      case ClipPathLayer(:final clipPath?, :final clipBehavior)
          when clipBehavior != Clip.none:
        canvas
          ..save()
          ..clipPath(clipPath, doAntiAlias: clipBehavior != Clip.hardEdge);
        clip = clipPath;
      default:
        // Lib clips to no rounded rect, so one a package draws clips by its
        // bounds here.
        final bounds = layer.describeClipBounds();
        if (bounds == null) {
          return false;
        }
        canvas
          ..save()
          ..clipRect(bounds);
        clip = bounds;
    }
    drawn.add(clip);
    return true;
  }

  void _leave() {
    final (layer, _, root) = _entered.removeLast();
    if (_saves.length <= _entered.length) {
      return;
    }
    final saves = _saves.removeLast();
    if (layer case ShaderMaskLayer(
      :final shader?,
      :final maskRect?,
      :final blendMode?,
    ) when !root) {
      canvas
        ..translate(maskRect.left, maskRect.top)
        ..drawRect(
          Offset.zero & maskRect.size,
          Paint()
            ..shader = shader
            ..blendMode = blendMode,
        );
      drawn
        ..add(maskRect)
        ..add(blendMode);
    }
    for (var index = 0; index < saves; index++) {
      canvas.restore();
    }
    drawn.add(saves);
  }
}

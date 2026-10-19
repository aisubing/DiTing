// Portions derived from DITING (https://github.com/chen08209/DITING), Copyright (c) the DITING authors, GPL-3.0-or-later.

part of 'open_container.dart';

class _OpenContainerRoute<T> extends ModalRoute<T>
    with DragBackRouteMixin<T>, DeferredPushRouteMixin<T> {
  _OpenContainerRoute({
    required this.closedColor,
    required ShapeBorder? closedShape,
    required this.closedBuilder,
    required this.openBuilder,
    required this.hideableKey,
    required this.closedBuilderKey,
  }) : _shapeTween = ShapeBorderTween(begin: closedShape);

  final Color? closedColor;
  final CloseContainerBuilder closedBuilder;
  final OpenContainerBuilder<T> openBuilder;
  final GlobalKey<_HideableState> hideableKey;
  final GlobalKey closedBuilderKey;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  static const _curve = Curves.fastOutSlowIn;
  static final _reverseCurve = _curve.flipped;

  final ShapeBorderTween _shapeTween;

  // The closed child stays in this route from the push until the route is
  // dismissed or dragged back, so it moves between its tile and the route
  // twice per cycle rather than at every status change.
  final _closedRect = ValueNotifier<Rect?>(null);
  final _hostsClosed = ValueNotifier<bool>(false);
  late final Listenable _closedChanges = Listenable.merge([
    _closedRect,
    _hostsClosed,
  ]);
  late final _openOpacity = _OpenOpacity(this);

  AnimationStatus? _lastAnimationStatus;
  AnimationStatus? _currentAnimationStatus;

  bool get _settled => animation!.isCompleted || isDragBackActive;

  bool get _closing =>
      animation!.status == AnimationStatus.reverse &&
      !_transitionWasInterrupted;

  double get _progress {
    final t = animation!.value;
    if (t == 0 || t == 1) {
      return t;
    }
    return (_closing ? _reverseCurve : _curve).transform(t);
  }

  /// How far the open page and the container color have faded in. Both
  /// change over a fifth of the transition: the second fifth on the way in,
  /// the fourth on the way out.
  double get _fade {
    if (_settled) {
      return 1;
    }
    final start = _closing ? 0.6 : 0.2;
    return clampDouble((animation!.value - start) / 0.2, 0, 1);
  }

  @override
  TickerFuture didPush() {
    _takeMeasurements(navigatorContext: hideableKey.currentContext!);

    animation!.addStatusListener((AnimationStatus status) {
      _lastAnimationStatus = _currentAnimationStatus;
      _currentAnimationStatus = status;
      switch (status) {
        case AnimationStatus.dismissed:
          _returnClosedChild(visible: true);
          break;
        case AnimationStatus.completed:
          if (!_hostsClosed.value) {
            hideableKey.currentState?.isVisible = false;
          }
          break;
        case AnimationStatus.forward:
        case AnimationStatus.reverse:
          break;
      }
    });

    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    if (isDragBackActive) {
      return super.didPop(result);
    }
    _takeMeasurements(
      navigatorContext: subtreeContext!,
      delayForSourceRoute: true,
    );
    return super.didPop(result);
  }

  @override
  void dispose() {
    final hideable = hideableKey.currentState;
    if (hideable != null && (!hideable.isInTree || !hideable.isVisible)) {
      SchedulerBinding.instance.addPostFrameCallback(
        (Duration d) => hideableKey.currentState
          ?..placeholderSize = null
          ..isVisible = true,
      );
    }
    super.dispose();
    _closedRect.dispose();
    _hostsClosed.dispose();
  }

  void _returnClosedChild({required bool visible}) {
    final hideable = hideableKey.currentState;
    if (hideable == null) {
      return;
    }
    hideable
      ..placeholderSize = null
      ..isVisible = visible;
    _hostsClosed.value = false;
  }

  void _takeMeasurements({
    required BuildContext navigatorContext,
    bool delayForSourceRoute = false,
  }) {
    final RenderBox navigator =
        Navigator.of(navigatorContext).context.findRenderObject()! as RenderBox;

    void takeMeasurementsInSourceRoute([Duration? _]) {
      if (!navigator.attached || hideableKey.currentContext == null) {
        return;
      }
      final rect = _getRect(hideableKey, navigator);
      _closedRect.value = rect;
      hideableKey.currentState!.placeholderSize = rect.size;
      _hostsClosed.value = true;
    }

    if (delayForSourceRoute) {
      SchedulerBinding.instance.addPostFrameCallback(
        takeMeasurementsInSourceRoute,
      );
    } else {
      takeMeasurementsInSourceRoute();
    }
  }

  Rect _getRect(GlobalKey key, RenderBox ancestor) {
    assert(key.currentContext != null);
    assert(ancestor.hasSize);
    final RenderBox render =
        key.currentContext!.findRenderObject()! as RenderBox;
    assert(render.hasSize);
    return MatrixUtils.transformRect(
      render.getTransformTo(ancestor),
      Offset.zero & render.size,
    );
  }

  bool get _transitionWasInterrupted =>
      (_lastAnimationStatus?.isAnimating ?? false) &&
      (_currentAnimationStatus?.isAnimating ?? false);

  void closeContainer({T? returnValue}) {
    Navigator.of(subtreeContext!).pop(returnValue);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final theme = Theme.of(context);
    final surface = SurfaceLevel.page.colorOf(theme.colorScheme);
    final open = FadeTransition(
      opacity: _openOpacity,
      child: RepaintBoundary(
        child: Material(
          type: MaterialType.transparency,
          child: Builder(
            builder: (BuildContext context) {
              return KeyboardInsetHold(
                child: openBuilder(context, closeContainer),
              );
            },
          ),
        ),
      ),
    );
    return ListenableBuilder(
      listenable: _closedChanges,
      builder: (BuildContext context, Widget? open) {
        return _ContainerTransition(
          route: this,
          closedColor: closedColor ?? surface,
          openColor: surface,
          settledColor: theme.canvasColor,
          closed: _hostsClosed.value
              ? IgnorePointer(
                  child: ExcludeFocus(
                    child: ExcludeSemantics(
                      child: Material(
                        type: MaterialType.transparency,
                        child: Builder(
                          key: closedBuilderKey,
                          builder: (BuildContext context) {
                            // Use dummy "open container" callback
                            // since we are in the process of opening.
                            return closedBuilder(context, () {});
                          },
                        ),
                      ),
                    ),
                  ),
                )
              : null,
          open: open!,
        );
      },
      child: open,
    );
  }

  @override
  void didStartDragBack() => _returnClosedChild(visible: true);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return dragBackDetector(dragBackSlide(context, animation, child));
  }

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;
}

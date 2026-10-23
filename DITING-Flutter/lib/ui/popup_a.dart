// Portions derived from DITING (https://github.com/chen08209/DITING), Copyright (c) the DITING authors, GPL-3.0-or-later.

part of 'popup.dart';

// Soft and wide like HyperOS menus rather than a Material elevation.
List<BoxShadow> _cardShadows(ColorScheme colorScheme, [double depth = 1]) {
  final strength = colorScheme.brightness == Brightness.dark ? 3.0 : 1.0;
  final alpha = strength * depth;
  return [
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: 0.05 * alpha),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: colorScheme.shadow.withValues(alpha: 0.04 * alpha),
      blurRadius: 30,
      offset: const Offset(0, 4),
    ),
  ];
}

const _maxContentBlur = 8.0;

const _overshootPerLongestSide = 0.1;

const _openDuration = Duration(milliseconds: 750);

const _dismissDuration = Duration(milliseconds: 300);

const _shrinkDuration = Duration(milliseconds: 200);

/// How far a popup with no control to return into shrinks toward its anchor as it fades.
const _dismissScale = 0.8;

double _secondsOf(Duration duration) =>
    duration.inMicroseconds / Duration.microsecondsPerSecond;

final _openSeconds = _secondsOf(_openDuration);

final _dismissSeconds = _secondsOf(_dismissDuration);

const _contentOut = Interval(0, 0.5, curve: Curves.easeOut);

final _returnSpring = SpringCurve(
  SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 260),
  ),
  seconds: _dismissSeconds,
);

final _returnXSpring = SpringCurve(
  SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 220),
  ),
  seconds: _dismissSeconds,
);

final _returnYSpring = SpringCurve(
  SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 290),
  ),
  seconds: _dismissSeconds,
);

final _growSpring = SpringCurve(
  SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 500),
    bounce: 0.3,
  ),
  seconds: _openSeconds,
);

final _moveYSpring = SpringCurve(
  SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 340),
    bounce: 0.12,
  ),
  seconds: _openSeconds,
);

final _moveXSpring = SpringCurve(
  SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 520),
    bounce: 0.2,
  ),
  seconds: _openSeconds,
);

const _dwellDuration = Duration(milliseconds: 400);

final _unfoldSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 420),
  bounce: 0.15,
);

final _foldSpring = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 340),
);

class CommonPopupRoute<T> extends PopupRoute<T> {
  CommonPopupRoute({
    required this.builder,
    required this.anchorOf,
    required this.barrierLabel,
    this.placement = PopupPlacement.overAnchorEnd,
    this.elevated = false,
    this.sourceColor = Colors.transparent,
    this.sourceImage,
    this.modal = true,
    this.avoid,
  }) : super(requestFocus: modal ? null : false);

  final WidgetBuilder builder;

  final PopupAnchorResolver anchorOf;
  final PopupPlacement placement;

  /// Whether the popup opens from a sheet's [ElevatedSurfaceTheme], below its navigator.
  final bool elevated;

  final Color sourceColor;

  /// A snapshot of the source control, drawn inside the platter while the control is hidden.
  final ValueListenable<ui.Image?>? sourceImage;

  final bool modal;

  final Rect? avoid;

  @override
  final String? barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => _openDuration;

  @override
  Duration get reverseTransitionDuration =>
      sourceImage == null ? _shrinkDuration : _dismissDuration;

  late final CurvedAnimation _grow = CurvedAnimation(
    parent: animation!,
    curve: _growSpring,
  );

  late final CurvedAnimation _moveX = CurvedAnimation(
    parent: animation!,
    curve: _moveXSpring,
  );

  late final CurvedAnimation _moveY = CurvedAnimation(
    parent: animation!,
    curve: _moveYSpring,
  );

  late final CurvedAnimation _content = CurvedAnimation(
    parent: animation!,
    curve: const Interval(0.04, 0.45, curve: Curves.easeOutCubic),
  );

  final _unfolded = ValueNotifier<bool>(false);

  /// Whether the platter shows rather than the cards, which on glass stand bare meanwhile.
  final _platter = ValueNotifier<bool>(true);

  final _pin = _PopupPin();

  final _press = _CarriedPress();

  @override
  void install() {
    super.install();
    animation!
      ..addListener(_updatePlatter)
      ..addStatusListener(_handleStatusChanged);
    _unfolded.addListener(_updatePlatter);
  }

  void _handleStatusChanged(AnimationStatus status) => _updatePlatter();

  void _updatePlatter() {
    final animation = this.animation!;
    // A popup with a control to return into does so on the platter; one without dissolves.
    if (animation.status == AnimationStatus.reverse) {
      if (sourceImage != null) {
        _platter.value = true;
      }
      return;
    }
    _platter.value =
        !animation.isCompleted && _content.value < 1 && !_unfolded.value;
  }

  @override
  void dispose() {
    animation
      ?..removeListener(_updatePlatter)
      ..removeStatusListener(_handleStatusChanged);
    _grow.dispose();
    _moveX.dispose();
    _moveY.dispose();
    _content.dispose();
    _unfolded.dispose();
    _platter.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    if (isCurrent) {
      navigator?.pop();
    }
  }

  /// A popup that returns into its control runs a picked item once landed, so nothing rebuilds.
  void _runPicked(VoidCallback action) {
    if (sourceImage == null) {
      action();
      return;
    }
    unawaited(completed.whenComplete(action));
  }

  @override
  Widget buildModalBarrier() {
    return modal ? super.buildModalBarrier() : const SizedBox.shrink();
  }

  Widget _buildDismissLayer() {
    if (modal) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: _handleDismiss,
      );
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _handleDismiss(),
      onPointerPanZoomStart: (_) => _handleDismiss(),
      onPointerSignal: (_) => _handleDismiss(),
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return SurfaceScope(
      level: SurfaceLevel.floatingOf(context.colorScheme),
      child: _PopupScope(
        platter: _platter,
        press: _press,
        runPicked: _runPicked,
        child: builder(context),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (elevated) {
      return ElevatedSurfaceTheme(
        child: Builder(
          builder: (context) => _buildPopup(context, animation, child),
        ),
      );
    }
    return _buildPopup(context, animation, child);
  }

  Widget _buildPopup(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    final colorScheme = context.colorScheme;
    final glass = LiquidGlassScope.of(context);
    return Stack(
      children: [
        Positioned.fill(child: _buildDismissLayer()),
        _PopupAnchorTracker(
          anchorOf: anchorOf,
          builder: (anchor, safeInsets, child) => CustomSingleChildLayout(
            delegate: _PopupLayoutDelegate(
              anchor: anchor,
              safeInsets: safeInsets,
              placement: placement,
              avoid: avoid,
              pin: _pin,
            ),
            child: _PopupMorph(
              anchor: anchor,
              animation: animation,
              grow: _grow,
              moveX: _moveX,
              moveY: _moveY,
              content: _content,
              platter: _platter,
              sourceColor: sourceColor,
              sourceImage: sourceImage,
              surfaceColor: SurfaceLevel.floatingOf(
                colorScheme,
              ).colorOf(colorScheme),
              shadows: glass
                  ? glassMenuShadows(colorScheme)
                  : _cardShadows(colorScheme),
              glass: glass
                  ? (
                      from: LiquidGlassStyle.regular(colorScheme),
                      to: LiquidGlassStyle.menu(colorScheme),
                      rim: LiquidGlassRim.menu(colorScheme),
                    )
                  : null,
              child: child,
            ),
          ),
          child: NotificationListener<_PopupUnfoldNotification>(
            onNotification: (_) {
              _unfolded.value = true;
              return true;
            },
            child: child,
          ),
        ),
      ],
    );
  }
}

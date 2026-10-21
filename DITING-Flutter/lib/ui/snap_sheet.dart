// Portions derived from DITING (https://github.com/chen08209/DITING), Copyright (c) the DITING authors, GPL-3.0-or-later.
import 'dart:async';
import 'dart:math' as math;

import 'package:diting/ui/context.dart';
import 'package:diting/ui/scroll_behavior.dart';
import 'package:diting/ui/shape.dart';
import 'package:diting/ui/surface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import 'inherited.dart';
import 'sheet.dart';
import 'sheet_navigator.dart';
part 'snap_sheet_a.dart';
part 'snap_sheet_b.dart';
part 'snap_sheet_c.dart';

/// Receives the sheet's own scroll controller, or null where the sheet has no
/// detents to drag between and the content keeps its own controller.
typedef SnapSheetBuilder =
    Widget Function(BuildContext context, ScrollController? controller);

/// The heights a snap sheet rests at, as a fraction of the space it gets.
const snapSheetDetents = [9 / 16, 0.9];

/// UIKit's presentation spring, mass 3 and stiffness 1000, which iOS 27 runs
/// critically damped for every move of a sheet.
const _stiffness = 1000 / 3;

final _omega = math.sqrt(_stiffness);

/// A sheet thrown at its detent overshoots it slightly on iOS.
const _thrownRatio = 0.8;
const _fullThrow = 0.3;
const _hardestThrow = 0.75;

/// UIScrollView.DecelerationRate.fast, which iOS projects a release with.
const _projectionTime = 0.99 / (1 - 0.99) / 1000;

const _settleTolerance = Tolerance(distance: 0.5, velocity: 10);

const _peakEase = 120.0;

/// [_settleTolerance] for a sheet about 500 pixels tall, in UIKit's 0.5 s.
const _presentationTolerance = Tolerance(distance: 0.001, velocity: 0.02);

/// Wheel events closer together than this are one turn of the wheel, the
/// span Chromium latches a wheel sequence to one scroller for.
const _wheelTurnGap = Duration(milliseconds: 500);

class SnapSheetRoute<T> extends PopupRoute<T> with SheetCoverRouteMixin<T> {
  SnapSheetRoute({
    required this.builder,
    required this.sheetBarrierColor,
    required this.barrierLabel,
    this.detents = snapSheetDetents,
    this.fitsContent = false,
    this.initialScrollOffset = 0,
  });

  final SnapSheetBuilder builder;
  final Color sheetBarrierColor;
  final List<double> detents;

  final bool fitsContent;

  final double initialScrollOffset;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => sheetBarrierColor;

  @override
  bool get barrierDismissible => true;

  final _dismissHandler = ValueNotifier<SheetDismissHandler?>(null);

  final _coveringSheet = ValueNotifier<SnapSheetRoute<dynamic>?>(null);

  double _closingVelocity = 0;

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);
    _coveringSheet.value = nextRoute is SnapSheetRoute ? nextRoute : null;
  }

  Future<void> _dismiss() async {
    final handler = _dismissHandler.value;
    if (handler != null) {
      await handler();
    } else {
      await navigator?.maybePop();
    }
  }

  void _drag(double value) => controller!.value = value;

  void _restore(double velocity) {
    controller!.animateWith(_presentation(1, velocity));
  }

  /// Springs back while a guard decides, and leaves from there with
  /// [velocity] if the sheet closes now, the way UIKit answers a swipe.
  void _close(double velocity) {
    _restore(0);
    _closingVelocity = velocity;
    SchedulerBinding.instance.addPostFrameCallback((_) => _closingVelocity = 0);
    unawaited(_dismiss());
  }

  _SheetSpring _presentation(double target, double velocity) {
    final from = controller!.value;
    final launch = _launch(target - from, velocity, overshoots: false);
    return _SheetSpring(
      from: from,
      to: target,
      velocity: launch.velocity,
      ratio: launch.ratio,
      tolerance: _presentationTolerance,
    );
  }

  @override
  Simulation createSimulation({required bool forward}) {
    final velocity = forward ? 0.0 : _closingVelocity;
    _closingVelocity = 0;
    return _presentation(forward ? 1 : 0, velocity);
  }

  @override
  Widget buildModalBarrier() {
    void onDismiss() => unawaited(_dismiss());
    final color = barrierColor;
    if (color == null || color.a == 0 || offstage) {
      return ModalBarrier(
        dismissible: barrierDismissible,
        semanticsLabel: barrierLabel,
        barrierSemanticsDismissible: semanticsDismissible,
        onDismiss: onDismiss,
      );
    }
    return AnimatedModalBarrier(
      color: animation!.drive(
        ColorTween(begin: color.withValues(alpha: 0), end: color),
      ),
      dismissible: barrierDismissible,
      semanticsLabel: barrierLabel,
      barrierSemanticsDismissible: semanticsDismissible,
      onDismiss: onDismiss,
    );
  }

  @override
  void dispose() {
    _dismissHandler.dispose();
    _coveringSheet.dispose();
    super.dispose();
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return ElevatedSurfaceTheme(child: _SnapSheet(route: this));
  }
}

/// A throw away from the target is dropped, as UIKit drops it.
({double velocity, double ratio}) _launch(
  double distance,
  double velocity, {
  required bool overshoots,
}) {
  if (distance == 0 || velocity == 0 || velocity.sign != distance.sign) {
    return (velocity: 0, ratio: 1);
  }
  final reach = _omega * distance.abs();
  final strength = velocity.abs() / reach;
  if (!overshoots) {
    return (velocity: velocity.sign * math.min(strength, 1) * reach, ratio: 1);
  }
  return (
    velocity: velocity.sign * math.min(strength, _hardestThrow) * reach,
    ratio: 1 - (1 - _thrownRatio) * math.min(strength / _fullThrow, 1),
  );
}

/// max(x, 0) with its corner rounded over [-width, width], never below it.
double _rounded(double x, double width) {
  if (x >= width) {
    return x;
  }
  if (x <= -width) {
    return 0;
  }
  final reach = x + width;
  return reach * reach / (4 * width);
}

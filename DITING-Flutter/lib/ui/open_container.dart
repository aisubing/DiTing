// Portions derived from DITING (https://github.com/chen08209/DITING), Copyright (c) the DITING authors, GPL-3.0-or-later.
import 'package:diting/ui/deferred_push.dart';
import 'package:diting/ui/drag_back.dart';
import 'package:diting/ui/keyboard_inset_hold.dart';
import 'package:diting/ui/surface.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
part 'open_container_a.dart';
part 'open_container_b.dart';

typedef CloseContainerActionCallback<S> = void Function({S? returnValue});
typedef OpenContainerBuilder<S> = Widget Function(
  BuildContext context,
  CloseContainerActionCallback<S> action,
);
typedef CloseContainerBuilder = Widget Function(
  BuildContext context,
  VoidCallback action,
);

typedef ClosedCallback<S> = void Function(S data);

@optionalTypeArgs
class OpenContainer<T extends Object?> extends StatefulWidget {
  const OpenContainer({
    super.key,
    this.closedColor,
    this.closedShape,
    this.onClosed,
    required this.closedBuilder,
    required this.openBuilder,
    this.clipBehavior = Clip.antiAlias,
  });

  final Color? closedColor;
  final ShapeBorder? closedShape;
  final ClosedCallback<T?>? onClosed;
  final CloseContainerBuilder closedBuilder;
  final OpenContainerBuilder<T> openBuilder;
  final Clip clipBehavior;

  @override
  State<OpenContainer<T?>> createState() => _OpenContainerState<T>();
}

class _OpenContainerState<T> extends State<OpenContainer<T?>> {
  final GlobalKey<_HideableState> _hideableKey = GlobalKey<_HideableState>();
  final GlobalKey _closedBuilderKey = GlobalKey();

  Future<void> openContainer() async {
    final T? data = await Navigator.of(context).push(
      _OpenContainerRoute<T>(
        closedColor: widget.closedColor,
        closedShape: widget.closedShape,
        closedBuilder: widget.closedBuilder,
        openBuilder: widget.openBuilder,
        hideableKey: _hideableKey,
        closedBuilderKey: _closedBuilderKey,
      ),
    );
    if (widget.onClosed != null) {
      widget.onClosed!(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Hideable(
      key: _hideableKey,
      child: Material(
        color: Colors.transparent,
        clipBehavior: widget.clipBehavior,
        shape: widget.closedShape,
        child: Builder(
          key: _closedBuilderKey,
          builder: (BuildContext context) {
            return widget.closedBuilder(context, openContainer);
          },
        ),
      ),
    );
  }
}

class _Hideable extends StatefulWidget {
  const _Hideable({super.key, required this.child});

  final Widget child;

  @override
  State<_Hideable> createState() => _HideableState();
}

class _HideableState extends State<_Hideable> {
  Size? get placeholderSize => _placeholderSize;
  Size? _placeholderSize;

  set placeholderSize(Size? value) {
    if (_placeholderSize == value) {
      return;
    }
    setState(() {
      _placeholderSize = value;
    });
  }

  bool get isVisible => _visible;
  bool _visible = true;

  set isVisible(bool value) {
    if (_visible == value) {
      return;
    }
    setState(() {
      _visible = value;
    });
  }

  bool get isInTree => _placeholderSize == null;

  @override
  Widget build(BuildContext context) {
    if (_placeholderSize != null) {
      return SizedBox.fromSize(size: _placeholderSize);
    }
    return Visibility(
      visible: _visible,
      maintainSize: true,
      maintainState: true,
      maintainAnimation: true,
      child: widget.child,
    );
  }
}

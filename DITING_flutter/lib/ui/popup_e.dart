// Portions derived from FlClash (https://github.com/chen08209/FlClash), Copyright (c) the FlClash authors, GPL-3.0-or-later.

part of 'popup.dart';

class CommonPopupMenu extends StatefulWidget {
  const CommonPopupMenu({super.key, required this.items, this.maxVisibleItems});

  final List<CommonPopupMenuItem> items;

  /// Half of the next row shows past these, so the cut tells the menu scrolls.
  /// Setting them builds only the rows in view, which needs rows of one height.
  final int? maxVisibleItems;

  @override
  State<CommonPopupMenu> createState() => _CommonPopupMenuState();
}

class _MenuStep {
  const _MenuStep({
    required this.index,
    required this.itemTop,
    required this.itemHeight,
    required this.cardWidth,
  });

  final int index;
  final double itemTop;
  final double itemHeight;
  final double cardWidth;
}

class _MenuLevel {
  const _MenuLevel({
    required this.items,
    required this.top,
    required this.fromWidth,
    required this.minWidth,
    required this.maxWidth,
    this.owner,
    this.step,
  });

  final List<CommonPopupMenuItem> items;
  final CommonPopupMenuItem? owner;

  /// The step that opened this level from an item of the one below.
  final _MenuStep? step;
  final double top;
  final double fromWidth;
  final double minWidth;
  final double maxWidth;
}

/// [begin] to [end] of a value that may overshoot either, as 0 to 1.
class _Span extends Animatable<double> {
  const _Span(this.begin, this.end);

  final double begin;
  final double end;

  @override
  double transform(double t) => ((t - begin) / (end - begin)).clamp(0.0, 1.0);
}

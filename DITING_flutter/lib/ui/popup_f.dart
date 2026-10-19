// Portions derived from DITING (https://github.com/chen08209/DITING), Copyright (c) the DITING authors, GPL-3.0-or-later.

part of 'popup.dart';

class _CommonPopupMenuState extends State<CommonPopupMenu>
    with SingleTickerProviderStateMixin {

  /// Where the top sub menu stands, from its item at 0 to its card at 1; one
  /// spring drives every part of the move, so a fold caught mid-unfold turns
  /// around with the speed it had.
  late final _unfold = AnimationController.unbounded(vsync: this, value: 1);
  late final Animation<double> _items = _unfold.drive(const _Span(0.05, 0.4));
  late final Animation<double> _arrow = _unfold.drive(_arrowTurns);

  ValueListenable<bool>? _platter;
  late Listenable _motion = _unfold;
  _CarriedPress? _carried;
  ValueSetter<VoidCallback>? _runPicked;

  final List<_MenuStep> _path = [];
  bool _folding = false;
  final _menuKey = GlobalKey();
  final _checkedKey = GlobalKey();
  ScrollController? _lazyController;

  /// The row of the top level under a finger that pressed one, or
  /// [_headerIndex] for its header.
  int? _pressed;
  Timer? _dwell;

  /// Whether the press rests where a sub menu it opened or folded left it,
  /// the header standing on its item, so letting go there changes nothing.
  bool _landed = false;
  bool _carrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealChecked());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = _PopupScope.maybeOf(context);
    final platter = scope?.platter;
    if (platter != _platter) {
      _platter = platter;
      _motion = Listenable.merge([_unfold, ?platter]);
    }
    _runPicked = scope?.runPicked;
    _carried = scope?.press
      ?..onMove = _slideCarried
      ..onRelease = _releaseCarried
      ..onCancel = _cancelCarried;
  }

  @override
  void dispose() {
    _carried
      ?..onMove = null
      ..onRelease = null
      ..onCancel = null;
    _dwell?.cancel();
    _unfold.dispose();
    _lazyController?.dispose();
    super.dispose();
  }

  /// A menu given its own cap builds only the rows in view, since building
  /// them all costs its first frame a row each; its rows share one height.
  bool _buildsLazily(_MenuLevel level) =>
      widget.maxVisibleItems != null &&
      level.owner == null &&
      level.items.every((item) => item.subItems.isEmpty);

  void _revealChecked() {
    final row = _checkedKey.currentContext;
    if (!mounted || row == null) {
      return;
    }
    // Whole rows above, not centring, keep the half row a label cut at the foot.
    final visible = _maxVisibleItems;
    final alignment = (visible ~/ 2) / (visible - 0.5);
    Scrollable.maybeOf(
      row,
    )?.position.ensureVisible(row.findRenderObject()!, alignment: alignment);
  }

  double _rowExtentOf(BuildContext context) =>
      _itemPadding.vertical +
      MediaQuery.textScalerOf(context).scale(AppTextStyle.subheadline.leading);

  int get _maxVisibleItems => widget.maxVisibleItems ?? _defaultMaxVisibleItems;

  double _maxHeightOf(BuildContext context, _MenuLevel level) {
    if (level.owner != null) {
      return double.infinity;
    }
    return 2 * _cardInset + (_maxVisibleItems + 0.5) * _rowExtentOf(context);
  }


  /// What the rows would take at their intrinsic width, measured from the
  /// labels as the rows lay them out.
  double _lazyWidthOf(BuildContext context, List<CommonPopupMenuItem> items) {
    final style = AppTextStyle.subheadline.of(context);
    final root = DefaultTextStyle.of(context).style.merge(style);
    final textScaler = MediaQuery.textScalerOf(context);
    final boldText = MediaQuery.boldTextOf(context);
    const limit = _menuMaxWidth - 2 * _cardInset;
    var width = 0.0;
    for (final item in items) {
      if (_labelWidths.length >= 1024) {
        _labelWidths.clear();
      }
      final label = _labelWidths[(item.label, root, textScaler, boldText)] ??=
          EmojiText.widthOf(context, item.label, root);
      final checked = item.checked == true;
      final row =
          (checked ? _itemArrowPadding : _itemPadding).horizontal +
          (item.glyph != null ? _itemIconSize + 12 : 0) +
          label +
          (checked ? 8 + _submenuArrowSize : 0);
      width = math.max(width, row);
      if (width >= limit) {
        break;
      }
    }
    return width;
  }

  Widget _buildLazyContent(BuildContext context, _MenuLevel level) {
    final items = level.items;
    final extent = _rowExtentOf(context);
    final visible = _maxVisibleItems;
    final height = math.min(items.length, visible + 0.5) * extent;
    final controller = _lazyController ??= () {
      final checked = items.indexWhere((item) => item.checked == true);
      // Whole rows above, as _revealChecked leaves them.
      return ScrollController(
        initialScrollOffset: ((checked - visible ~/ 2) * extent).clamp(
          0.0,
          math.max(0.0, items.length * extent - height),
        ),
      );
    }();
    return SizedBox(
      width: _lazyWidthOf(context, items),
      height: height,
      child: ListView.builder(
        controller: controller,
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        itemExtent: extent,
        itemCount: items.length,
        itemBuilder: (context, index) =>
            _buildItem(context, items[index], index, active: true),
      ),
    );
  }

  List<_MenuLevel> _resolveLevels() {
    final levels = [
      _MenuLevel(
        items: widget.items,
        top: 0,
        fromWidth: _menuMinWidth,
        minWidth: _menuMinWidth,
        maxWidth: _menuMaxWidth,
      ),
    ];
    for (final step in _path) {
      final parent = levels.last;
      if (step.index >= parent.items.length) {
        break;
      }
      final item = parent.items[step.index];
      if (item.subItems.isEmpty) {
        break;
      }
      final fromWidth = math.max(step.cardWidth, parent.minWidth);
      final minWidth = fromWidth * _levelWidthScale;
      levels.add(
        _MenuLevel(
          items: item.subItems,
          owner: item,
          step: step,
          top: math.max(0, step.itemTop - _cardInset),
          fromWidth: fromWidth,
          minWidth: minWidth,
          maxWidth: math.max(minWidth, _menuMaxWidth),
        ),
      );
    }
    return levels;
  }

  void _push(BuildContext itemContext, int index) {
    final itemBox = itemContext.findRenderObject() as RenderBox?;
    final stackBox = context.findRenderObject() as RenderBox?;
    final placed =
        itemBox != null &&
        stackBox != null &&
        itemBox.hasSize &&
        stackBox.hasSize;
    const _PopupUnfoldNotification().dispatch(context);
    setState(() {
      _folding = false;
      _path.add(
        _MenuStep(
          index: index,
          itemTop: placed
              ? itemBox.localToGlobal(Offset.zero, ancestor: stackBox).dy
              : 0,
          itemHeight: placed ? itemBox.size.height : 0,
          cardWidth: placed
              ? itemBox.size.width + 2 * _cardInset
              : _menuMinWidth,
        ),
      );
    });
    _unfold.value = 0;
    _unfoldTop();
  }

  TickerFuture _springTo(double target, SpringDescription spring) {
    return _unfold.animateWith(
      SpringSimulation(spring, _unfold.value, target, _unfold.velocity),
    );
  }

  void _unfoldTop() {
    // A spring stops within its tolerance; the card lands on its bounds.
    _springTo(1, _unfoldSpring).then((_) {
      if (mounted && !_folding) {
        _unfold.value = 1;
      }
    });
  }

  void _pop() {
    if (_path.isEmpty || _folding) {
      return;
    }
    setState(() => _folding = true);
    _springTo(0, _foldSpring).then((_) {
      if (!mounted || !_folding) {
        return;
      }
      setState(() {
        _folding = false;
        final step = _path.removeLast();
        // The header stood on the item that opened its sub menu.
        if (_pressed == _headerIndex) {
          _pressed = step.index;
        }
        _unfold.value = 1;
      });
    });
  }

  /// The header stands on the item that opened its sub menu, so tapping it
  /// mid-fold reads as tapping that item again.
  void _toggleTop() {
    if (!_folding) {
      _pop();
      return;
    }
    setState(() => _folding = false);
    _unfoldTop();
  }

  void _select(VoidCallback onPressed) {
    Navigator.of(context).pop();
    final runPicked = _runPicked;
    if (runPicked == null) {
      onPressed();
    } else {
      runPicked(onPressed);
    }
  }

  /// Hit tests where the menu paints, which a press swells or stretches.
  _MenuRow? _rowAt(Offset position) {
    final box = _menuKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) {
      return null;
    }
    final painted = ElasticPress.paintBoundsOf(box);
    final local = box.globalToLocal(position);
    final result = BoxHitTestResult();
    box.hitTest(
      result,
      position: Offset(
        (local.dx - painted.left) * box.size.width / painted.width,
        (local.dy - painted.top) * box.size.height / painted.height,
      ),
    );
    for (final entry in result.path) {
      if (entry.target case RenderMetaData(metaData: final _MenuRow row)) {
        return row;
      }
    }
    return null;
  }

  bool _startPress(Offset position) {
    final row = _rowAt(position);
    if (row == null) {
      return false;
    }
    _hold(row);
    return true;
  }

  void _slidePress(Offset position) {
    final row = _rowAt(position);
    final index = row?.onTap == null ? null : row!.index;
    if (index == _pressed) {
      return;
    }
    if (index != null) {
      HapticFeedback.selectionClick();
    }
    _hold(row);
  }

  void _hold(_MenuRow? row) {
    _dwell?.cancel();
    _landed = false;
    final onTap = row?.onTap;
    final index = onTap == null ? null : row!.index;
    setState(() => _pressed = index);
    if (onTap == null || !row!.togglesSubMenu) {
      return;
    }
    _dwell = Timer(_dwellDuration, () {
      if (!mounted || _pressed != index) {
        return;
      }
      onTap();
      HapticFeedback.selectionClick();
      setState(() {
        _pressed = _headerIndex;
        _landed = true;
      });
    });
  }

  void _endPress(Offset position) {
    final onTap = _landed ? null : _rowAt(position)?.onTap;
    _cancelPress();
    onTap?.call();
  }

  void _cancelPress() {
    _dwell?.cancel();
    _landed = false;
    if (mounted && _pressed != null) {
      setState(() => _pressed = null);
    }
  }

  ElasticPressHandle? get _elastic {
    final menu = _menuKey.currentContext;
    return menu == null ? null : ElasticPress.maybeOf(menu);
  }

  bool get _platterShows => _platter?.value ?? false;

  void _slideCarried(Offset position) {
    if (!_carrying && !_platterShows) {
      _carrying = true;
      _elastic?.press(position);
    }
    if (_carrying) {
      _elastic?.drag(position);
    }
    _slidePress(position);
  }

  void _releaseCarried(Offset position) {
    _carrying = false;
    _elastic?.release();
    _endPress(position);
  }

  void _cancelCarried() {
    _carrying = false;
    _elastic?.release();
    _cancelPress();
  }

  @override
  Widget build(BuildContext context) {
    final levels = _resolveLevels();
    final topIndex = levels.length - 1;
    return PopScope(
      canPop: topIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _pop();
        }
      },
      // The platter clips the menu while it opens and does not swell with it,
      // so a swell then would cut the menu's edges until the platter left.
      child: ValueListenableBuilder<bool>(
        valueListenable: _platter ?? const AlwaysStoppedAnimation(false),
        builder: (_, platter, child) =>
            ElasticPress(enabled: !platter, pullPastEdges: true, child: child!),
        child: RawGestureDetector(
          key: _menuKey,
          gestures: {
            _RowPressRecognizer:
                GestureRecognizerFactoryWithHandlers<_RowPressRecognizer>(
                  () => _RowPressRecognizer(debugOwner: this),
                  (recognizer) => recognizer
                    ..onStart = _startPress
                    ..onUpdate = _slidePress
                    ..onEnd = _endPress
                    ..onCancel = _cancelPress,
                ),
          },
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              for (var index = 0; index <= topIndex; index++)
                Padding(
                  key: ValueKey(index),
                  padding: EdgeInsets.only(top: levels[index].top),
                  child: _buildLevel(
                    context,
                    levels[index],
                    depth: topIndex - index,
                    pivot: index < topIndex
                        ? _path[index].itemTop - levels[index].top
                        : 0,
                    covered: index < topIndex ? _path[index].index : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

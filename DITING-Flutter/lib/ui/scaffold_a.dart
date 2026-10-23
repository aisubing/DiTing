// Portions derived from DITING (https://github.com/chen08209/DITING), Copyright (c) the DITING authors, GPL-3.0-or-later.

part of 'scaffold.dart';

class CommonScaffoldState extends State<CommonScaffold> {
  late final ValueNotifier<AppBarState> _appBarState;
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(false);
  final ValueNotifier<List<String>> _keywordsNotifier = ValueNotifier([]);
  final _textController = TextEditingController();
  final _searchFocusNode = FocusNode();
  var _sorting = false;

  bool get _isSearch {
    return _appBarState.value.searchState?.query != null;
  }

  bool get _hasActions {
    return widget.canSort ||
        widget.primaryAction != null ||
        widget.iconActions.isNotEmpty ||
        widget.confirmationAction != null ||
        widget.menuItems.isNotEmpty ||
        widget.actions?.isNotEmpty == true;
  }

  @override
  void initState() {
    super.initState();
    _appBarState = ValueNotifier(AppBarState(searchState: widget.searchState));
    _loadingNotifier.value = widget.isLoading;
    HardwareKeyboard.instance.addHandler(_handleSearchShortcut);
  }

  Future<void> _updateSearchState(AppBarSearchStateBuilder builder) async {
    _appBarState.value = _appBarState.value.copyWith(
      searchState: builder(_appBarState.value.searchState),
    );
  }

  void _handleToSearch() {
    _updateSearchState((state) => state?.copyWith(query: ''));
  }

  void _toggleSorting() {
    setState(() {
      _sorting = !_sorting;
    });
  }

  bool _handleSearchShortcut(KeyEvent event) {
    if (event is! KeyDownEvent ||
        _appBarState.value.searchState == null ||
        _sorting ||
        !controlSingleActivator(
          LogicalKeyboardKey.keyF,
        ).accepts(event, HardwareKeyboard.instance) ||
        !_isFrontmost) {
      return false;
    }
    if (_isSearch || context.isInCompactSheet) {
      _searchFocusNode.requestFocus();
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    } else {
      _handleToSearch();
    }
    return true;
  }

  // Kept-alive pages and pages under another route stay mounted too.
  bool get _isFrontmost {
    if (!mounted ||
        context.getInheritedWidgetOfExactType<PageActivityScope>()?.isActive ==
            false) {
      return false;
    }
    BuildContext? current = context;
    while (current != null && current.mounted) {
      final route = ModalRoute.of(current);
      if (route == null) {
        return true;
      }
      if (!route.isCurrent) {
        return false;
      }
      current = route.navigator?.context;
    }
    return true;
  }

  Color get _searchingBackgroundColor =>
      SurfaceLevel.card.colorOf(context.colorScheme);

  Widget _buildSearchingAppBarTheme(Widget child) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            appBarTheme: theme.appBarTheme.copyWith(
              backgroundColor: _searchingBackgroundColor,
              titleTextStyle: AppTextStyle.body.of(context),
              toolbarTextStyle: AppTextStyle.subheadline.of(context),
            ),
          ),
          child: SurfaceScope(
            level: SurfaceLevel.card,
            child: InputDecorationTheme(
              data: InputDecorationThemeData(
                hintStyle: theme.inputDecorationTheme.hintStyle,
                border: InputBorder.none,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  void didUpdateWidget(CommonScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchState != widget.searchState) {
      final query = _appBarState.value.searchState?.query;
      _appBarState.value = _appBarState.value.copyWith(
        searchState: widget.searchState?.copyWith(query: query),
      );
    }
    if (oldWidget.isLoading != widget.isLoading) {
      _loadingNotifier.value = widget.isLoading;
    }
    if (oldWidget.canSort && !widget.canSort) {
      _sorting = false;
    }
  }

  void _handleClearInput() {
    _textController.text = '';
    if (_appBarState.value.searchState != null) {
      _appBarState.value.searchState!.onSearch('');
    }
  }

  void _handleClear() {
    if (_textController.text.isNotEmpty) {
      _handleClearInput();
      return;
    }
    _popAppBarLayer();
  }

  void handleExitSearching() {
    if (!_isSearch) {
      return;
    }
    _handleClearInput();
    _updateSearchState((state) => state?.copyWith(query: null));
  }

  void _handleExitAppBarLayer() {
    handleExitSearching();
    if (_sorting) {
      _toggleSorting();
    }
  }

  void _popAppBarLayer() {
    if (!_isSearch) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleSearchShortcut);
    _appBarState.dispose();
    _textController.dispose();
    _searchFocusNode.dispose();
    _loadingNotifier.dispose();
    _keywordsNotifier.dispose();
    super.dispose();
  }

  void addKeyword(String keyword) {
    final isContains = _keywordsNotifier.value.contains(keyword);
    if (isContains) return;
    final keywords = List<String>.from(_keywordsNotifier.value)..add(keyword);
    _keywordsNotifier.value = keywords;
  }

  void _deleteKeyword(String keyword) {
    final isContains = _keywordsNotifier.value.contains(keyword);
    if (!isContains) return;
    final keywords = List<String>.from(_keywordsNotifier.value)
      ..remove(keyword);
    _keywordsNotifier.value = keywords;
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.title != null || widget.titleWidget != null);
    final backAction = widget.backAction;
    final form = _SheetForm.of(
      context,
      searchState: widget.searchState,
      hasActions: _hasActions,
      hasPrimaryAction: widget.primaryAction != null,
      hasConfirmationAction: widget.confirmationAction != null,
    );
    final isCompact = form.isCompact;
    final bottomInset = BottomInsetScope.of(context);
    // A detent sheet fills its detent and clips its own corners; any other sizes to content.
    final hugsContent = isCompact && !SheetOverhangScope.fillsDetentOf(context);
    // The bar floats over the body, leaving its height at the top through MediaQuery padding.
    final barFloats = !isCompact;
    final sortableBody = SortModeScope(sorting: _sorting, child: widget.body);
    final body = SafeArea(
      top: !barFloats,
      child: ValueListenableBuilder(
        valueListenable: _keywordsNotifier,
        builder: (context, keywords, _) {
          if (widget.onKeywordsUpdate != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onKeywordsUpdate!(keywords);
            });
          }
          final hasKeywords = keywords.isNotEmpty;
          // The status bar height must come from the `View`: the outer Scaffold consumed it to 0.
          final view = View.of(context);
          final barInset = view.viewPadding.top / view.devicePixelRatio;
          // Total inset of the floating bar: status bar + toolbar.
          final overlap = barFloats
              ? barInset + pageToolbarHeight
              : isCompact
              ? sheetAppBarHeight
              : 0.0;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: hugsContent ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (hasKeywords) ...[
                SizedBox(height: barInset),
                Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: isCompact ? sheetAppBarHeight : 16,
                    bottom: 16,
                  ),
                  child: Wrap(
                    runSpacing: 8,
                    spacing: 8,
                    children: [
                      for (final keyword in keywords)
                        CommonChip(
                          label: keyword,
                          onDeleted: () {
                            _deleteKeyword(keyword);
                          },
                        ),
                    ],
                  ),
                ),
              ],
              Flexible(
                fit: hugsContent ? FlexFit.loose : FlexFit.tight,
                child: hasKeywords
                    ? MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        child: FloatingBarScope(inset: 0, child: sortableBody),
                      )
                    : sortableBody,
              ),
            ],
          );
          final scoped = FloatingBarScope(
            inset: overlap,
            child: overlap > 0
                ? _FocusClearOfBar(inset: overlap, child: content)
                : content,
          );
          if (keywords.isEmpty) {
            return scoped;
          }
          return TopInsetScope(inset: 0, child: scoped);
        },
      ),
    );
    final appBar = _buildAppBar(backAction, form);
    final content = form.hasDockedSearch
        ? BottomInsetScope(
            inset: bottomInset + BottomInsetScope.dockedSearchInset,
            child: body,
          )
        : body;
    if (!isCompact) {
      final media = MediaQuery.of(context);
      // The dock shell writes the dock height into `padding.bottom`, cleared by `DockSpacer`.
      final pagePadding = media.padding.copyWith(
        bottom: math.min(media.padding.bottom, media.viewPadding.bottom),
      );
      return AppBarInsetScope(
        child: Scaffold(
          appBar: appBar,
          extendBodyBehindAppBar: barFloats,
          body: _BodyScope(
            child: MediaQuery(
              data: media.copyWith(padding: pagePadding),
              child: content,
            ),
          ),
          resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
          backgroundColor: widget.backgroundColor,
        ),
      );
    }
    final sheetBody = FloatingHeaderBody(
      backgroundColor:
          widget.backgroundColor ??
          SurfaceLevel.page.colorOf(context.colorScheme),
      header: SheetToolBar(appBar: appBar, dragHandle: form.hasDragHandle),
      footer: form.dockedSearch == null || _sorting
          ? null
          : _buildDockedSearch(form.dockedSearch!),
      body: content,
    );
    final footed = form.pop?.atFoot == true
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                fit: hugsContent ? FlexFit.loose : FlexFit.tight,
                child: sheetBody,
              ),
              _buildFootActions(widget.confirmationAction!),
            ],
          )
        : sheetBody;
    if (!hugsContent) {
      return AppBarInsetScope(
        child: Scaffold(
          body: footed,
          resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
          backgroundColor: widget.backgroundColor,
        ),
      );
    }
    final hugging = Column(
      mainAxisSize: MainAxisSize.min,
      children: [Flexible(child: footed)],
    );
    return AppBarInsetScope(
      child: form.hasDragHandle
          ? ClipRSuperellipse(
              borderRadius: AppRadius.top(AppCorner.xxl),
              child: hugging,
            )
          : hugging,
    );
  }
}

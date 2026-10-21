// Portions derived from DITING (https://github.com/chen08209/DITING), Copyright (c) the DITING authors, GPL-3.0-or-later.

part of 'scaffold.dart';

// 按项目单文件 ≤550 行规范，从 CommonScaffoldState 拆出的构建方法（同库扩展，
// 私有成员经库级可见性直接访问，语义与类内方法完全一致）。
extension CommonScaffoldStateBuild on CommonScaffoldState {
  Widget _buildDockedSearch(AppBarSearchState searchState) {
    final colorScheme = context.colorScheme;
    final glass = LiquidGlassScope.of(context);
    final pill = AppShape.input.copyWith(borderRadius: AppRadius.full);
    final fieldPadding =
        (BottomInsetScope.dockedSearchHeight -
            MeasureScope.of(context).textHeight(AppTextStyle.body)) /
        2;
    final field = InputDecorationTheme(
      data: InputDecorationTheme.of(context).copyWith(
        filled: !glass,
        fillColor: SurfaceLevel.floatingOf(colorScheme).colorOf(colorScheme),
        border: pill.copyWith(borderSide: BorderSide.none),
        focusedBorder: pill.copyWith(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: fieldPadding,
        ),
      ),
      child: SearchField(
        controller: _textController,
        focusNode: _searchFocusNode,
        onChanged: searchState.onSearch,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(
        left: BottomInsetScope.dockedSearchMargin,
        right: BottomInsetScope.dockedSearchMargin,
        bottom: BottomInsetScope.dockedSearchMargin,
      ),
      // A surface of its own, so the list runs under it, not a sheet-wide band.
      child: SafeArea(
        left: false,
        top: false,
        right: false,
        child: glass
            ? LiquidGlass(
                style: LiquidGlassStyle.pill(colorScheme),
                shadows: dockGlassShadows(colorScheme),
                child: field,
              )
            : DecoratedBox(
                decoration: ShapeDecoration(
                  shape: AppShape.full,
                  shadows: dockShadows(colorScheme),
                ),
                child: field,
              ),
      ),
    );
  }

  VoidCallback get _closeSheet =>
      SheetProvider.of(context)?.onClose ?? () => context.safeNestedPop();

  Widget _buildSheetPopButton(
    VoidCallback? backAction, {
    required bool useCloseIcon,
  }) {
    final localizations = UiLocalizations.of(context);
    return AppBarActionButton(
      data: useCloseIcon
          ? IconButtonData(
              glyph: AppGlyphs.close,
              onPressed: _closeSheet,
              tooltip: localizations.close,
            )
          : IconButtonData(
              glyph: AppGlyphs.backFor(Theme.of(context).platform),
              onPressed: backAction ?? () => Navigator.of(context).pop(),
              tooltip: localizations.back,
            ),
    );
  }

  Widget? _buildLeading(VoidCallback? backAction, {required _SheetPop? pop}) {
    final button = _buildLeadingButton(backAction, pop: pop);
    if (button == null) {
      return null;
    }
    final hidden = _sorting && !_isSearch;
    return Center(
      child: ExcludeFocus(
        excluding: hidden,
        child: ExcludeSemantics(
          excluding: hidden,
          child: IgnorePointer(
            ignoring: hidden,
            child: AnimatedOpacity(
              opacity: hidden ? 0 : 1,
              duration: context.motionDuration(kThemeAnimationDuration),
              child: ElasticPress(child: button),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildLeadingButton(
    VoidCallback? backAction, {
    required _SheetPop? pop,
  }) {
    if (_isSearch) {
      return IconButton(
        tooltip: UiLocalizations.of(context).back,
        onPressed: _popAppBarLayer,
        icon: const GlyphIcon(AppGlyphs.arrowBack),
      );
    }
    if (pop != null) {
      return pop.asSuffix || pop.atFoot
          ? null
          : _buildSheetPopButton(backAction, useCloseIcon: pop.useCloseIcon);
    }
    if (backAction != null) {
      return BackButton(
        onPressed: () {
          if (!mounted) {
            return;
          }
          backAction();
        },
      );
    }
    final route = ModalRoute.of(context);
    if (route?.impliesAppBarDismissal != true) {
      return null;
    }
    return route is PageRoute && route.fullscreenDialog
        ? const CloseButton()
        : const BackButton();
  }

  Widget _buildTitle(AppBarSearchState? startState, {required bool compact}) {
    final localizations = UiLocalizations.of(context);
    return _isSearch
        ? TextField(
            autofocus: true,
            controller: _textController,
            focusNode: _searchFocusNode,
            textInputAction: TextInputAction.search,
            inputFormatters: TextInputLimits.limit(TextInputLimits.search),
            style: AppTextStyle.body.of(context),
            onChanged: (value) {
              if (startState != null) {
                startState.onSearch(value);
              }
            },
            decoration: InputDecoration(hintText: localizations.search),
          )
        : widget.titleWidget ??
              (widget.titleMenuItems.isEmpty
                  ? Text(widget.title!)
                  : CommonPopupBox(
                      placement: PopupPlacement.overAnchorStart,
                      targetBuilder: (open) => _TitleMenuButton(
                        title: widget.title!,
                        compact: compact,
                        onPressed: open,
                      ),
                      popupBuilder: (_) =>
                          CommonPopupMenu(items: widget.titleMenuItems),
                    ));
  }

  List<Widget> _buildActions(
    bool hasSearch,
    IconButtonData? primaryAction,
    VoidCallback? backAction,
    _SheetForm form,
  ) {
    if (_sorting) {
      return genActions([
        if (widget.canSort)
          ElasticPress(
            child: AppBarActionButton(
              data: sortModeAction(
                context,
                sorting: true,
                onPressed: _toggleSorting,
              ),
            ),
          ),
      ], edge: AppBarActionEdge.container);
    }
    final localizations = UiLocalizations.of(context);
    final pop = form.pop;
    final lead = _isSearch
        ? IconButtonData(
            glyph: AppGlyphs.close,
            tooltip: localizations.clearSearch,
            onPressed: _handleClear,
          )
        : hasSearch && !form.hasDockedSearch
        ? IconButtonData(
            glyph: AppGlyphs.search,
            tooltip: localizations.search,
            onPressed: _handleToSearch,
          )
        : null;
    final widgets = _isSearch
        ? const <Widget>[]
        : widget.actions ?? const <Widget>[];
    final selection = widget.selectionActions;
    final selectionGroup = selection.take(_maxGroupedActions);
    final selectionSingles = selection.skip(_maxGroupedActions);
    final selectionCount =
        (selection.isEmpty ? 0 : 1) + selectionSingles.length;
    final popAsSuffix = !_isSearch && pop?.asSuffix == true;
    final pairedPrimary = popAsSuffix ? primaryAction : null;
    final atFoot = pop?.atFoot == true;
    final fold = _isSearch
        ? _foldBarActions(
            hasLead: true,
            icons: widget.searchActions,
            widgetCount: selectionCount,
          )
        : _foldBarActions(
            hasLead: lead != null,
            primary: pairedPrimary == null ? primaryAction : null,
            foldPrimary: widget.foldPrimaryAction,
            icons: [
              if (widget.canSort)
                sortModeAction(
                  context,
                  sorting: false,
                  onPressed: _toggleSorting,
                ),
              ...widget.iconActions,
            ],
            confirmation: atFoot ? null : widget.confirmationAction,
            widgetCount:
                widgets.length +
                selectionCount +
                (pairedPrimary == null ? 0 : 1),
            menuItems: widget.menuItems,
          );
    final shown = [?lead, ...fold.shown];
    final grouped = shown.length > 1 ? shown.take(_maxGroupedActions) : null;
    return genActions([
      if (grouped != null)
        TonalButtonGroup(
          children: [
            for (final data in grouped) AppBarActionButton(data: data),
          ],
        ),
      for (final data in shown.skip(grouped?.length ?? 0))
        ElasticPress(
          enabled: !data.isLoading && data.onPressed != null,
          child: AppBarActionButton(data: data),
        ),
      if (selection.isNotEmpty)
        TonalButtonGroup(
          children: [
            for (final data in selectionGroup) AppBarActionButton(data: data),
          ],
        ),
      for (final data in selectionSingles)
        ElasticPress(
          enabled: !data.isLoading && data.onPressed != null,
          child: AppBarActionButton(data: data),
        ),
      for (final action in widgets) ElasticPress(child: action),
      if (fold.overflow.isNotEmpty)
        ElasticPress(child: _OverflowMenuButton(items: fold.overflow)),
      if (pairedPrimary != null)
        TonalButtonGroup(
          children: [
            AppBarActionButton(data: pairedPrimary),
            _buildSheetPopButton(backAction, useCloseIcon: pop!.useCloseIcon),
          ],
        )
      else if (popAsSuffix)
        ElasticPress(
          child: _buildSheetPopButton(
            backAction,
            useCloseIcon: pop!.useCloseIcon,
          ),
        ),
    ], edge: AppBarActionEdge.container);
  }

  Widget _buildFootActions(IconButtonData confirmation) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: AlertActions(
        actions: [
          TextButton(
            onPressed: _closeSheet,
            child: Text(UiLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: confirmation.isLoading ? null : confirmation.onPressed,
            child: confirmation.isLoading
                ? CommonCircleLoading(size: TonalButtonSize.bar.icon)
                : Text(confirmation.tooltip!),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarWrap(Widget child) {
    final appBar = TonalButtonTheme(
      glass: LiquidGlassScope.of(context),
      child: _isSearch ? _buildSearchingAppBarTheme(child) : child,
    );
    if (_isSearch || _sorting) {
      return BackLayerScope(onBack: _handleExitAppBarLayer, child: appBar);
    }
    return appBar;
  }

  Widget _buildFloatingHeader(Widget appBar) {
    final top = MediaQuery.paddingOf(context).top;
    // 渐隐起点压在工具栏下方（约 72% 高）：正文从栏底透出才有半透明感，若从
    // 状态栏下就开始淡出，滚动中的大号数字会直接叠在标题与动作上。
    const fadeUntil = 0.72;
    return FloatingHeader(
      backgroundColor:
          widget.backgroundColor ??
          SurfaceLevel.page.colorOf(context.colorScheme),
      fadeStart:
          (top + pageToolbarHeight * fadeUntil) / (top + pageToolbarHeight),
      overhang: _headerOverhang,
      child: appBar,
    );
  }

  PreferredSizeWidget _buildAppBar(VoidCallback? backAction, _SheetForm form) {
    final isCompact = form.isCompact;
    final isMobileView = ViewScope.isMobileOf(context);
    final pushed =
        form.pop == null &&
        widget.titleWidget == null &&
        isMobileView &&
        ModalRoute.of(context)?.impliesAppBarDismissal == true;
    final compactTitle = isCompact || pushed;
    final titleEndInset = appBarActionInset(
      _isCompactBar(context, isMobileView),
    );
    // Under a sheet the bar drops its actions, so none reads as the sheet's.
    final uncovered = ReverseAnimation(sheetCoverOf(context));
    return PreferredSize(
      preferredSize: Size.fromHeight(
        isCompact ? sheetToolbarHeight : pageToolbarHeight,
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          ValueListenableBuilder<AppBarState>(
            valueListenable: _appBarState,
            builder: (_, state, _) {
              final leading = _buildLeading(backAction, pop: form.pop);
              final appBar = _buildAppBarWrap(
                AppBar(
                  clipBehavior: Clip.none,
                  automaticallyImplyLeading: false,
                  animateColor: true,
                  // A searching bar carries its own opaque theme.
                  forceMaterialTransparency: isCompact || !_isSearch,
                  toolbarHeight: isCompact ? sheetToolbarHeight : null,
                  centerTitle: isCompact,
                  titleTextStyle: _isSearch
                      ? null
                      : compactTitle
                      ? AppTextStyle.headline.of(context)
                      : AppTextStyle.pageTitle.of(context),
                  leading: leading,
                  // The leading slot already trails its button by a margin.
                  titleSpacing: leading == null ? null : 0,
                  title: leading == null || isCompact || _isSearch
                      ? _buildTitle(state.searchState, compact: compactTitle)
                      : Padding(
                          padding: EdgeInsetsDirectional.only(
                            end: titleEndInset,
                          ),
                          child: _buildTitle(
                            state.searchState,
                            compact: compactTitle,
                          ),
                        ),
                  actions: [
                    for (final action in _buildActions(
                      state.searchState != null,
                      widget.primaryAction,
                      backAction,
                      form,
                    ))
                      FadeTransition(opacity: uncovered, child: action),
                  ],
                ),
              );
              return isCompact
                  ? appBar
                  : _buildFloatingHeader(
                      _WindowControlsClearance(child: appBar),
                    );
            },
          ),
          ValueListenableBuilder(
            valueListenable: _loadingNotifier,
            builder: (_, value, _) {
              return value == true
                  ? const LinearProgressIndicator()
                  : Container();
            },
          ),
        ],
      ),
    );
  }
}

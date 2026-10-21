// Portions derived from DITING (https://github.com/chen08209/DITING), Copyright (c) the DITING authors, GPL-3.0-or-later.

part of 'scaffold.dart';

/// What the surface a scaffold sits on asks of its chrome.
///
/// A sheet page is a pushed route and wears a page's chrome. A bottom sheet
/// floats its bar over the body and searches from a field docked over its
/// foot instead of a button that takes the bar over.
class _SheetForm {
  const _SheetForm({
    required this.isCompact,
    required this.hasDragHandle,
    required this.dockedSearch,
    required this.pop,
  });

  factory _SheetForm.of(
    BuildContext context, {
    required AppBarSearchState? searchState,
    required bool hasActions,
    required bool hasPrimaryAction,
    required bool hasConfirmationAction,
  }) {
    final provider = SheetProvider.of(context);
    final isModal = provider != null && provider.type != SheetType.page;
    final isCompact = provider?.type.isCompact ?? false;
    return _SheetForm(
      isCompact: isCompact,
      hasDragHandle: provider?.type == SheetType.bottomSheet,
      dockedSearch: isCompact ? searchState : null,
      pop: !isModal
          ? null
          : _SheetPop.of(
              context,
              provider,
              // A bottom sheet docks its search at its foot, not in the bar.
              hasActions: hasActions || searchState != null && !isCompact,
              hasPrimaryAction: hasPrimaryAction,
              hasConfirmationAction:
                  hasConfirmationAction && searchState == null,
            ),
    );
  }

  final bool isCompact;
  final bool hasDragHandle;
  final AppBarSearchState? dockedSearch;
  final _SheetPop? pop;

  bool get hasDockedSearch => dockedSearch != null;
}

/// How a sheet's own pop button reads: [useCloseIcon] where it dismisses the
/// sheet, and [asSuffix] where it ends the bar, alone or with a primary action.
class _SheetPop {
  const _SheetPop({
    required this.useCloseIcon,
    required this.asSuffix,
    required this.atFoot,
  });

  factory _SheetPop.of(
    BuildContext context,
    SheetProvider provider, {
    required bool hasActions,
    required bool hasPrimaryAction,
    required bool hasConfirmationAction,
  }) {
    final useCloseIcon =
        provider.nestedNavigatorPop == null ||
        ModalRoute.of(context)?.impliesAppBarDismissal == false;
    final atFoot =
        useCloseIcon &&
        hasConfirmationAction &&
        provider.type == SheetType.formSheet;
    return _SheetPop(
      useCloseIcon: useCloseIcon,
      asSuffix: !atFoot && useCloseIcon && (!hasActions || hasPrimaryAction),
      atFoot: atFoot,
    );
  }

  final bool useCloseIcon;
  final bool asSuffix;
  final bool atFoot;
}

const double appBarActionSpace = 4;

const double _barButtonGap = 8;
const double _headerOverhang = 16;
const double _iconButtonTapPadding = 4;

/// Where a filled button sits from the app bar edge, leading included: the
/// layout margin iOS gives a compact and a regular width.
double appBarActionInset(bool compact) => compact ? 16 : 20;

double _iconActionInset(bool isMobileView) => isMobileView ? 4 : 8;

double appBarLeadingWidth(bool compact) =>
    TonalButtonSize.bar.button + appBarActionInset(compact) * 2;

/// A phone view or a sheet: an iOS compact width.
bool _isCompactBar(BuildContext context, bool isMobileView) {
  final sheet = SheetProvider.of(context)?.type;
  return isMobileView || (sheet != null && sheet != SheetType.page);
}

enum AppBarActionEdge {
  icon,
  container;

  double spaceOf(BuildContext context, bool isMobileView) => switch (this) {
    icon => _iconActionInset(isMobileView) - _tapPaddingOf(context),
    container => appBarActionInset(_isCompactBar(context, isMobileView)),
  };

  double get gap => switch (this) {
    icon => appBarActionSpace,
    container => _barButtonGap,
  };
}

/// Only the touch platforms ask for the 48 dp target that pads the container out.
double _tapPaddingOf(BuildContext context) =>
    Theme.of(context).materialTapTargetSize == MaterialTapTargetSize.padded
    ? _iconButtonTapPadding
    : 0;

List<Widget> genActions(
  List<Widget> actions, {
  required AppBarActionEdge edge,
}) {
  return <Widget>[
    ...actions.separated(SizedBox(width: edge.gap)),
    _ActionEdgeGap(edge),
  ];
}

class _ActionEdgeGap extends StatelessWidget {
  const _ActionEdgeGap(this.edge);

  final AppBarActionEdge edge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: edge.spaceOf(context, ViewScope.isMobileOf(context)),
    );
  }
}

class AppBarInsetScope extends StatelessWidget {
  const AppBarInsetScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = _isCompactBar(context, ViewScope.isMobileOf(context));
    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          leadingWidth: appBarLeadingWidth(compact),
          toolbarHeight: pageToolbarHeight,
        ),
      ),
      child: child,
    );
  }
}

/// A route over the home page on the root navigator fills the window, with
/// neither the window header nor the sidebar keeping it off the buttons.
class _TitleMenuButton extends StatelessWidget {
  const _TitleMenuButton({
    required this.title,
    required this.compact,
    required this.onPressed,
  });

  final String title;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // No ink: the padding it needs would move the title off its place in the
    // bar, and a press turns the title into its menu at once.
    return InkWell(
      onTap: onPressed,
      customBorder: AppShape.sm,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: compact ? 2 : 4,
        children: [
          Flexible(child: Text(title)),
          GlyphIcon(
            AppGlyphs.chevronDown,
            size: compact ? 16 : 20,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _WindowControlsClearance extends StatelessWidget {
  const _WindowControlsClearance({required this.child});

  final Widget child;

  static bool _fillsWindow(BuildContext context) {
    final route = ModalRoute.of(context);
    return route != null &&
        route.opaque &&
        !route.isFirst &&
        route.navigator == Navigator.maybeOf(context, rootNavigator: true);
  }

  @override
  Widget build(BuildContext context) {
    final controls = ViewScope.windowControlsOf(context);
    if (controls.isEmpty || !_fillsWindow(context)) {
      return child;
    }
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.padding;
    return MediaQuery(
      data: mediaQuery.copyWith(
        padding: padding.copyWith(left: math.max(padding.left, controls.width)),
      ),
      child: child,
    );
  }
}

class BaseScaffold extends StatelessWidget {
  final String title;
  final Widget body;

  const BaseScaffold({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(body: body, title: title);
  }
}

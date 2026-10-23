// Portions derived from DITING (https://github.com/chen08209/DITING), Copyright (c) the DITING authors, GPL-3.0-or-later.
import 'dart:math' as math;

import 'package:diting/ui/support/input_limits.dart';
import 'package:diting/ui/support/iterable.dart';
import 'package:diting/ui/context.dart';
import 'package:diting/ui/icons/icons.dart';
import 'package:diting/ui/keyboard.dart';
import 'package:diting/ui/l10n.dart';
import 'package:diting/ui/measure.dart';
import 'package:diting/ui/metrics.dart';
import 'package:diting/ui/models.dart';
import 'package:diting/ui/pop_scope.dart';
import 'package:diting/ui/shape.dart';
import 'package:diting/ui/surface.dart';
import 'package:diting/ui/typography.dart';
import 'package:diting/ui/view_scope.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'button.dart';
import 'chip.dart';
import 'dialog.dart';
import 'inherited.dart';
import 'liquid_glass.dart';
import 'loading.dart';
import 'navigation_dock.dart';
import 'popup.dart';
import 'search_field.dart';
import 'sheet.dart';
import 'sheet_header.dart';
import 'sheet_navigator.dart';
import 'sortable.dart';
part 'scaffold_a.dart';
part 'scaffold_b.dart';
part 'scaffold_c.dart';
part 'scaffold_d.dart';

typedef OnKeywordsUpdateCallback = void Function(List<String> keywords);

typedef AppBarSearchStateBuilder =
    AppBarSearchState? Function(AppBarSearchState? state);

class CommonScaffold extends StatefulWidget {
  final Widget body;
  final Color? backgroundColor;
  final String? title;
  final Widget? titleWidget;
  final List<CommonPopupMenuItem> titleMenuItems;
  final bool isLoading;
  final List<Widget>? actions;

  final IconButtonData? primaryAction;

  final List<IconButtonData> iconActions;
  final List<CommonPopupMenuItem> menuItems;

  final IconButtonData? confirmationAction;

  final bool foldPrimaryAction;
  final AppBarSearchState? searchState;
  final List<IconButtonData> searchActions;

  final List<IconButtonData> selectionActions;
  final OnKeywordsUpdateCallback? onKeywordsUpdate;
  final bool? resizeToAvoidBottomInset;
  final VoidCallback? backAction;

  final bool canSort;

  const CommonScaffold({
    super.key,
    required this.body,
    this.backgroundColor,
    this.title,
    this.titleWidget,
    this.titleMenuItems = const [],
    this.actions,
    this.backAction,
    this.isLoading = false,
    this.searchState,
    this.searchActions = const [],
    this.selectionActions = const [],
    this.primaryAction,
    this.iconActions = const [],
    this.menuItems = const [],
    this.confirmationAction,
    this.foldPrimaryAction = false,
    this.onKeywordsUpdate,
    this.resizeToAvoidBottomInset,
    this.canSort = false,
  });

  @override
  State<CommonScaffold> createState() => CommonScaffoldState();
}


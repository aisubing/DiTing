import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Wraps a sub page in [MaterialPage] so the theme supplies the transition. Every route must use
/// `pageBuilder`: plain `builder` makes go_router test `isMaterialApp` against
/// `package:flutter/material.dart`, false for this `material_ui` app, so it degrades instead.
Page<void> androidDefaultPage(GoRouterState state, Widget child) {
  return MaterialPage<void>(
    // Keep `state.pageKey`: go_router uses it to recognise a new state of the
    // same route, otherwise every push/pop rebuilds the subtree and loses state.
    key: state.pageKey,
    name: state.name ?? state.path,
    child: child,
  );
}

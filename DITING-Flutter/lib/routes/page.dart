import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 把二级页面包成 [MaterialPage]，转场交给主题里 Android 的默认 builder。
///
/// 为什么每条 `GoRoute` 都要显式给 `pageBuilder`，不能只写 `builder`：
/// `go_router` 看到 `builder` 时会走 `_buildPlatformAdapterPage`，用
/// `isMaterialApp(context)` 判断外面是不是 `MaterialApp` —— 它找的是
/// `package:flutter/material.dart` 的 `MaterialApp`，而本工程用的是
/// `material_ui` 自己那份，于是判断永远为假，落到 `NoTransitionPage`：
/// **页面根本不带转场**，直接硬切。显式给出 [MaterialPage] 就不用再猜，
/// 转场动画由 `ThemeData.pageTransitionsTheme` 决定（Android 用系统默认）。
///
/// 底栏的六个 branch 不经过这里：它们在 shell 的 `indexedStack` 里切换，
/// 本来就不该有转场。
Page<void> androidDefaultPage(GoRouterState state, Widget child) {
  return MaterialPage<void>(
    // 必须沿用 `state.pageKey`：go_router 靠这个 key 认出「同一个路由的新
    // 状态」，换成别的一 push 一 pop 就会重建整棵子树、丢状态。
    key: state.pageKey,
    name: state.name ?? state.path,
    child: child,
  );
}

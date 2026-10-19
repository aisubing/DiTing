/// 演示用状态：应用选择（哪些应用纳入分流）。
///
/// 单独成文件而不是塞进已有 state：应用选择是「按应用分流」这一整块功能的
/// 唯一状态源，后续应用规则页（排除 / 禁止 / 放行）都要读它，放在这里比
/// 挂在某个页面里更容易被复用。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 已选应用的包名集合。
///
/// 用 `Set<String>` 而不是 `List`：勾选语义天然去重，`contains` 是 O(1)——
/// 列表每帧都要判断每一行的选中态，设备上有几百个应用时这个差别会被放大。
class AppSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// 单个应用勾选 / 取消。
  void toggle(String packageName) {
    final next = {...state};
    if (!next.remove(packageName)) {
      next.add(packageName);
    }
    state = next;
  }

  /// 全选：只接受传入的候选集，避免把列表里不存在的包名写进状态。
  void selectAll(Iterable<String> packageNames) => state = {...packageNames};

  /// 反选：在候选集内取补集，候选集外的既有选择保持不变。
  void invert(Iterable<String> packageNames) {
    final next = {...state};
    for (final packageName in packageNames) {
      if (!next.remove(packageName)) {
        next.add(packageName);
      }
    }
    state = next;
  }

  void clear() => state = const {};
}

final appSelectionProvider =
    NotifierProvider<AppSelectionNotifier, Set<String>>(
      AppSelectionNotifier.new,
    );

/// 功能中心演示状态：隐藏卡片集合与日志长按提示。
///
/// 上游把隐藏项存在 SharedPreferences（`HiddenFeaturesStore`），本阶段按项目
/// 约定只做内存态；接口形状与上游一致：一个可读集合 + 切换 / 恢复默认。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

class HiddenFeatureKeysNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void setVisible(String key, bool visible) {
    final next = {...state};
    if (visible) {
      next.remove(key);
    } else {
      next.add(key);
    }
    state = next;
  }

  void toggle(String key) => setVisible(key, !state.contains(key));

  void resetAll() => state = const {};
}

/// 当前被隐藏的功能键。
final hiddenFeatureKeysProvider =
    NotifierProvider<HiddenFeatureKeysNotifier, Set<String>>(
      HiddenFeatureKeysNotifier.new,
    );

/// 「日志卡可长按」提示是否已经看过。
///
/// 上游用 `SettingsGuides.HOME_LOG_LONG_PRESS_ID` 记录，长按一次后永久消失；
/// 这里同样只在本次会话内记住。
class LogLongPressHintNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void acknowledge() => state = false;
}

final logLongPressHintProvider =
    NotifierProvider<LogLongPressHintNotifier, bool>(
      LogLongPressHintNotifier.new,
    );

import 'package:diting/ui/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The Chinese [UiLocalizations] the app runs with. `UiLocalizations.of` asserts the delegate is
/// registered, so every vendored widget in `lib/ui` depends on it. The tests keep their own copy.
class AppUiLocalizations extends UiLocalizations {
  AppUiLocalizations();

  static const delegate = _AppUiDelegate();

  @override
  String get back => '返回';
  @override
  String get cancel => '取消';
  @override
  String get clearSearch => '清除搜索';
  @override
  String get close => '关闭';
  @override
  String get hidePassword => '隐藏密码';
  @override
  String get more => '更多';
  @override
  String get noSearchResults => '无搜索结果';
  @override
  String get reset => '重置';
  @override
  String get search => '搜索';
  @override
  String get showLess => '收起';
  @override
  String get showMore => '展开';
  @override
  String get showPassword => '显示密码';
  @override
  String get sort => '排序';
  @override
  String get submit => '提交';
}

class _AppUiDelegate extends LocalizationsDelegate<UiLocalizations> {
  const _AppUiDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<UiLocalizations> load(Locale locale) async => AppUiLocalizations();

  @override
  bool shouldReload(_AppUiDelegate old) => false;
}
